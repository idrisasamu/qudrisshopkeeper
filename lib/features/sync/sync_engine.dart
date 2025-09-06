import '../..//data/local/app_database.dart';

/// Represents a single operation to sync between devices.
class SyncOp {
  final String uuid; // unique id for dedupe
  final String entity; // table name e.g. items, sales
  final String op; // "create" or "update"
  final Map<String, dynamic> payload; // serialized row
  final int ts; // timestamp UTC ms
  final String deviceId; // origin device

  SyncOp({
    required this.uuid,
    required this.entity,
    required this.op,
    required this.payload,
    required this.ts,
    required this.deviceId,
  });
}

/// Represents a batch of operations for transfer.
class Delta {
  final String fromDevice;
  final String toDevice;
  final int ts;
  final List<SyncOp> ops;

  Delta({
    required this.fromDevice,
    required this.toDevice,
    required this.ts,
    required this.ops,
  });
}

abstract class SyncEngine {
  /// Add a new operation (local create/update).
  Future<void> enqueueOp(SyncOp op);

  /// Apply remote operations, dedupe by uuid.
  Future<void> applyRemoteOps(List<SyncOp> ops);

  /// Build a delta to send to a peer.
  Future<Delta> buildDeltaForPeer(String peerDeviceId, {int maxOps = 100});

  /// Mark operations as acknowledged by a peer.
  Future<void> markAcked(String peerDeviceId, List<String> uuids);

  /// Try to reconcile with all available transports (email, sms, qr).
  Future<void> reconcile();
}
