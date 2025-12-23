import 'package:drift/drift.dart';
import '../app_database.dart';

part 'report_dao.g.dart';

@DriftAccessor(tables: [Sales, SaleItems, Items])
class ReportDao extends DatabaseAccessor<AppDatabase> with _$ReportDaoMixin {
  ReportDao(AppDatabase db) : super(db);

  Future<double> totalSalesBetween(DateTime from, DateTime to) async {
    final q = (select(sales)
      ..where((s) => s.createdAt.isBiggerOrEqualValue(from))
      ..where((s) => s.createdAt.isSmallerThanValue(to)));
    final rows = await q.get();
    return rows.fold<double>(0, (sum, s) => sum + (s.totalAmount ?? 0));
  }

  Future<List<Map<String, dynamic>>> topItemsBetween(
    DateTime from,
    DateTime to, {
    int limit = 10,
  }) async {
    final q = customSelect(
      '''
      SELECT i.name as item, SUM(sl.quantity) as qty, SUM(sl.total_price) as total
      FROM sale_items sl
      JOIN sales s ON s.id = sl.sale_id
      JOIN items i ON i.id = sl.item_id
      WHERE s.created_at >= ? AND s.created_at < ?
      GROUP BY i.name
      ORDER BY total DESC
      LIMIT ?
      ''',
      variables: [Variable(from), Variable(to), Variable(limit)],
      readsFrom: {saleItems, sales, items},
    );
    final res = await q.get();
    return res
        .map(
          (r) => {
            'item': r.data['item'],
            'qty': (r.data['qty'] as num?)?.toDouble() ?? 0,
            'total': (r.data['total'] as num?)?.toDouble() ?? 0,
          },
        )
        .toList();
  }

  Future<int> transactionsCountBetween(DateTime from, DateTime to) async {
    final q = (select(sales)
      ..where((s) => s.createdAt.isBiggerOrEqualValue(from))
      ..where((s) => s.createdAt.isSmallerThanValue(to)));
    return q.get().then((rows) => rows.length);
  }
}
