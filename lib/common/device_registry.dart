import 'dart:math';
import 'package:drift/drift.dart' as dr;
import '../data/local/app_database.dart';

class DeviceRegistry {
  final AppDatabase db;
  DeviceRegistry(this.db);

  Future<String> _randId(String prefix) async {
    final rnd = Random.secure();
    final bytes = List<int>.generate(6, (_) => rnd.nextInt(256));
    return '$prefix-${bytes.map((b)=>b.toRadixString(16).padLeft(2,'0')).join()}';
  }

  Future<String> getOrCreateDeviceId() async {
    final k = 'device_id';
    final row = await (db.select(db.kvStore)..where((t) => t.key.equals(k))).getSingleOrNull();
    if (row != null) return row.value;
    final id = await _randId('DEV');
    await db.into(db.kvStore).insert(dr.Value(k), dr.Value(id));
    return id;
  }

  Future<void> setShopIds({required String shopId, required String shopShortId, required bool isAdmin}) async {
    await db.batch((b) {
      b.insert(db.kvStore, KvStoreCompanion.insert(key: 'shop_id', value: shopId), mode: dr.InsertMode.insertOrReplace);
      b.insert(db.kvStore, KvStoreCompanion.insert(key: 'shop_short_id', value: shopShortId), mode: dr.InsertMode.insertOrReplace);
      b.insert(db.kvStore, KvStoreCompanion.insert(key: 'is_admin', value: isAdmin ? '1' : '0'), mode: dr.InsertMode.insertOrReplace);
    });
  }

  Future<String?> shopId() async => (await (db.select(db.kvStore)..where((t)=>t.key.equals('shop_id'))).getSingleOrNull())?.value;
  Future<String?> shopShortId() async => (await (db.select(db.kvStore)..where((t)=>t.key.equals('shop_short_id'))).getSingleOrNull())?.value;
  Future<bool> isAdmin() async => ((await (db.select(db.kvStore)..where((t)=>t.key.equals('is_admin'))).getSingleOrNull())?.value) == '1';
}
