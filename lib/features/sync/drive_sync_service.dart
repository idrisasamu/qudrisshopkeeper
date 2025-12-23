import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../data/local/app_database.dart';
import '../../common/session.dart';
import '../../common/uuid.dart';
import 'drive_client.dart';
import 'sync_utils.dart';
import 'sync_errors.dart';
import 'crypto_box.dart';

class DriveSyncService {
  final AppDatabase db;
  final GoogleSignIn gsignIn;
  final DriveClient drive;

  DriveSyncService(this.db, this.gsignIn, this.drive);

  // KV helpers for IDs + watermarks
  Future<String?> get _shopId async => _sessionManager.getString('shop_id');
  Future<String?> get _broadcastId async =>
      _sessionManager.getString('drive_broadcast_folder_id');
  Future<String?> get _inboxRootId async =>
      _sessionManager.getString('drive_inbox_root_id');

  final SessionManager _sessionManager = SessionManager();

  Future<int> _getWatermark(String key) async {
    final value = await _sessionManager.getString(key);
    return int.tryParse(value ?? '0') ?? 0;
  }

  Future<void> _setWatermark(String key, int v) async {
    await _sessionManager.setString(key, v.toString());
  }

  // ----- PUBLIC API -----
  Future<void> syncNow({required bool isAdmin, required String myEmail}) async {
    print(
      'DEBUG: DriveSyncService.syncNow - isAdmin: $isAdmin, email: $myEmail',
    );

    final driveEnabled = await _sessionManager.isDriveEnabled();
    print('DEBUG: Drive sync enabled: $driveEnabled');
    if (!driveEnabled) {
      print('DEBUG: Drive sync not enabled, skipping sync');
      return;
    }

    print('DEBUG: Starting push operation');
    await _push(isAdmin: isAdmin, myEmail: myEmail);

    print('DEBUG: Starting pull operation');
    await _pull(isAdmin: isAdmin, myEmail: myEmail);

    await _sessionManager.setString(
      'last_sync_at',
      DateTime.now().millisecondsSinceEpoch.toString(),
    );

    print('DEBUG: Sync completed successfully');
  }

  /// Rotate the shop key and broadcast the rotation
  Future<void> rotateShopKey() async {
    final newK = CryptoBox.generateShopKey();
    final newVer = (await _sessionManager.getInt('shop_key_version') ?? 1) + 1;
    await _sessionManager.setString('shop_key_b64', newK);
    await _sessionManager.setInt('shop_key_version', newVer);

    await _broadcastKeyRotation(newVer);
  }

  /// Broadcast a key rotation control message
  Future<void> _broadcastKeyRotation(int newVersion) async {
    final parentId = await _broadcastId;
    if (parentId == null) throw Exception('Broadcast folder not set');

    final payload = {
      'type': 'key_rotation',
      'keyVersion': newVersion,
      'ts': DateTime.now().toUtc().toIso8601String(),
    };
    final enc = await SyncCodec.encryptJson(payload);
    final fname = SyncCodec.makeFileName('key_rotation_$newVersion.json');
    await drive.uploadString(parentId, fname, enc);
  }

  // ----- PUSH -----
  Future<void> _push({required bool isAdmin, required String myEmail}) async {
    final unsent = await (db.select(
      db.syncOps,
    )..where((t) => t.sent.equals(false))).get();
    if (unsent.isEmpty) return;

    final ops = unsent
        .map(
          (e) => {
            'uuid': e.uuid,
            'entity': e.entity,
            'op': e.op,
            'ts': e.ts,
            'payload': jsonDecode(e.payload),
          },
        )
        .toList();

    final shopId = await _shopId ?? 'UNKNOWN';
    final header = {
      'v': 1,
      'shopId': shopId,
      'from': myEmail,
      'role': isAdmin ? 'admin' : 'sales',
      'ts': DateTime.now().millisecondsSinceEpoch,
    };
    final payload = {...header, 'ops': ops};

    // Encrypt the payload
    final encryptedContent = await SyncCodec.encryptJson(payload);

    String parentId;
    if (isAdmin) {
      // Admin pushes to broadcast
      parentId = (await _broadcastId)!;
    } else {
      // Sales pushes to its own inbox subfolder
      final inboxRoot = (await _inboxRootId)!;
      final myFolder =
          await drive.findChildFolderId(inboxRoot, myEmail) ??
          (await drive.createFolder(myEmail, parentId: inboxRoot)).id!;
      parentId = myFolder;
    }

    final baseFileName =
        '${isAdmin ? 'A' : 'S'}-${shopId.substring(0, 8)}-${_hashEmail(myEmail)}-${header['ts']}.json';
    final fileName = SyncCodec.makeFileName(baseFileName);
    await drive.uploadString(
      parentId,
      fileName,
      encryptedContent,
      mimeType: 'text/plain',
    );

    // mark as sent
    await db.batch((b) {
      for (final r in unsent) {
        b.update(
          db.syncOps,
          r.copyWith(sent: true),
          where: (t) => t.uuid.equals(r.uuid),
        );
      }
    });
  }

  // ----- PULL -----
  Future<void> _pull({required bool isAdmin, required String myEmail}) async {
    print('DEBUG: _pull - isAdmin: $isAdmin, email: $myEmail');

    if (isAdmin) {
      // Admin pulls from all inbox subfolders
      final inboxRoot = (await _inboxRootId)!;
      print('DEBUG: Admin pulling from inbox root: $inboxRoot');
      final subfolders = await drive.listChildFolders(inboxRoot);
      print('DEBUG: Found ${subfolders.length} inbox subfolders');
      for (final f in subfolders) {
        await _pullFolder(folderId: f.id!, watermarkKey: 'wm_inbox_${f.id!}');
      }
    } else {
      // Sales pulls from broadcast
      final broadcastId = (await _broadcastId)!;
      print('DEBUG: Staff pulling from broadcast folder: $broadcastId');
      await _pullFolder(folderId: broadcastId, watermarkKey: 'wm_broadcast');
    }
  }

  Future<void> _pullFolder({
    required String folderId,
    required String watermarkKey,
  }) async {
    final since = await _getWatermark(watermarkKey);
    print('DEBUG: _pullFolder - folderId: $folderId, since: $since');

    final files = await drive.listNewJsonFiles(
      folderId,
      sinceModifiedMs: since,
    );
    print('DEBUG: Found ${files.length} new files in folder $folderId');

    for (final f in files) {
      try {
        print('DEBUG: Processing file: ${f.name} (${f.id})');
        final text = await drive.downloadString(f.id!);
        await _applyDelta(text, fileName: f.name ?? 'file');
        final modifiedMs = f.modifiedTime?.millisecondsSinceEpoch ?? 0;
        if (modifiedMs > since) await _setWatermark(watermarkKey, modifiedMs);
        print('DEBUG: Successfully applied file: ${f.name}');
      } catch (e) {
        print('Failed to apply ${f.name}: ${friendlySyncError(e)}');
        // Continue with other files even if one fails
      }
    }
  }

  // ----- APPLY -----
  Future<void> _applyDelta(String content, {required String fileName}) async {
    final obj = await SyncCodec.decodeFromDrive(
      fileName: fileName,
      content: content,
    );

    // Handle key rotation control messages
    if (obj['type'] == 'key_rotation') {
      final remoteVer = (obj['keyVersion'] as num?)?.toInt() ?? 0;
      final localVer = await _sessionManager.getInt('shop_key_version') ?? 1;
      if (remoteVer > localVer) {
        print('Key rotation detected: remote v$remoteVer > local v$localVer');
        // This will be handled by UI banners in the staff home page
        await _sessionManager.setString(
          'needed_key_version',
          remoteVer.toString(),
        );
      }
      return;
    }

    final ops = (obj['ops'] as List).cast<Map<String, dynamic>>();

    await db.transaction(() async {
      for (final o in ops) {
        final id = o['uuid'] as String;
        final already = await (db.select(
          db.appliedOps,
        )..where((t) => t.uuid.equals(id))).getSingleOrNull();
        if (already != null) continue;

        switch (o['entity']) {
          case 'item':
            await _applyItemUpsert(o['payload']);
            break;
          case 'stock':
            await _applyStockAdjust(o['payload']);
            break;
          case 'sale':
            await _applySaleCreate(o['payload']);
            break;
          case 'user':
            await _applyUserUpsert(o['payload']);
            break;
          case 'shop':
            await _applyShopUpsert(o['payload']);
            break;
        }

        await db
            .into(db.appliedOps)
            .insert(
              AppliedOpsCompanion.insert(
                uuid: id,
                ts: DateTime.now().millisecondsSinceEpoch,
              ),
            );
      }
    });
  }

  // Implement using existing DAOs:
  Future<void> _applyItemUpsert(Map<String, dynamic> p) async {
    final itemId = p['id'] as String;
    final shopId = p['shopId'] as String; // Get shop_id from payload
    final name = p['name'] as String;
    final price = (p['price'] as num).toDouble();
    final minQty = (p['minQty'] as num).toDouble();
    final isActive = p['isActive'] as bool? ?? true;

    // If you track updatedAt locally, do LWW here by comparing p['ts'] vs local updatedAt.
    final existing = await (db.select(
      db.items,
    )..where((t) => t.id.equals(itemId))).getSingleOrNull();

    if (existing == null) {
      // Use the shop_id from the payload, not the current session
      await db
          .into(db.items)
          .insert(
            ItemsCompanion.insert(
              id: itemId,
              shopId: shopId, // Use shop_id from sync payload
              name: name,
              sku: const Value(null),
              barcode: const Value(null),
              category: const Value(null),
              unit: 'pcs',
              costPrice: 0.0,
              salePrice: price,
              minQty: minQty,
              isActive: isActive,
              updatedAt: DateTime.now(),
            ),
          );
    } else {
      // LWW: only update if incoming timestamp is newer
      final incomingTs = p['ts'] as int;
      final localTs = existing.updatedAt.millisecondsSinceEpoch;

      if (incomingTs >= localTs) {
        await (db.update(db.items)..where((t) => t.id.equals(itemId))).write(
          ItemsCompanion(
            name: Value(name),
            salePrice: Value(price),
            minQty: Value(minQty),
            isActive: Value(isActive),
            updatedAt: Value(DateTime.now()),
          ),
        );
      }
    }
  }

  Future<void> _applyStockAdjust(Map<String, dynamic> p) async {
    // payload: { itemId, shopId, delta, reason, ts }
    final itemId = p['itemId'] as String;
    final shopId = p['shopId'] as String; // Get shop_id from payload
    final delta = (p['delta'] as num).toDouble();
    final reason = (p['reason'] as String?) ?? 'sync';
    final ts = p['ts'] as int? ?? DateTime.now().millisecondsSinceEpoch;

    // Insert movement (if you have a movements table)
    await db
        .into(db.stockMovements)
        .insert(
          StockMovementsCompanion.insert(
            id: newId(),
            shopId: shopId, // Use shop_id from sync payload
            itemId: itemId,
            type: delta > 0 ? 'in' : 'out',
            qty: delta.abs(),
            unitCost: 0.0,
            unitPrice: 0.0,
            reason: Value(reason),
            byUserId: 'sync',
            at: DateTime.fromMillisecondsSinceEpoch(ts),
          ),
        );
  }

  Future<void> _applySaleCreate(Map<String, dynamic> p) async {
    // payload: { sale: {...}, lines: [...] }
    final saleJson = Map<String, dynamic>.from(p['sale'] as Map);
    final linesJson = (p['lines'] as List).cast<Map<String, dynamic>>();

    // Insert sale header
    final saleId = saleJson['id'] as String;
    final total = (saleJson['totalAmount'] as num?)?.toDouble() ?? 0.0;
    final createdAtMs =
        saleJson['createdAt'] as int? ?? DateTime.now().millisecondsSinceEpoch;

    await db
        .into(db.sales)
        .insert(
          SalesCompanion.insert(
            id: saleId,
            shopId: saleJson['shopId'] as String? ?? 'SHOP-LOCAL',
            totalAmount: total,
            byUserId: saleJson['byUserId'] as String? ?? 'sync',
            createdAt: DateTime.fromMillisecondsSinceEpoch(createdAtMs),
          ),
        );

    // Insert lines + decrease stock
    for (final l in linesJson) {
      final itemId = l['itemId'] as String;
      final qty = (l['quantity'] as num).toDouble();
      final price = (l['unitPrice'] as num).toDouble();

      await db
          .into(db.saleItems)
          .insert(
            SaleItemsCompanion.insert(
              id: l['id'] as String,
              saleId: saleId,
              itemId: itemId,
              itemName: l['itemName'] as String,
              quantity: qty,
              unitPrice: price,
              totalPrice: qty * price,
            ),
          );

      // Deduct stock via movement to keep history consistent
      await _applyStockAdjust({
        'itemId': itemId,
        'shopId': saleJson['shopId'] as String, // Include shop_id
        'delta': -qty,
        'reason': 'sale:$saleId',
        'ts': p['ts'] ?? DateTime.now().millisecondsSinceEpoch,
      });
    }
  }

  Future<void> _applyUserUpsert(Map<String, dynamic> p) async {
    final userId = p['id'] as String;
    final shopId = p['shopId'] as String;
    final name = p['name'] as String;
    final email = p['email'] as String;
    final role = p['role'] as String;
    final isActive = p['isActive'] as bool? ?? true;
    final createdAtMs =
        p['createdAt'] as int? ?? DateTime.now().millisecondsSinceEpoch;

    final existing = await (db.select(
      db.users,
    )..where((t) => t.id.equals(userId))).getSingleOrNull();

    if (existing == null) {
      await db
          .into(db.users)
          .insert(
            UsersCompanion.insert(
              id: userId,
              shopId: shopId,
              username: email.split('@')[0], // Use email prefix as username
              name: name,
              email: email,
              role: role,
              isActive: Value(isActive),
              passwordHash: 'temp', // Will be updated later
              salt: 'temp', // Will be updated later
              createdAt: Value(DateTime.fromMillisecondsSinceEpoch(createdAtMs)),
            ),
          );
    } else {
      // LWW: only update if incoming timestamp is newer
      final incomingTs = p['ts'] as int;
      final localTs = existing.createdAt.millisecondsSinceEpoch;

      if (incomingTs >= localTs) {
        await (db.update(db.users)..where((t) => t.id.equals(userId))).write(
          UsersCompanion(
            shopId: Value(shopId),
            name: Value(name),
            email: Value(email),
            role: Value(role),
            isActive: Value(isActive),
          ),
        );
      }
    }
  }

  Future<void> _applyShopUpsert(Map<String, dynamic> p) async {
    final shopId = p['id'] as String;
    final name = p['name'] as String;
    final email = p['email'] as String;
    final key = p['key'] as String;
    final appPassword = p['appPassword'] as String;
    final createdAtMs =
        p['createdAt'] as int? ?? DateTime.now().millisecondsSinceEpoch;

    final existing = await (db.select(
      db.shops,
    )..where((t) => t.id.equals(shopId))).getSingleOrNull();

    if (existing == null) {
      await db
          .into(db.shops)
          .insert(
            ShopsCompanion.insert(
              id: shopId,
              name: name,
              email: email,
              ownerName: 'Owner', // Default value
              country: 'Unknown', // Default value
              city: 'Unknown', // Default value
              key: key,
              appPassword: appPassword,
              createdAt: DateTime.fromMillisecondsSinceEpoch(createdAtMs),
            ),
          );
    } else {
      // LWW: only update if incoming timestamp is newer
      final incomingTs = p['ts'] as int;
      final localTs = existing.createdAt.millisecondsSinceEpoch;

      if (incomingTs >= localTs) {
        await (db.update(db.shops)..where((t) => t.id.equals(shopId))).write(
          ShopsCompanion(
            name: Value(name),
            email: Value(email),
            key: Value(key),
            appPassword: Value(appPassword),
          ),
        );
      }
    }
  }

  String _hashEmail(String e) =>
      sha1.convert(utf8.encode(e)).toString().substring(0, 8);
}
