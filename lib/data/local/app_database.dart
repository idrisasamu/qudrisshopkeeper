import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift_sqflite/drift_sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'app_database.g.dart';

@DataClassName('Item')
class Items extends Table {
  TextColumn get id => text()();
  TextColumn get shopId => text()();
  TextColumn get name => text()();
  TextColumn get sku => text().nullable()();
  TextColumn get barcode => text().nullable()();
  TextColumn get category => text().nullable()();
  TextColumn get unit => text()();
  RealColumn get costPrice => real()();
  RealColumn get salePrice => real()();
  RealColumn get minQty => real()();
  BoolColumn get isActive => boolean()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('StockMovement')
class StockMovements extends Table {
  TextColumn get id => text()();
  TextColumn get shopId => text()();
  TextColumn get itemId => text()();
  TextColumn get type => text()(); // 'in', 'out', 'adjust'
  RealColumn get qty => real()();
  RealColumn get unitCost => real()();
  RealColumn get unitPrice => real()();
  TextColumn get reason => text().nullable()();
  TextColumn get byUserId => text()();
  DateTimeColumn get at => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('Sale')
class Sales extends Table {
  TextColumn get id => text()();
  TextColumn get shopId => text()();
  RealColumn get totalAmount => real()();
  TextColumn get byUserId => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('SaleItem')
class SaleItems extends Table {
  TextColumn get id => text()();
  TextColumn get saleId => text()();
  TextColumn get itemId => text()();
  TextColumn get itemName => text()();
  RealColumn get quantity => real()();
  RealColumn get unitPrice => real()();
  RealColumn get totalPrice => real()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('User')
class Users extends Table {
  TextColumn get id => text()();
  TextColumn get shopId => text()();
  TextColumn get username => text().unique()(); // unique per shop
  TextColumn get name => text()(); // display name
  TextColumn get email => text()(); // email address
  TextColumn get role => text()(); // 'admin' | 'staff'
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  // security
  TextColumn get passwordHash => text()(); // base64
  TextColumn get salt => text()(); // base64
  TextColumn get kdf =>
      text().withDefault(const Constant('pbkdf2-sha256/150000'))();

  // new fields for default pin flow
  BoolColumn get mustChangePassword =>
      boolean().withDefault(const Constant(false))();
  DateTimeColumn get passwordUpdatedAt => dateTime().nullable()();

  // sync
  IntColumn get rev => integer().withDefault(const Constant(1))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('Shop')
class Shops extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get email => text()();
  TextColumn get key => text()();
  TextColumn get appPassword => text()();
  TextColumn get ownerName => text()();
  TextColumn get country => text()();
  TextColumn get city => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('SyncOp')
class SyncOps extends Table {
  TextColumn get uuid => text()();
  TextColumn get entity => text()(); // e.g., items, stock, sales
  TextColumn get op => text()(); // e.g., create, update, adjust
  TextColumn get payload => text()(); // json
  IntColumn get ts => integer()(); // milliseconds UTC
  BoolColumn get sent => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {uuid};
}

@DataClassName('AppliedOp')
class AppliedOps extends Table {
  TextColumn get uuid => text()(); // op id
  IntColumn get ts => integer()(); // when applied locally

  @override
  Set<Column> get primaryKey => {uuid};
}

@DriftDatabase(
  tables: [
    Items,
    StockMovements,
    Sales,
    SaleItems,
    Users,
    Shops,
    SyncOps,
    AppliedOps,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection()) {
    print('DEBUG: AppDatabase constructed');
  }

  @override
  int get schemaVersion => 11;

  /// Ensure database is open before operations
  Future<void> ensureOpen() async {
    // Check if database connection is valid by attempting a simple query
    try {
      await customSelect('SELECT 1').get();
    } catch (e) {
      throw Exception('Database is closed. Please restart the app.');
    }
  }

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
    },
    onUpgrade: (Migrator m, int from, int to) async {
      if (from == 1 && to == 2) {
        // Add new tables for sales
        await m.createTable(sales);
        await m.createTable(saleItems);
      }
      if (from <= 2 && to == 3) {
        // Add users table
        await m.createTable(users);
      }
      if (from <= 3 && to == 4) {
        // Add shops table
        await m.createTable(shops);
      }
      if (from <= 4 && to == 5) {
        // Ensure all tables exist with latest schema
        await m.createTable(users);
        await m.drop(shops);
        await m.createTable(shops);
      }
      if (from <= 5 && to == 6) {
        // Add sync operations table
        await m.createTable(syncOps);
      }
      if (from <= 6 && to == 7) {
        // Add applied operations table
        await m.createTable(appliedOps);
      }
      if (from <= 7 && to == 8) {
        // Update users table with new authentication fields
        await m.drop(users);
        await m.createTable(users);
      }
      if (from <= 8 && to == 9) {
        // Add PIN change fields to users table
        await m.addColumn(users, users.mustChangePassword);
        await m.addColumn(users, users.passwordUpdatedAt);
      }
      if (from <= 9 && to == 10) {
        // Update users table with new defaults and constraints
        await m.alterTable(
          TableMigration(
            users,
            newColumns: [users.mustChangePassword, users.passwordUpdatedAt],
          ),
        );
      }
      if (from <= 10 && to == 11) {
        // Add shop profile fields to existing shops table
        await m.addColumn(shops, shops.ownerName);
        await m.addColumn(shops, shops.country);
        await m.addColumn(shops, shops.city);
        await m.addColumn(shops, shops.updatedAt);

        // Add name and email fields to users table
        await m.addColumn(users, users.name);
        await m.addColumn(users, users.email);
      }
    },
  );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'qsk.db'));
    return SqfliteQueryExecutor.inDatabaseFolder(
      path: 'qsk.db',
      logStatements: false, // Disable logging to prevent issues
    );
  });
}
