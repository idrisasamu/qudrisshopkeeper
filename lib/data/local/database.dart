import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'database.g.dart';

// ================================================
// TABLES
// ================================================

@DataClassName('LocalProduct')
class Products extends Table {
  TextColumn get id => text()();
  TextColumn get shopId => text().named('shop_id')();
  TextColumn get categoryId => text().nullable().named('category_id')();
  TextColumn get sku => text()();
  TextColumn get barcode => text().nullable()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();

  IntColumn get priceCents => integer().named('price_cents')();
  IntColumn get costCents => integer().nullable().named('cost_cents')();
  RealColumn get taxRate =>
      real().withDefault(const Constant(0.0)).named('tax_rate')();

  BoolColumn get trackInventory =>
      boolean().withDefault(const Constant(true)).named('track_inventory')();
  IntColumn get reorderLevel =>
      integer().withDefault(const Constant(0)).named('reorder_level')();
  IntColumn get reorderQuantity =>
      integer().withDefault(const Constant(0)).named('reorder_quantity')();

  TextColumn get imagePath => text().nullable().named('image_path')();
  TextColumn get imageUrl => text().nullable().named('image_url')();

  BoolColumn get isActive =>
      boolean().withDefault(const Constant(true)).named('is_active')();
  BoolColumn get isFeatured =>
      boolean().withDefault(const Constant(false)).named('is_featured')();

  DateTimeColumn get createdAt => dateTime().named('created_at')();
  DateTimeColumn get updatedAt => dateTime().named('updated_at')();
  DateTimeColumn get deletedAt => dateTime().nullable().named('deleted_at')();
  DateTimeColumn get lastModified => dateTime().named('last_modified')();
  IntColumn get version => integer().withDefault(const Constant(1))();

  BoolColumn get dirty => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('LocalCategory')
class Categories extends Table {
  TextColumn get id => text()();
  TextColumn get shopId => text().named('shop_id')();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  TextColumn get parentId => text().nullable().named('parent_id')();
  TextColumn get color => text().nullable()();
  TextColumn get icon => text().nullable()();
  IntColumn get sortOrder =>
      integer().withDefault(const Constant(0)).named('sort_order')();
  BoolColumn get isActive =>
      boolean().withDefault(const Constant(true)).named('is_active')();

  DateTimeColumn get createdAt => dateTime().named('created_at')();
  DateTimeColumn get updatedAt => dateTime().named('updated_at')();
  DateTimeColumn get deletedAt => dateTime().nullable().named('deleted_at')();
  DateTimeColumn get lastModified => dateTime().named('last_modified')();
  IntColumn get version => integer().withDefault(const Constant(1))();

  BoolColumn get dirty => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('LocalInventory')
class Inventory extends Table {
  TextColumn get id => text()();
  TextColumn get shopId => text().named('shop_id')();
  TextColumn get productId => text().named('product_id')();

  IntColumn get onHandQty =>
      integer().withDefault(const Constant(0)).named('on_hand_qty')();
  IntColumn get reservedQty =>
      integer().withDefault(const Constant(0)).named('reserved_qty')();

  DateTimeColumn get lastCountedAt =>
      dateTime().nullable().named('last_counted_at')();

  DateTimeColumn get createdAt => dateTime().named('created_at')();
  DateTimeColumn get updatedAt => dateTime().named('updated_at')();
  DateTimeColumn get deletedAt => dateTime().nullable().named('deleted_at')();
  DateTimeColumn get lastModified => dateTime().named('last_modified')();
  IntColumn get version => integer().withDefault(const Constant(1))();

  BoolColumn get dirty => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('LocalStockMovement')
class StockMovements extends Table {
  TextColumn get id => text()();
  TextColumn get shopId => text().named('shop_id')();
  TextColumn get productId => text().named('product_id')();

  TextColumn get type => text()(); // sale, purchase, adjustment, return, damage
  IntColumn get qtyDelta => integer().named('qty_delta')();
  IntColumn get qtyBefore => integer().named('qty_before')();
  IntColumn get qtyAfter => integer().named('qty_after')();

  TextColumn get reason => text().nullable()();
  TextColumn get referenceId => text().nullable().named('reference_id')();
  TextColumn get referenceType => text().nullable().named('reference_type')();
  TextColumn get notes => text().nullable()();

  DateTimeColumn get createdAt => dateTime().named('created_at')();
  DateTimeColumn get updatedAt => dateTime().named('updated_at')();
  DateTimeColumn get deletedAt => dateTime().nullable().named('deleted_at')();
  DateTimeColumn get lastModified => dateTime().named('last_modified')();
  IntColumn get version => integer().withDefault(const Constant(1))();

  BoolColumn get dirty => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('LocalCustomer')
class Customers extends Table {
  TextColumn get id => text()();
  TextColumn get shopId => text().named('shop_id')();

  TextColumn get name => text()();
  TextColumn get email => text().nullable()();
  TextColumn get phone => text().nullable()();
  TextColumn get address => text().nullable()();
  TextColumn get city => text().nullable()();
  TextColumn get state => text().nullable()();

  IntColumn get loyaltyPoints =>
      integer().withDefault(const Constant(0)).named('loyalty_points')();
  IntColumn get totalSpentCents =>
      integer().withDefault(const Constant(0)).named('total_spent_cents')();
  IntColumn get totalOrders =>
      integer().withDefault(const Constant(0)).named('total_orders')();

  TextColumn get notes => text().nullable()();
  BoolColumn get isActive =>
      boolean().withDefault(const Constant(true)).named('is_active')();

  DateTimeColumn get createdAt => dateTime().named('created_at')();
  DateTimeColumn get updatedAt => dateTime().named('updated_at')();
  DateTimeColumn get deletedAt => dateTime().nullable().named('deleted_at')();
  DateTimeColumn get lastModified => dateTime().named('last_modified')();
  IntColumn get version => integer().withDefault(const Constant(1))();

  BoolColumn get dirty => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('LocalOrder')
class Orders extends Table {
  TextColumn get id => text()();
  TextColumn get shopId => text().named('shop_id')();
  TextColumn get customerId => text().nullable().named('customer_id')();

  TextColumn get orderNumber => text().named('order_number')();
  TextColumn get status => text()(); // draft, pending, paid, refunded, void
  TextColumn get channel => text().withDefault(
    const Constant('in_store'),
  )(); // in_store, online, phone

  IntColumn get subtotalCents =>
      integer().withDefault(const Constant(0)).named('subtotal_cents')();
  IntColumn get discountCents =>
      integer().withDefault(const Constant(0)).named('discount_cents')();
  IntColumn get taxCents =>
      integer().withDefault(const Constant(0)).named('tax_cents')();
  IntColumn get totalCents =>
      integer().withDefault(const Constant(0)).named('total_cents')();
  IntColumn get amountPaidCents =>
      integer().withDefault(const Constant(0)).named('amount_paid_cents')();

  DateTimeColumn get orderedAt => dateTime().named('ordered_at')();
  DateTimeColumn get paidAt => dateTime().nullable().named('paid_at')();
  DateTimeColumn get completedAt =>
      dateTime().nullable().named('completed_at')();

  TextColumn get notes => text().nullable()();
  TextColumn get deviceId => text().nullable().named('device_id')();

  DateTimeColumn get createdAt => dateTime().named('created_at')();
  DateTimeColumn get updatedAt => dateTime().named('updated_at')();
  DateTimeColumn get deletedAt => dateTime().nullable().named('deleted_at')();
  DateTimeColumn get lastModified => dateTime().named('last_modified')();
  IntColumn get version => integer().withDefault(const Constant(1))();

  BoolColumn get dirty => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('LocalOrderItem')
class OrderItems extends Table {
  TextColumn get id => text()();
  TextColumn get shopId => text().named('shop_id')();
  TextColumn get orderId => text().named('order_id')();
  TextColumn get productId => text().named('product_id')();

  TextColumn get productName => text().named('product_name')();
  TextColumn get productSku => text().nullable().named('product_sku')();

  IntColumn get quantity => integer()();
  IntColumn get unitPriceCents => integer().named('unit_price_cents')();
  IntColumn get discountCents =>
      integer().withDefault(const Constant(0)).named('discount_cents')();
  RealColumn get taxRate =>
      real().withDefault(const Constant(0.0)).named('tax_rate')();
  IntColumn get taxCents =>
      integer().withDefault(const Constant(0)).named('tax_cents')();
  IntColumn get lineTotalCents => integer().named('line_total_cents')();

  TextColumn get notes => text().nullable()();

  DateTimeColumn get createdAt => dateTime().named('created_at')();
  DateTimeColumn get updatedAt => dateTime().named('updated_at')();
  DateTimeColumn get deletedAt => dateTime().nullable().named('deleted_at')();
  DateTimeColumn get lastModified => dateTime().named('last_modified')();
  IntColumn get version => integer().withDefault(const Constant(1))();

  BoolColumn get dirty => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('LocalPayment')
class Payments extends Table {
  TextColumn get id => text()();
  TextColumn get shopId => text().named('shop_id')();
  TextColumn get orderId => text().named('order_id')();

  TextColumn get method => text()(); // cash, card, transfer, mobile_money
  IntColumn get amountCents => integer().named('amount_cents')();

  TextColumn get transactionRef => text().nullable().named('transaction_ref')();
  TextColumn get receiptPath => text().nullable().named('receipt_path')();
  TextColumn get receiptUrl => text().nullable().named('receipt_url')();

  TextColumn get status => text().withDefault(const Constant('completed'))();
  DateTimeColumn get processedAt => dateTime().named('processed_at')();

  TextColumn get notes => text().nullable()();

  DateTimeColumn get createdAt => dateTime().named('created_at')();
  DateTimeColumn get updatedAt => dateTime().named('updated_at')();
  DateTimeColumn get deletedAt => dateTime().nullable().named('deleted_at')();
  DateTimeColumn get lastModified => dateTime().named('last_modified')();
  IntColumn get version => integer().withDefault(const Constant(1))();

  BoolColumn get dirty => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('LocalSyncState')
class SyncStates extends Table {
  TextColumn get id => text()();
  TextColumn get syncTableName => text().named('table_name')();
  TextColumn get shopId => text().named('shop_id')();

  DateTimeColumn get lastPulledAt =>
      dateTime().nullable().named('last_pulled_at')();
  DateTimeColumn get lastPushedAt =>
      dateTime().nullable().named('last_pushed_at')();

  IntColumn get rowsPulled =>
      integer().withDefault(const Constant(0)).named('rows_pulled')();
  IntColumn get rowsPushed =>
      integer().withDefault(const Constant(0)).named('rows_pushed')();

  DateTimeColumn get createdAt => dateTime().named('created_at')();
  DateTimeColumn get updatedAt => dateTime().named('updated_at')();

  @override
  Set<Column> get primaryKey => {id};
}

// ================================================
// DATABASE
// ================================================

@DriftDatabase(
  tables: [
    Products,
    Categories,
    Inventory,
    StockMovements,
    Customers,
    Orders,
    OrderItems,
    Payments,
    SyncStates,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        // Handle migrations here
      },
    );
  }

  // ================================================
  // PRODUCT QUERIES
  // ================================================

  Future<List<LocalProduct>> getAllProducts(String shopId) {
    return (select(products)
          ..where((t) => t.shopId.equals(shopId))
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .get();
  }

  Future<LocalProduct?> getProduct(String id) {
    return (select(products)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<List<LocalProduct>> searchProducts(String shopId, String query) {
    return (select(products)
          ..where((t) => t.shopId.equals(shopId))
          ..where((t) => t.deletedAt.isNull())
          ..where(
            (t) =>
                t.name.contains(query) |
                t.sku.contains(query) |
                t.barcode.contains(query),
          ))
        .get();
  }

  Future<List<LocalProduct>> getDirtyProducts(String shopId) {
    return (select(products)
          ..where((t) => t.shopId.equals(shopId))
          ..where((t) => t.dirty.equals(true)))
        .get();
  }

  // ================================================
  // ORDER QUERIES
  // ================================================

  Future<List<LocalOrder>> getAllOrders(String shopId) {
    return (select(orders)
          ..where((t) => t.shopId.equals(shopId))
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.orderedAt)]))
        .get();
  }

  Future<LocalOrder?> getOrder(String id) {
    return (select(orders)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<List<LocalOrderItem>> getOrderItems(String orderId) {
    return (select(orderItems)
          ..where((t) => t.orderId.equals(orderId))
          ..where((t) => t.deletedAt.isNull()))
        .get();
  }

  Future<List<LocalPayment>> getOrderPayments(String orderId) {
    return (select(payments)
          ..where((t) => t.orderId.equals(orderId))
          ..where((t) => t.deletedAt.isNull()))
        .get();
  }

  // ================================================
  // SYNC QUERIES
  // ================================================

  Future<LocalSyncState?> getSyncState(String tableName, String shopId) {
    return (select(syncStates)
          ..where((t) => t.syncTableName.equals(tableName))
          ..where((t) => t.shopId.equals(shopId)))
        .getSingleOrNull();
  }

  Future<void> updateSyncState(
    String tableName,
    String shopId, {
    DateTime? lastPulledAt,
    DateTime? lastPushedAt,
    int? rowsPulled,
    int? rowsPushed,
  }) async {
    final existing = await getSyncState(tableName, shopId);

    if (existing == null) {
      await into(syncStates).insert(
        SyncStatesCompanion.insert(
          id: '${shopId}_$tableName',
          syncTableName: tableName,
          shopId: shopId,
          lastPulledAt: Value(lastPulledAt),
          lastPushedAt: Value(lastPushedAt),
          rowsPulled: Value(rowsPulled ?? 0),
          rowsPushed: Value(rowsPushed ?? 0),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
    } else {
      await (update(syncStates)..where((t) => t.id.equals(existing.id))).write(
        SyncStatesCompanion(
          lastPulledAt: Value(lastPulledAt ?? existing.lastPulledAt),
          lastPushedAt: Value(lastPushedAt ?? existing.lastPushedAt),
          rowsPulled: Value(rowsPulled ?? existing.rowsPulled),
          rowsPushed: Value(rowsPushed ?? existing.rowsPushed),
          updatedAt: Value(DateTime.now()),
        ),
      );
    }
  }

  // ================================================
  // BULK OPERATIONS
  // ================================================

  Future<void> upsertProducts(List<LocalProduct> items) async {
    await batch((batch) {
      for (final item in items) {
        batch.insert(products, item, mode: InsertMode.insertOrReplace);
      }
    });
  }

  Future<void> markProductsDirty(List<String> ids) async {
    await batch((batch) {
      for (final id in ids) {
        batch.update(
          products,
          ProductsCompanion(dirty: const Value(true)),
          where: (t) => t.id.equals(id),
        );
      }
    });
  }

  Future<void> clearDirtyFlag(String table, List<String> ids) async {
    // Implement for each table as needed
    if (table == 'products') {
      await batch((batch) {
        for (final id in ids) {
          batch.update(
            products,
            const ProductsCompanion(dirty: Value(false)),
            where: (t) => t.id.equals(id),
          );
        }
      });
    }
    // Add similar logic for other tables
  }
}

// ================================================
// DATABASE CONNECTION
// ================================================

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'qudris_shopkeeper.db'));
    return NativeDatabase(file);
  });
}
