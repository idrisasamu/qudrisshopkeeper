import 'package:drift/drift.dart';
import '../app_database.dart';
import '../../../common/uuid.dart';

part 'item_dao.g.dart';

@DriftAccessor(tables: [Items, StockMovements])
class ItemDao extends DatabaseAccessor<AppDatabase> with _$ItemDaoMixin {
  ItemDao(AppDatabase db) : super(db);

  Future<List<Item>> all(String shopId) {
    return (select(items)..where((t) => t.shopId.equals(shopId))).get();
  }

  Future<Item?> byId(String id) {
    return (select(items)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<String> insertItem({
    required String shopId,
    required String name,
    String? sku,
    String? barcode,
    String? category,
    String unit = 'unit',
    double costPrice = 0.0,
    double salePrice = 0.0,
    double minQty = 0.0,
  }) async {
    final id = newId();
    await into(items).insert(
      ItemsCompanion.insert(
        id: id,
        shopId: shopId,
        name: name,
        sku: Value(sku),
        barcode: Value(barcode),
        category: Value(category),
        unit: unit,
        costPrice: costPrice,
        salePrice: salePrice,
        minQty: minQty,
        isActive: const Value(true),
        updatedAt: DateTime.now().toUtc(),
      ),
    );
    return id;
  }

  Future<void> updateItem({
    required String id,
    String? name,
    String? sku,
    String? barcode,
    String? category,
    String? unit,
    double? costPrice,
    double? salePrice,
    double? minQty,
    bool? isActive,
  }) async {
    final comp = ItemsCompanion(
      name: name != null ? Value(name) : const Value.absent(),
      sku: Value(sku),
      barcode: Value(barcode),
      category: Value(category),
      unit: unit != null ? Value(unit) : const Value.absent(),
      costPrice: costPrice != null ? Value(costPrice) : const Value.absent(),
      salePrice: salePrice != null ? Value(salePrice) : const Value.absent(),
      minQty: minQty != null ? Value(minQty) : const Value.absent(),
      isActive: isActive != null ? Value(isActive) : const Value.absent(),
      updatedAt: Value(DateTime.now().toUtc()),
    );
    await (update(items)..where((t) => t.id.equals(id))).write(comp);
  }

  Future<double> onHand(String itemId) async => db.onHandForItem(itemId);

  Stream<double> watchOnHand(String itemId) {
    final q = (select(stockMovements)..where((m) => m.itemId.equals(itemId)));
    return q.watch().asyncMap((_) => db.onHandForItem(itemId));
  }
}
