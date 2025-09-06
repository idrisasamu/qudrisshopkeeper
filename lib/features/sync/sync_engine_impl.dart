import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart' as dr;
import '../../data/local/app_database.dart';
import '../../common/uuid.dart';
import 'sync_engine.dart';

/// Basic implementation that:
///  - enqueues local ops to SyncOps table
///  - applies remote ops idempotently
///  - builds deltas per peer from unapplied ops
/// Transport-specific sending/receiving is handled elsewhere.
class SyncEngineImpl implements SyncEngine {
  final AppDatabase db;
  final String selfDeviceId;

  SyncEngineImpl({required this.db, required this.selfDeviceId});

  @override
  Future<void> enqueueOp(SyncOp op) async {
    final jsonStr = jsonEncode(op.payload);
    await db
        .into(db.syncOps)
        .insertOnConflictUpdate(
          SyncOpsCompanion.insert(
            uuid: op.uuid,
            entity: op.entity,
            op: op.op,
            payloadJson: jsonStr,
            ts: op.ts,
            deviceId: op.deviceId,
            applied: const dr.Value(false),
          ),
        );
  }

  @override
  Future<void> applyRemoteOps(List<SyncOp> ops) async {
    await db.transaction(() async {
      for (final op in ops) {
        // Deduplicate by uuid
        final existing = await (db.select(
          db.syncOps,
        )..where((t) => t.uuid.equals(op.uuid))).getSingleOrNull();
        if (existing != null) continue;

        // Apply entity mutation
        await _apply(op);

        // Record op as applied to prevent re-applying.
        await db
            .into(db.syncOps)
            .insert(
              SyncOpsCompanion.insert(
                uuid: op.uuid,
                entity: op.entity,
                op: op.op,
                payloadJson: jsonEncode(op.payload),
                ts: op.ts,
                deviceId: op.deviceId,
                applied: const dr.Value(true),
              ),
            );
      }
    });
  }

  Future<void> _apply(SyncOp op) async {
    switch (op.entity) {
      case 'items':
        if (op.op == 'create') {
          final p = op.payload;
          await db
              .into(db.items)
              .insert(
                db.items.fromJson(p as Map<String, dynamic>),
                mode: dr.InsertMode.insertOrReplace,
              );
        } else if (op.op == 'update') {
          final p = op.payload;
          final id = p['id'] as String;
          await (db.update(db.items)..where((t) => t.id.equals(id))).write(
            db.items.fromJson(p as Map<String, dynamic>).toCompanion(true),
          );
        }
        break;
      case 'stock_movements':
        if (op.op == 'create') {
          final p = op.payload;
          await db
              .into(db.stockMovements)
              .insert(
                db.stockMovements.fromJson(p as Map<String, dynamic>),
                mode: dr.InsertMode.insertOrIgnore, // movements are immutable
              );
        }
        break;
      case 'sales':
        if (op.op == 'create') {
          final p = op.payload as Map<String, dynamic>;
          // Expect embedded sale + lines arrays
          final sale = p['sale'] as Map<String, dynamic>;
          final lines = (p['lines'] as List).cast<Map<String, dynamic>>();
          await db.transaction(() async {
            await db
                .into(db.sales)
                .insert(
                  db.sales.fromJson(sale),
                  mode: dr.InsertMode.insertOrIgnore,
                );
            for (final l in lines) {
              await db
                  .into(db.saleLines)
                  .insert(
                    db.saleLines.fromJson(l),
                    mode: dr.InsertMode.insertOrIgnore,
                  );
            }
            // Derive movements are expected to be included separately OR recompute if needed.
          });
        }
        break;
      default:
        if (kDebugMode) {
          print('Unknown entity ${op.entity}, ignoring.');
        }
    }
  }

  @override
  Future<Delta> buildDeltaForPeer(
    String peerDeviceId, {
    int maxOps = 100,
  }) async {
    // For now, send unapplied ops regardless of origin device (upper layers may filter).
    final rows =
        await (db.select(db.syncOps)
              ..where((t) => t.applied.equals(false))
              ..orderBy([(t) => dr.OrderingTerm.asc(t.ts)])
              ..limit(maxOps))
            .get();

    final ops = rows
        .map(
          (r) => SyncOp(
            uuid: r.uuid,
            entity: r.entity,
            op: r.op,
            payload: jsonDecode(r.payloadJson) as Map<String, dynamic>,
            ts: r.ts,
            deviceId: r.deviceId,
          ),
        )
        .toList();

    return Delta(
      fromDevice: selfDeviceId,
      toDevice: peerDeviceId,
      ts: DateTime.now().toUtc().millisecondsSinceEpoch,
      ops: ops,
    );
  }

  @override
  Future<void> markAcked(String peerDeviceId, List<String> uuids) async {
    // Optionally mark as applied/sent to that peer using KvStore (per-peer watermark).
    final key = 'peer:$peerDeviceId:lastAck';
    final val = uuids.isNotEmpty ? uuids.last : '';
    await db
        .into(db.kvStore)
        .insertOnConflictUpdate(KvStoreCompanion.insert(key: key, value: val));
  }

  @override
  Future<void> reconcile() async {
    // Placeholder: transports will call buildDeltaForPeer() and send.
    // Here you can orchestrate: check peers from Users table, build/send, poll inbox, apply.
  }
}

/// Helper to create a SyncOp for local inserts/updates.
SyncOp makeOp({
  required String entity,
  required String op,
  required Map<String, dynamic> payload,
  required String deviceId,
}) {
  return SyncOp(
    uuid: newId(),
    entity: entity,
    op: op,
    payload: payload,
    ts: DateTime.now().toUtc().millisecondsSinceEpoch,
    deviceId: deviceId,
  );
}
