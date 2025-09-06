import 'package:drift/drift.dart';
import '../app_database.dart';
import '../../../common/uuid.dart';

part 'movement_dao.g.dart';

@DriftAccessor(tables: [StockMovements])
class MovementDao extends DatabaseAccessor<AppDatabase>
    with _$MovementDaoMixin {
  MovementDao(AppDatabase db) : super(db);

  Future<String> addPurchase({
    required String shopId,
    required String itemId,
    required double qty,
    required String byUserId,
    double? unitCost,
    String? refId,
    DateTime? at,
  }) async {
    final id = newId();
    await into(stockMovements).insert(
      StockMovementsCompanion.insert(
        id: id,
        shopId: shopId,
        itemId: itemId,
        type: 'purchase',
        qty: qty,
        unitCost: unitCost != null ? Value(unitCost) : const Value.absent(),
        unitPrice: const Value.absent(),
        reason: const Value.absent(),
        byUserId: byUserId,
        at: at ?? DateTime.now().toUtc(),
        refId: Value(refId),
      ),
    );
    return id;
  }

  Future<String> adjust({
    required String shopId,
    required String itemId,
    required double qty, // + or -
    required String byUserId,
    String? reason,
    DateTime? at,
  }) async {
    final id = newId();
    await into(stockMovements).insert(
      StockMovementsCompanion.insert(
        id: id,
        shopId: shopId,
        itemId: itemId,
        type: 'adjust',
        qty: qty,
        unitCost: const Value.absent(),
        unitPrice: const Value.absent(),
        reason: Value(reason),
        byUserId: byUserId,
        at: at ?? DateTime.now().toUtc(),
        refId: const Value.absent(),
      ),
    );
    return id;
  }

  Future<List<StockMovement>> forItem(String itemId) {
    return (select(
      stockMovements,
    )..where((m) => m.itemId.equals(itemId))).get();
  }
}
