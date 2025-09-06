import 'package:drift/drift.dart';
import '../app_database.dart';
import '../../../common/uuid.dart';

part 'sales_dao.g.dart';

@DriftAccessor(tables: [Sales, SaleLines, StockMovements])
class SalesDao extends DatabaseAccessor<AppDatabase> with _$SalesDaoMixin {
  SalesDao(AppDatabase db) : super(db);

  /// Creates a sale with lines and corresponding stock movements (-qty).
  Future<String> createSale({
    required String shopId,
    required String cashierId,
    required DateTime at,
    required List<SaleLineInsert> lines,
    String? paymentMethod,
  }) async {
    return transaction(() async {
      final saleId = newId();
      final total = lines.fold<double>(0.0, (a, l) => a + l.lineTotal);
      await into(sales).insert(
        SalesCompanion.insert(
          id: saleId,
          shopId: shopId,
          cashierId: cashierId,
          at: at,
          total: total,
          paymentMethod: Value(paymentMethod),
        ),
      );
      for (final l in lines) {
        final lineId = newId();
        await into(saleLines).insert(
          SaleLinesCompanion.insert(
            id: lineId,
            saleId: saleId,
            itemId: l.itemId,
            qty: l.qty,
            unitPrice: l.unitPrice,
            lineTotal: l.lineTotal,
          ),
        );
        // Stock movement (sale = negative)
        await into(stockMovements).insert(
          StockMovementsCompanion.insert(
            id: newId(),
            shopId: shopId,
            itemId: l.itemId,
            type: 'sale',
            qty: -l.qty,
            unitPrice: Value(l.unitPrice),
            unitCost: const Value.absent(),
            reason: const Value.absent(),
            byUserId: cashierId,
            at: at,
            refId: Value(saleId),
          ),
        );
      }
      return saleId;
    });
  }

  Future<List<Sale>> salesForDay(DateTime dayStart, DateTime dayEnd) {
    return (select(
      sales,
    )..where((s) => s.at.isBetweenValues(dayStart, dayEnd))).get();
  }
}

class SaleLineInsert {
  final String itemId;
  final double qty;
  final double unitPrice;
  double get lineTotal => qty * unitPrice;
  SaleLineInsert({
    required this.itemId,
    required this.qty,
    required this.unitPrice,
  });
}
