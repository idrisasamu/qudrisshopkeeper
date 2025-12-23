import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import '../../common/session.dart';
import '../../common/currency_utils.dart';
import '../../app/main.dart';
import '../../data/local/app_database.dart';

// Provider for sales from the past 7 days with user email info
final salesHistoryProvider = FutureProvider<List<SaleWithItems>>((ref) async {
  final db = ref.read(dbProvider);
  final sessionManager = SessionManager();
  final currentShopId =
      await sessionManager.getString('shop_id') ?? 'SHOP-LOCAL';
  final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));

  // Get sales from the past 7 days for current shop only
  final sales =
      await (db.select(db.sales)
            ..where(
              (tbl) =>
                  tbl.shopId.equals(currentShopId) &
                  tbl.createdAt.isBiggerOrEqualValue(sevenDaysAgo),
            )
            ..orderBy([(tbl) => drift.OrderingTerm.desc(tbl.createdAt)]))
          .get();

  // Get sale items for each sale and user email
  final salesWithItems = <SaleWithItems>[];
  for (final sale in sales) {
    final saleItems = await (db.select(
      db.saleItems,
    )..where((tbl) => tbl.saleId.equals(sale.id))).get();

    // Try to get user email from Users table
    String? userEmail;
    try {
      final user = await (db.select(
        db.users,
      )..where((tbl) => tbl.id.equals(sale.byUserId))).getSingleOrNull();
      userEmail = user?.email;
    } catch (e) {
      // If user not found in Users table, use byUserId as fallback
      userEmail = sale.byUserId;
    }

    salesWithItems.add(
      SaleWithItems(sale: sale, items: saleItems, userEmail: userEmail),
    );
  }

  return salesWithItems;
});

class SaleWithItems {
  final Sale sale;
  final List<SaleItem> items;
  final String? userEmail;

  SaleWithItems({required this.sale, required this.items, this.userEmail});
}

class SalesHistoryPage extends ConsumerStatefulWidget {
  final bool readOnly;
  const SalesHistoryPage({super.key, this.readOnly = false});

  @override
  ConsumerState<SalesHistoryPage> createState() => _SalesHistoryPageState();
}

class _SalesHistoryPageState extends ConsumerState<SalesHistoryPage> {
  @override
  void initState() {
    super.initState();
    // Clean up old sales records (older than 8 days) when page loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _cleanupOldSales();
    });
  }

  Future<void> _cleanupOldSales() async {
    try {
      final db = ref.read(dbProvider);
      final eightDaysAgo = DateTime.now().subtract(const Duration(days: 8));

      // Get old sales to delete
      final oldSales = await (db.select(
        db.sales,
      )..where((tbl) => tbl.createdAt.isSmallerThanValue(eightDaysAgo))).get();

      for (final sale in oldSales) {
        // Delete sale items first
        await (db.delete(
          db.saleItems,
        )..where((tbl) => tbl.saleId.equals(sale.id))).go();

        // Delete the sale
        await db.delete(db.sales).delete(sale);
      }

      if (oldSales.isNotEmpty) {
        print('Cleaned up ${oldSales.length} old sales records');
        // Refresh the sales list
        ref.invalidate(salesHistoryProvider);
      }
    } catch (e) {
      print('Error cleaning up old sales: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales History'),
        actions: [
          IconButton(
            onPressed: () {
              // Refresh the sales list
              ref.invalidate(salesHistoryProvider);
            },
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh sales',
          ),
        ],
      ),
      body: Consumer(
        builder: (context, ref, child) {
          final salesAsync = ref.watch(salesHistoryProvider);

          return salesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(child: Text('Error: $error')),
            data: (salesWithItems) {
              if (salesWithItems.isEmpty) {
                return const Center(
                  child: Text(
                    'No sales in the past 7 days.\nStart making sales to see them here!',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: salesWithItems.length,
                itemBuilder: (context, index) {
                  final saleWithItems = salesWithItems[index];
                  final sale = saleWithItems.sale;
                  final items = saleWithItems.items;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Sale header
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Sale #${sale.id.substring(0, 8)}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                _formatDate(sale.createdAt),
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),

                          // User email tag
                          if (saleWithItems.userEmail != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.blue.shade200),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.person,
                                    size: 12,
                                    color: Colors.blue.shade700,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    saleWithItems.userEmail!,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.blue.shade700,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 8),

                          // Sale items
                          ...items.map(
                            (item) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${item.itemName} x${item.quantity.toStringAsFixed(0)}',
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ),
                                  Text(
                                    '${getShopCurrencySymbol('NGN')}${item.totalPrice.toStringAsFixed(2)}',
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const Divider(),

                          // Total
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Total:',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '${getShopCurrencySymbol('NGN')}${sale.totalAmount.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Yesterday ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else {
      return '${difference.inDays} days ago';
    }
  }
}
