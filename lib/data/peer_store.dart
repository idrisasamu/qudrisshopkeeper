import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'local/app_database.dart';
import '../app/main.dart';

final peerStoreProvider = Provider<PeerStore>((ref) {
  final db = ref.read(dbProvider);
  return PeerStore(db);
});

class PeerStore {
  final AppDatabase db;

  PeerStore(this.db);

  Future<List<Map<String, dynamic>>> listPeers() async {
    // Stub implementation - return empty list for now
    return [];
  }

  Future<void> upsertPeer(
    String deviceId,
    Map<String, dynamic> peerData,
  ) async {
    // Stub implementation - just print for now
    print('Upserting peer: $deviceId with data: $peerData');
  }

  Future<void> removePeer(String deviceId) async {
    // Stub implementation - just print for now
    print('Removing peer: $deviceId');
  }

  Future<void> savePeer(dynamic peerInfo) async {
    // Stub implementation - just print for now
    print('Saving peer: $peerInfo');
  }
}
