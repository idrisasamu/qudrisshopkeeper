import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:googleapis/drive/v3.dart' as gdrive;
import 'package:drift/drift.dart';
import '../local/app_database.dart';
import '../repositories/drive_data_repo.dart';
import '../serializers/json_maps.dart';
import '../../features/sync/drive_client.dart';
import '../../features/auth/google_auth.dart';

class DataSync {
  final AppDatabase db;
  final DriveDataRepo repo;
  final String shopId;
  final String dataRootId; // /QSK/<shopId>/data folder id

  DataSync({
    required this.db,
    required this.repo,
    required this.shopId,
    required this.dataRootId,
  });

  // ---------- PULL (bootstrap a fresh device) ----------

  /// Pull inventory data from Drive (snapshot + deltas)
  Future<void> pullInventory() async {
    try {
      print('DEBUG: DataSync.pullInventory() - starting for shop: $shopId');

      final inventoryFolder = await _ensureFolder(dataRootId, 'inventory');

      // 1) Apply latest snapshot
      final snaps = await repo.listByPrefix(inventoryFolder.id!, 'snapshot_v');
      if (snaps.isNotEmpty) {
        snaps.sort((a, b) => (b.name ?? '').compareTo(a.name ?? '')); // vN desc
        final latest = snaps.first;
        final text = await repo.readDecryptedString(latest.id!);
        if (text != null && text.isNotEmpty) {
          final map = json.decode(text) as Map<String, dynamic>;
          final list = (map['items'] as List).cast<Map<String, dynamic>>();
          print('DEBUG: applying snapshot ${latest.name} items=${list.length}');

          // Clear existing items for this shop and insert snapshot items
          await db.transaction(() async {
            await (db.delete(
              db.items,
            )..where((t) => t.shopId.equals(shopId))).go();
            for (final j in list) {
              await _upsertItemFromJson(j);
            }
          });
        }
      } else {
        print('DEBUG: no inventory snapshot found');
      }

      // 2) Apply deltas since N days
      final since = DateTime.now().toUtc().subtract(const Duration(days: 180));
      final deltas = await repo.listByPrefix(inventoryFolder.id!, 'delta_');
      print('DEBUG: found ${deltas.length} delta files');

      for (final f in deltas.where(
        (f) => _isOnOrAfterDayFlexible(f.name!, since),
      )) {
        print(
          'DEBUG: DataSync.pullInventory() - processing delta file: ${f.name}',
        );
        final s = await repo.readDecryptedString(f.id!);
        if (s == null || s.isEmpty) {
          print(
            'DEBUG: DataSync.pullInventory() - skipping empty file: ${f.name}',
          );
          continue;
        }

        for (final line in const LineSplitter().convert(s)) {
          final t = line.trim();
          if (t.isEmpty) continue;

          try {
            final op = json.decode(line) as Map<String, dynamic>;
            final kind = (op['kind'] as String?)?.toLowerCase() ?? 'upsert';

            if (kind == 'delete') {
              final id = (op['itemId'] ?? op['item']?['id']) as String?;
              if (id != null) {
                await (db.delete(db.items)
                      ..where((t) => t.id.equals(id) & t.shopId.equals(shopId)))
                    .go();
              }
            } else {
              final itemJson =
                  (op['item'] as Map<String, dynamic>?) ??
                  op; // tolerate bare item
              await _upsertItemFromJson(itemJson);
            }
          } catch (e) {
            print('WARN: skip bad inventory line in ${f.name}: $e');
            continue; // Skip this line and continue with the next
          }
        }
      }

      print('DEBUG: DataSync.pullInventory() - completed');
    } catch (e) {
      print('DEBUG: DataSync.pullInventory() - error: $e');
      rethrow;
    }
  }

  /// Pull sales and stock data from Drive
  Future<void> pullSalesAndStock({int daysBack = 90}) async {
    try {
      print(
        'DEBUG: DataSync.pullSalesAndStock() - starting for shop: $shopId, daysBack: $daysBack',
      );

      final since = DateTime.now().toUtc().subtract(Duration(days: daysBack));

      // STOCK MOVEMENTS
      final stockFolder = await _ensureFolder(dataRootId, 'stock');
      final stockFiles = await repo.listByPrefix(stockFolder.id!, 'moves_');
      print(
        'DEBUG: DataSync.pullSalesAndStock() - found ${stockFiles.length} stock files',
      );

      // Sort oldest → newest to keep application order deterministic
      stockFiles.sort((a, b) => (a.name ?? '').compareTo(b.name ?? ''));

      for (final f in stockFiles.where(
        (f) => _isOnOrAfterDayFlexible(f.name!, since),
      )) {
        print(
          'DEBUG: DataSync.pullSalesAndStock() - processing stock file: ${f.name}',
        );
        final s = await repo.readDecryptedString(f.id!);
        if (s == null) continue;

        for (final line in const LineSplitter().convert(s)) {
          final t = line.trim();
          if (t.isEmpty) continue;
          try {
            final m = StockMovementJson.fromJson(json.decode(t));
            await _upsertStockMovement(m);
          } catch (e) {
            print('WARN: skip bad stock line in ${f.name}: $e');
          }
        }
      }

      // SALES
      final salesFolder = await _ensureFolder(dataRootId, 'sales');
      final saleFiles = await repo.listByPrefix(salesFolder.id!, 'sales_');
      print(
        'DEBUG: DataSync.pullSalesAndStock() - found ${saleFiles.length} sales files',
      );

      // Sort oldest → newest to keep application order deterministic
      saleFiles.sort((a, b) => (a.name ?? '').compareTo(b.name ?? ''));

      for (final f in saleFiles.where(
        (f) => _isOnOrAfterDayFlexible(f.name!, since),
      )) {
        print(
          'DEBUG: DataSync.pullSalesAndStock() - processing sales file: ${f.name}',
        );
        final s = await repo.readDecryptedString(f.id!);
        if (s == null) continue;

        for (final line in const LineSplitter().convert(s)) {
          final t = line.trim();
          if (t.isEmpty) continue;
          try {
            final j = json.decode(t) as Map<String, dynamic>;

            // createdAt can be ISO or yyyyMMdd; normalize if needed
            if (j['createdAt'] is String) {
              j['createdAt'] = _parseDateFlexible(
                j['createdAt'],
              ).toIso8601String();
            }

            await _applySaleJson(j);
          } catch (e) {
            print('WARN: skip bad sale line in ${f.name}: $e');
          }
        }
      }

      print('DEBUG: DataSync.pullSalesAndStock() - completed successfully');
    } catch (e) {
      print('DEBUG: DataSync.pullSalesAndStock() - error: $e');
      rethrow;
    }
  }

  // ---------- PUSH (batch queued ops to Drive) ----------

  /// Push queued inventory operations to Drive
  Future<void> pushQueuedInventoryOps() async {
    try {
      print('DEBUG: DataSync.pushQueuedInventoryOps() - starting');

      // 1) Make sure there is at least one snapshot for fresh devices
      await _ensureInventorySnapshotExists();

      // Get pending inventory ops with proper entity filtering
      final ops = await _getPendingOps('item');
      print(
        'DEBUG: DataSync.pushQueuedInventoryOps() - found ${ops.length} pending item ops',
      );
      if (ops.isEmpty) {
        print('DEBUG: DataSync.pushQueuedInventoryOps() - no pending ops');
        return;
      }

      final inventoryFolder = await _ensureFolder(dataRootId, 'inventory');
      final day = _today(); // e.g. "20250925" (compact to match writer)
      final fileName = 'delta_${day}.jsonl.enc';

      // Prepare lines to append
      final newLines = <String>[];
      for (final op in ops) {
        newLines.add(
          op.payload,
        ); // already JSON; payload format ≈ {kind:'upsert'|'delete', item:{...}} or {itemId:'...'}
      }

      // Append by: read→concat→write
      final existingId = await repo.findFileId(inventoryFolder.id!, fileName);

      final existingText = existingId == null
          ? null
          : await repo.readDecryptedString(existingId);

      final combined = StringBuffer();
      if (existingText != null && existingText.isNotEmpty) {
        combined.write(existingText.trimRight());
        if (!existingText.endsWith('\n')) combined.writeln();
      }
      for (final l in newLines) {
        combined.writeln(l);
      }

      await repo.writeEncryptedString(
        inventoryFolder.id!,
        fileName,
        combined.toString(),
      );

      await _markOpsAsSent(ops.map((e) => e.uuid).toList());
      print(
        'DEBUG: DataSync.pushQueuedInventoryOps() - wrote ${newLines.length} lines → $fileName',
      );
    } catch (e) {
      print('DEBUG: DataSync.pushQueuedInventoryOps() - error: $e');
      rethrow;
    }
  }

  /// Push queued stock movements to Drive
  Future<void> pushQueuedStockMoves() async {
    try {
      print('DEBUG: DataSync.pushQueuedStockMoves() - starting');

      final folder = await _ensureFolder(dataRootId, 'stock');
      final day = _today();
      final fileName = 'moves_${day}.jsonl.enc';

      // Get pending stock ops
      final ops = await _getPendingOps('stock');
      if (ops.isEmpty) {
        print('DEBUG: DataSync.pushQueuedStockMoves() - no pending ops');
        return;
      }

      print(
        'DEBUG: DataSync.pushQueuedStockMoves() - pushing ${ops.length} stock ops',
      );

      // Convert to JSONL format
      final payload = ops.map((op) => op.payload).join('\n');

      await _appendEncrypted(folder.id!, fileName, payload);
      await _markOpsAsSent(ops.map((e) => e.uuid).toList());

      print('DEBUG: DataSync.pushQueuedStockMoves() - completed successfully');
    } catch (e) {
      print('DEBUG: DataSync.pushQueuedStockMoves() - error: $e');
      rethrow;
    }
  }

  /// Push queued sales to Drive
  Future<void> pushQueuedSales() async {
    try {
      print('DEBUG: DataSync.pushQueuedSales() - starting');

      final folder = await _ensureFolder(dataRootId, 'sales');
      final day = _today();
      final fileName = 'sales_${day}.jsonl.enc';

      // Get pending sales ops
      final ops = await _getPendingOps('sale');
      if (ops.isEmpty) {
        print('DEBUG: DataSync.pushQueuedSales() - no pending ops');
        return;
      }

      print(
        'DEBUG: DataSync.pushQueuedSales() - pushing ${ops.length} sales ops',
      );

      // Convert to JSONL format
      final payload = ops.map((op) => op.payload).join('\n');

      await _appendEncrypted(folder.id!, fileName, payload);
      await _markOpsAsSent(ops.map((e) => e.uuid).toList());

      print('DEBUG: DataSync.pushQueuedSales() - completed successfully');
    } catch (e) {
      print('DEBUG: DataSync.pushQueuedSales() - error: $e');
      rethrow;
    }
  }

  // ---------- Helpers ----------

  /// Upsert item from JSON data
  Future<void> _upsertItemFromJson(Map<String, dynamic> itemJson) async {
    try {
      final itemId = itemJson['id'] as String;
      final shopId = itemJson['shopId'] as String;
      final name = itemJson['name'] as String;
      final price = (itemJson['price'] as num).toDouble();
      final minQty = (itemJson['minQty'] as num).toDouble();
      final isActive = itemJson['isActive'] as bool? ?? true;

      // Check if item exists
      final existing =
          await (db.select(db.items)
                ..where((t) => t.id.equals(itemId) & t.shopId.equals(shopId)))
              .getSingleOrNull();

      if (existing != null) {
        // Update existing item
        await (db.update(db.items)..where((t) => t.id.equals(itemId))).write(
          ItemsCompanion(
            name: Value(name),
            salePrice: Value(price),
            minQty: Value(minQty),
            isActive: Value(isActive),
            updatedAt: Value(DateTime.now()),
          ),
        );
      } else {
        // Insert new item
        await db
            .into(db.items)
            .insert(
              ItemsCompanion.insert(
                id: itemId,
                shopId: shopId,
                name: name,
                unit: 'pcs', // Default unit
                costPrice:
                    price, // Use sale price as cost price if not provided
                salePrice: price,
                minQty: minQty,
                isActive: isActive,
                updatedAt: DateTime.now(),
              ),
            );
      }
    } catch (e) {
      print('DEBUG: DataSync._upsertItemFromJson() - error: $e');
      // Don't rethrow - continue with other items
    }
  }

  /// Ensure inventory snapshot exists (create initial snapshot if none exists)
  Future<void> _ensureInventorySnapshotExists() async {
    try {
      final inventoryFolder = await _ensureFolder(dataRootId, 'inventory');
      final snaps = await repo.listByPrefix(inventoryFolder.id!, 'snapshot_v');
      if (snaps.isNotEmpty) {
        print(
          'DEBUG: DataSync._ensureInventorySnapshotExists() - snapshot already exists',
        );
        return;
      }

      print(
        'DEBUG: DataSync._ensureInventorySnapshotExists() - creating initial snapshot',
      );

      // Build snapshot from local DB - make sure this filters by shopId
      final items = await (db.select(
        db.items,
      )..where((t) => t.shopId.equals(shopId))).get();
      print(
        'DEBUG: DataSync._ensureInventorySnapshotExists() - found ${items.length} items in local DB',
      );

      final snapshot = jsonEncode({
        'version': 1,
        'createdAt': DateTime.now().toUtc().toIso8601String(),
        'items': items
            .map(
              (item) => {
                'id': item.id,
                'shopId': item.shopId,
                'name': item.name,
                'price': item.salePrice,
                'minQty': item.minQty,
                'isActive': item.isActive,
                'updatedAt': item.updatedAt.toIso8601String(),
              },
            )
            .toList(),
      });

      await repo.writeEncryptedString(
        inventoryFolder.id!,
        'snapshot_v1.json.enc',
        snapshot,
      );
      print('DEBUG: wrote initial inventory snapshot: items=${items.length}');
    } catch (e) {
      print('DEBUG: DataSync._ensureInventorySnapshotExists() - error: $e');
      // Don't rethrow - this is not critical for the main sync operation
    }
  }

  /// Ensure folder exists, create if not
  Future<gdrive.File> _ensureFolder(String parentId, String name) async {
    try {
      final found = await repo.findFileId(parentId, name);
      if (found != null) {
        return gdrive.File()
          ..id = found
          ..name = name;
      }

      print(
        'DEBUG: DataSync._ensureFolder() - creating folder $name in parent $parentId',
      );
      final driveClient = DriveClient(GoogleAuthService.googleSignIn);
      final api = await driveClient.getApi();

      return await api.files.create(
        gdrive.File()
          ..name = name
          ..mimeType = 'application/vnd.google-apps.folder'
          ..parents = [parentId],
      );
    } catch (e) {
      print('DEBUG: DataSync._ensureFolder() - error: $e');
      rethrow;
    }
  }

  /// Check if file is on or after given day
  /// Accepts "2025-09-25", "20250925", or full ISO like "2025-09-25T12:55:25Z"
  DateTime _parseDateFlexible(String s) {
    print('DEBUG: DataSync._parseDateFlexible() - parsing date: $s');

    // First, try native ISO-8601
    try {
      final result = DateTime.parse(s).toUtc();
      print(
        'DEBUG: DataSync._parseDateFlexible() - parsed as ISO-8601: $result',
      );
      return result;
    } catch (_) {}

    // Try yyyy-MM-dd
    try {
      final parts = s.split('-');
      if (parts.length == 3) {
        final y = int.parse(parts[0]);
        final m = int.parse(parts[1]);
        final d = int.parse(parts[2]);
        final result = DateTime.utc(y, m, d);
        print(
          'DEBUG: DataSync._parseDateFlexible() - parsed as YYYY-MM-DD: $result',
        );
        return result;
      }
    } catch (_) {}

    // Try yyyyMMdd (exactly 8 digits)
    try {
      if (RegExp(r'^\d{8}$').hasMatch(s)) {
        final y = int.parse(s.substring(0, 4));
        final m = int.parse(s.substring(4, 6));
        final d = int.parse(s.substring(6, 8));
        final result = DateTime.utc(y, m, d);
        print(
          'DEBUG: DataSync._parseDateFlexible() - parsed as YYYYMMDD: $result',
        );
        return result;
      }
    } catch (_) {}

    // Fallback: no date → treat as very old so it's still processed when daysBack is large
    print('DEBUG: DataSync._parseDateFlexible() - using fallback date for: $s');
    return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  }

  /// Extracts the yyyymmdd (or yyyy-mm-dd) day from file names like:
  ///   sales_20250925.jsonl.enc
  ///   moves_2025-09-25.jsonl.enc
  /// Returns a UTC DateTime at midnight.
  DateTime _fileDayFromName(String fileName) {
    print(
      'DEBUG: DataSync._fileDayFromName() - extracting date from: $fileName',
    );

    // Try yyyyMMdd
    final m1 = RegExp(r'(\d{8})').firstMatch(fileName);
    if (m1 != null) {
      print(
        'DEBUG: DataSync._fileDayFromName() - found YYYYMMDD pattern: ${m1.group(1)}',
      );
      return _parseDateFlexible(m1.group(1)!);
    }

    // Try yyyy-MM-dd
    final m2 = RegExp(r'(\d{4}-\d{2}-\d{2})').firstMatch(fileName);
    if (m2 != null) {
      print(
        'DEBUG: DataSync._fileDayFromName() - found YYYY-MM-DD pattern: ${m2.group(1)}',
      );
      return _parseDateFlexible(m2.group(1)!);
    }

    // Fallback: no date → treat as very old so it's still processed when daysBack is large
    print(
      'DEBUG: DataSync._fileDayFromName() - no date pattern found, using fallback',
    );
    return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  }

  /// Replaces any strict helper you currently use (e.g. _isOnOrAfterDay)
  bool _isOnOrAfterDayFlexible(String fileName, DateTime sinceUtc) {
    final day = _fileDayFromName(fileName); // midnight UTC of file's day
    final since = DateTime.utc(sinceUtc.year, sinceUtc.month, sinceUtc.day);
    return !day.isBefore(since); // day >= since
  }

  /// Get today's date as YYYYMMDD string
  String _today() => DateFormat('yyyyMMdd').format(DateTime.now().toUtc());

  /// Append encrypted content to file (or create new)
  Future<void> _appendEncrypted(
    String folderId,
    String name,
    String jsonl,
  ) async {
    try {
      final id = await repo.findFileId(folderId, name);
      String merged = jsonl;

      if (id != null) {
        final prev = await repo.readDecryptedString(id);
        if (prev != null && prev.isNotEmpty) {
          merged = '$prev\n$jsonl';
        }
        await repo.overwriteString(id, merged);
      } else {
        await repo.writeEncryptedString(folderId, name, jsonl);
      }
    } catch (e) {
      print('DEBUG: DataSync._appendEncrypted() - error: $e');
      rethrow;
    }
  }

  /// Apply sale JSON
  Future<void> _applySaleJson(Map<String, dynamic> j) async {
    try {
      // Insert sale + lines idempotently
      final sale = SaleJson.fromJson(j);
      await _upsertSale(sale);

      if (j['lines'] != null) {
        final lines = (j['lines'] as List).cast<Map<String, dynamic>>();
        for (final lineJson in lines) {
          final line = SaleItemJson.fromJson(lineJson);
          await _upsertSaleItem(line);
        }
      }
    } catch (e) {
      print('DEBUG: DataSync._applySaleJson() - error: $e');
    }
  }

  // ---------- Database Operations ----------

  Future<void> _upsertStockMovement(StockMovement movement) async {
    await db
        .into(db.stockMovements)
        .insertOnConflictUpdate(
          StockMovementsCompanion.insert(
            id: movement.id,
            shopId: movement.shopId,
            itemId: movement.itemId,
            type: movement.type,
            qty: movement.qty,
            unitCost: movement.unitCost,
            unitPrice: movement.unitPrice,
            reason: Value(movement.reason),
            byUserId: movement.byUserId,
            at: movement.at,
          ),
        );
  }

  Future<void> _upsertSale(Sale sale) async {
    await db
        .into(db.sales)
        .insertOnConflictUpdate(
          SalesCompanion.insert(
            id: sale.id,
            shopId: sale.shopId,
            totalAmount: sale.totalAmount,
            byUserId: sale.byUserId,
            createdAt: sale.createdAt,
          ),
        );
  }

  Future<void> _upsertSaleItem(SaleItem item) async {
    await db
        .into(db.saleItems)
        .insertOnConflictUpdate(
          SaleItemsCompanion.insert(
            id: item.id,
            saleId: item.saleId,
            itemId: item.itemId,
            itemName: item.itemName,
            quantity: item.quantity,
            unitPrice: item.unitPrice,
            totalPrice: item.totalPrice,
          ),
        );
  }

  // ---------- Sync Ops Management ----------

  Future<List<SyncOp>> _getPendingOps(String entity) async {
    return await (db.select(
      db.syncOps,
    )..where((t) => t.entity.equals(entity) & t.sent.equals(false))).get();
  }

  Future<void> _markOpsAsSent(List<String> uuids) async {
    for (final uuid in uuids) {
      await (db.update(db.syncOps)..where((t) => t.uuid.equals(uuid))).write(
        SyncOpsCompanion(sent: const Value(true)),
      );
    }
  }
}
