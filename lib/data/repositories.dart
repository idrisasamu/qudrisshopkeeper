import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app/main.dart';
import 'local/app_database.dart';
import 'local/daos/item_dao.dart';
import 'local/daos/sales_dao.dart';
import 'local/daos/movement_dao.dart';
import '../features/sync/sync_engine_impl.dart';
import '../features/sync/sync_engine.dart';

final itemDaoProvider = Provider<ItemDao>(
  (ref) => ItemDao(ref.read(dbProvider)),
);
final salesDaoProvider = Provider<SalesDao>(
  (ref) => SalesDao(ref.read(dbProvider)),
);
final movementDaoProvider = Provider<MovementDao>(
  (ref) => MovementDao(ref.read(dbProvider)),
);

final deviceIdProvider = Provider<String>(
  (_) => 'DEVICE-${DateTime.now().millisecondsSinceEpoch}',
); // TODO: stable device id

final syncEngineProvider = Provider<SyncEngine>((ref) {
  final db = ref.read(dbProvider);
  final deviceId = ref.read(deviceIdProvider);
  return SyncEngineImpl(db: db, selfDeviceId: deviceId);
});
