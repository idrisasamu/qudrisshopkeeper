import 'dart:convert';
import 'package:drift/drift.dart' as dr;
import 'local/app_database.dart';
import 'peers.dart';

class PeerStore {
  final AppDatabase db;
  PeerStore(this.db);

  Future<void> savePeer(PeerInfo p) async {
    final k = 'peer:${p.deviceId}';
    final v = jsonEncode({
      'deviceId': p.deviceId,
      'username': p.username,
      'phone': p.phone,
      'email': p.email,
      'isAdmin': p.isAdmin,
    });
    await db.into(db.kvStore).insertOnConflictUpdate(dr.Value(k), dr.Value(v));
  }

  Future<List<PeerInfo>> listPeers() async {
    final rows = await (db.select(db.kvStore)..where((t) => t.key.like('peer:%'))).get();
    return rows.map((r) {
      final j = jsonDecode(r.value) as Map<String, dynamic>;
      return PeerInfo(
        deviceId: j['deviceId'],
        username: j['username'],
        phone: j['phone'],
        email: j['email'],
        isAdmin: j['isAdmin'] == true,
      );
    }).toList();
  }
}
