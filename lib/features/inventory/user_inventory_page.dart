import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../inventory/inventory_page.dart';
import '../../common/session.dart';

class UserInventoryPage extends ConsumerStatefulWidget {
  const UserInventoryPage({super.key});

  @override
  ConsumerState<UserInventoryPage> createState() => _UserInventoryPageState();
}

class _UserInventoryPageState extends ConsumerState<UserInventoryPage> {
  @override
  void initState() {
    super.initState();
    // Refresh inventory when page is first loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(itemsWithStockProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory (Read Only)'),
        actions: [
          IconButton(
            onPressed: () {
              // Refresh the inventory
              ref.invalidate(itemsWithStockProvider);
            },
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh inventory',
          ),
        ],
      ),
      body: Consumer(
        builder: (context, ref, child) {
          final itemsAsync = ref.watch(itemsWithStockProvider);

          return itemsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(child: Text('Error: $error')),
            data: (itemsWithStock) {
              if (itemsWithStock.isEmpty) {
                return const Center(
                  child: Text(
                    'No items in inventory.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: itemsWithStock.length,
                itemBuilder: (context, index) {
                  final itemWithStock = itemsWithStock[index];
                  final item = itemWithStock.item;
                  final currentStock = itemWithStock.currentStock;

                  // Check if stock is below minimum threshold
                  final isLowStock = currentStock < item.minQty;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    color: isLowStock
                        ? Colors.red[50]
                        : null, // Light red background for low stock
                    elevation: isLowStock
                        ? 2
                        : 1, // Slightly higher elevation for low stock
                    shape: isLowStock
                        ? RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(color: Colors.red[300]!, width: 1),
                          )
                        : null, // Red border for low stock items
                    child: ListTile(
                      title: Row(
                        children: [
                          if (isLowStock) ...[
                            const Icon(
                              Icons.warning,
                              color: Colors.red,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                          ],
                          Expanded(child: Text(item.name)),
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Price: ₦${item.salePrice.toStringAsFixed(2)}'),
                          Text(
                            'Stock: ${currentStock.toStringAsFixed(0)} | Min: ${item.minQty.toStringAsFixed(0)}',
                            style: TextStyle(
                              color: isLowStock ? Colors.red[700] : null,
                              fontWeight: isLowStock ? FontWeight.w600 : null,
                            ),
                          ),
                        ],
                      ),
                      // No action buttons for users - read only
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
}
