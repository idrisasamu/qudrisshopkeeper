import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../common/session.dart';
import '../../data/local/app_database.dart';
import '../../app/main.dart';
import 'package:drift/drift.dart' as drift;

// Provider for low stock items
final lowStockItemsProvider = FutureProvider<List<ItemWithStock>>((ref) async {
  final db = ref.read(dbProvider);
  final sessionManager = SessionManager();
  final currentShopId =
      await sessionManager.getString('shop_id') ?? 'SHOP-LOCAL';

  // Get items for current shop only
  final items = await (db.select(
    db.items,
  )..where((tbl) => tbl.shopId.equals(currentShopId))).get();

  // Calculate current stock for each item and filter low stock
  final lowStockItems = <ItemWithStock>[];
  for (final item in items) {
    final stockMovements =
        await (db.select(db.stockMovements)..where(
              (tbl) =>
                  tbl.itemId.equals(item.id) & tbl.shopId.equals(currentShopId),
            ))
            .get();

    double currentStock = 0.0;
    for (final movement in stockMovements) {
      switch (movement.type) {
        case 'in':
        case 'adjust':
          currentStock += movement.qty;
          break;
        case 'out':
          currentStock -= movement.qty;
          break;
      }
    }

    // Check if stock is below minimum quantity OR negative
    if (currentStock < item.minQty || currentStock < 0) {
      lowStockItems.add(ItemWithStock(item: item, currentStock: currentStock));
    }
  }

  return lowStockItems;
});

class ItemWithStock {
  final Item item;
  final double currentStock;

  ItemWithStock({required this.item, required this.currentStock});
}

class LowStockPage extends ConsumerWidget {
  final bool readOnly;

  const LowStockPage({super.key, this.readOnly = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Low Stock Alert'),
        actions: [
          if (!readOnly)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                ref.invalidate(lowStockItemsProvider);
              },
            ),
        ],
      ),
      body: Consumer(
        builder: (context, ref, child) {
          final lowStockAsync = ref.watch(lowStockItemsProvider);

          return lowStockAsync.when(
            data: (items) {
              if (items.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle, size: 64, color: Colors.green),
                      SizedBox(height: 16),
                      Text(
                        'All items are well stocked!',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'No low stock alerts at this time.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final itemWithStock = items[index];
                  final item = itemWithStock.item;
                  final currentStock = itemWithStock.currentStock;

                  return Card(
                    color: Colors.red.shade50,
                    child: ListTile(
                      leading: Icon(
                        Icons.warning_amber,
                        color: Colors.red.shade700,
                        size: 28,
                      ),
                      title: Text(
                        item.name,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade800,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Current Stock: $currentStock'),
                          Text('Minimum Required: ${item.minQty}'),
                          if (currentStock <= 0)
                            Text(
                              'OUT OF STOCK!',
                              style: TextStyle(
                                color: Colors.red.shade700,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          else
                            Text(
                              'Stock is ${item.minQty - currentStock} units below minimum',
                              style: TextStyle(
                                color: Colors.orange.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                        ],
                      ),
                      trailing: currentStock <= 0
                          ? Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'OUT OF STOCK',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            )
                          : Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'LOW STOCK',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                    ),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error loading low stock items: $error'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => ref.invalidate(lowStockItemsProvider),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
