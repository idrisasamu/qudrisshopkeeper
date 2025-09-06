import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'app_database.g.dart';

@DataClassName('Shop')
class Shops extends Table {
  TextColumn get id => text()(); // uuid
  TextColumn get name => text()();
  TextColumn get ownerUserId => text()();
  TextColumn get smsHubPhone => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('UserRow')
class Users extends Table {
  TextColumn get id => text()();
  TextColumn get shopId => text()();
  TextColumn get role => text()(); // 'admin' | 'sales'
  TextColumn get phone => text()();
  TextColumn get email => text().nullable()();
  TextColumn get username => text()(); // chosen by Admin
  TextColumn get status => text().withDefault(const Constant('active'))();
  DateTimeColumn get joinedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('Item')
class Items extends Table {
  TextColumn get id => text()();
  TextColumn get shopId => text()();
  TextColumn get name => text()();
  TextColumn get sku => text().nullable()();
  TextColumn get barcode => text().nullable()();
  TextColumn get category => text().nullable()();
  TextColumn get unit => text().withDefault(const Constant('unit'))();
  RealColumn get costPrice => real().withDefault(const Constant(0.0))();
  RealColumn get salePrice => real().withDefault(const Constant(0.0))();
  RealColumn get minQty => real().withDefault(const Constant(0.0))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('StockMovement')
class StockMovements extends Table {
  TextColumn get id => text()();
  TextColumn get shopId => text()();
  TextColumn get itemId => text()();
  TextColumn get type => text()(); // 'purchase' | 'sale' | 'adjust'
  RealColumn get qty => real()(); // positive or negative
  RealColumn get unitCost => real().nullable()();
  RealColumn get unitPrice => real().nullable()();
  TextColumn get reason => text().nullable()();
  TextColumn get byUserId => text()();
  DateTimeColumn get at => dateTime()();
  TextColumn get refId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('Sale')
class Sales extends Table {
  TextColumn get id => text()();
  TextColumn get shopId => text()();
  TextColumn get cashierId => text()();
  DateTimeColumn get at => dateTime()();
  RealColumn get total => real().withDefault(const Constant(0.0))();
  TextColumn get paymentMethod => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('SaleLine')
class SaleLines extends Table {
  TextColumn get id => text()();
  TextColumn get saleId => text()();
  TextColumn get itemId => text()();
  RealColumn get qty => real()();
  RealColumn get unitPrice => real()();
  RealColumn get lineTotal => real()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('AlertRow')
class Alerts extends Table {
  TextColumn get id => text()();
  TextColumn get shopId => text()();
  TextColumn get itemId => text()();
  RealColumn get threshold => real()();
  DateTimeColumn get triggeredAt => dateTime()();
  DateTimeColumn get resolvedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('SyncOpRow')
class SyncOps extends Table {
  TextColumn get uuid => text()(); // primary key for idempotency
  TextColumn get entity => text()(); // table name
  TextColumn get op => text()(); // 'create'|'update'
  TextColumn get payloadJson => text()(); // serialized row json
  IntColumn get ts => integer()(); // utc ms
  TextColumn get deviceId => text()();
  BoolColumn get applied => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {uuid};
}

@DataClassName('Kv')
class KvStore extends Table {
  TextColumn get key => text()(); // e.g., 'lastRemoteTs', 'peer:<id>:lastAck'
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

@DriftDatabase(
  tables: [
    Shops,
    Users,
    Items,
    StockMovements,
    Sales,
    SaleLines,
    Alerts,
    SyncOps,
    KvStore,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  // --- Convenience queries / views ---

  /// Sum of qty per item = on hand.
  Future<double> onHandForItem(String itemId) async {
    final res = await (select(
      stockMovements,
    )..where((m) => m.itemId.equals(itemId))).get();
    return res.fold<double>(0.0, (acc, m) => acc + m.qty);
  }

  /// Today revenue (local time).
  Future<double> todayRevenue() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    final res = await (select(
      sales,
    )..where((s) => s.at.isBetweenValues(start, end))).get();
    return res.fold<double>(0.0, (acc, s) => acc + s.total);
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'qsk.db'));
    return NativeDatabase.createInBackground(file);
  });
}
