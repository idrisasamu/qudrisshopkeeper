import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../common/uuid.dart';
import '../../common/session.dart';
import '../../data/local/app_database.dart';
import '../../data/repositories/sync_ops_repo.dart';
import '../../app/main.dart';
import 'package:drift/drift.dart' as drift;

// Provider for items with current stock - now using StreamProvider for live updates
final itemsWithStockProvider = StreamProvider.autoDispose<List<ItemWithStock>>((
  ref,
) async* {
  final db = ref.read(dbProvider);
  final sessionManager = SessionManager();
  final currentShopId =
      await sessionManager.getString('shop_id') ?? 'SHOP-LOCAL';

  print('DEBUG: itemsWithStockProvider - currentShopId: $currentShopId');

  // Watch items for this shop - this will emit whenever items change
  yield* (db.select(
    db.items,
  )..where((tbl) => tbl.shopId.equals(currentShopId))).watch().asyncMap((
    items,
  ) async {
    print(
      'DEBUG: itemsWithStockProvider - found ${items.length} items in database',
    );

    // Calculate current stock for each item
    final itemsWithStock = <ItemWithStock>[];
    for (final item in items) {
      print(
        'DEBUG: itemsWithStockProvider - processing item: ${item.name} (id: ${item.id})',
      );

      final stockMovements =
          await (db.select(db.stockMovements)..where(
                (tbl) =>
                    tbl.itemId.equals(item.id) &
                    tbl.shopId.equals(currentShopId),
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

      itemsWithStock.add(ItemWithStock(item: item, currentStock: currentStock));
    }

    print(
      'DEBUG: itemsWithStockProvider - returning ${itemsWithStock.length} items with stock',
    );
    return itemsWithStock;
  });
});

class ItemWithStock {
  final Item item;
  final double currentStock;

  ItemWithStock({required this.item, required this.currentStock});
}

class InventoryPage extends ConsumerStatefulWidget {
  final bool readOnly;
  const InventoryPage({super.key, this.readOnly = false});

  @override
  ConsumerState<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends ConsumerState<InventoryPage> {
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
      appBar: AppBar(title: const Text('Inventory'), actions: []),
      floatingActionButton: widget.readOnly
          ? null
          : FloatingActionButton.extended(
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => _NewItemSheet(ref: ref),
                );
              },
              label: const Text('Add Item'),
              icon: const Icon(Icons.add),
            ),
      body: Consumer(
        builder: (context, ref, child) {
          // Check if database is open
          final holder = ref.watch(dbHolderProvider);
          if (!holder.isOpen) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Opening database...'),
                ],
              ),
            );
          }

          final itemsAsync = ref.watch(itemsWithStockProvider);

          return itemsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(child: Text('Error: $error')),
            data: (itemsWithStock) {
              if (itemsWithStock.isEmpty) {
                return const Center(
                  child: Text(
                    'No items yet.\nTap the + button to add your first item!',
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

                  // Check if stock is below minimum threshold OR negative
                  final isLowStock =
                      currentStock < item.minQty || currentStock < 0;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    color: isLowStock
                        ? Colors
                              .red[900] // Dark red background for better contrast
                        : null,
                    elevation: isLowStock
                        ? 2
                        : 1, // Slightly higher elevation for low stock
                    shape: isLowStock
                        ? RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(color: Colors.red[600]!, width: 2),
                          )
                        : null, // Red border for low stock items
                    child: ListTile(
                      title: Row(
                        children: [
                          if (isLowStock) ...[
                            const Icon(
                              Icons.warning,
                              color: Colors
                                  .white, // White icon for dark background
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                          ],
                          Expanded(
                            child: Text(
                              item.name,
                              style: TextStyle(
                                color: isLowStock
                                    ? Colors.white
                                    : null, // White text for dark background
                                fontWeight: isLowStock ? FontWeight.bold : null,
                              ),
                            ),
                          ),
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Price: ₦${item.salePrice.toStringAsFixed(2)}',
                            style: TextStyle(
                              color: isLowStock
                                  ? Colors.white70
                                  : null, // Light white for dark background
                            ),
                          ),
                          Text(
                            'Stock: ${currentStock.toStringAsFixed(0)} | Min: ${item.minQty.toStringAsFixed(0)}',
                            style: TextStyle(
                              color: isLowStock
                                  ? Colors.white
                                  : null, // White text for dark background
                              fontWeight: isLowStock ? FontWeight.bold : null,
                            ),
                          ),
                        ],
                      ),
                      trailing: widget.readOnly
                          ? null
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Stock adjustment button
                                IconButton(
                                  icon: Icon(
                                    Icons.add_circle_outline,
                                    color: isLowStock
                                        ? Colors.white
                                        : Colors.green,
                                  ),
                                  onPressed: () => _showStockAdjustmentDialog(
                                    context,
                                    ref,
                                    item,
                                    'add',
                                  ),
                                  tooltip: 'Add Stock',
                                ),
                                // Edit button
                                IconButton(
                                  icon: Icon(
                                    Icons.edit,
                                    color: isLowStock
                                        ? Colors.white
                                        : Colors.blue,
                                  ),
                                  onPressed: () =>
                                      _showEditItemDialog(context, ref, item),
                                  tooltip: 'Edit Item',
                                ),
                                // Delete button
                                IconButton(
                                  icon: Icon(
                                    Icons.delete,
                                    color: isLowStock
                                        ? Colors.white
                                        : Colors.red,
                                  ),
                                  onPressed: () => _showDeleteConfirmation(
                                    context,
                                    ref,
                                    item,
                                  ),
                                  tooltip: 'Delete Item',
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

  void _showStockAdjustmentDialog(
    BuildContext context,
    WidgetRef ref,
    Item item,
    String type,
  ) {
    final controller = TextEditingController();
    final isAdd = type == 'add';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isAdd ? 'Add Stock' : 'Remove Stock'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Item: ${item.name}'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: 'Quantity to ${isAdd ? 'add' : 'remove'}',
                suffixText: item.unit,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 16,
                ),
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final quantity = double.tryParse(controller.text);
              if (quantity == null || quantity <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a valid quantity'),
                  ),
                );
                return;
              }

              // For stock removal, check if we have enough stock
              if (type == 'remove') {
                final currentStock = await _getCurrentStock(item.id);
                if (quantity > currentStock) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Cannot remove ${quantity.toStringAsFixed(0)} units. Only ${currentStock.toStringAsFixed(0)} units available.',
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
              }

              await _adjustStock(ref, item, quantity, isAdd ? 'in' : 'out');
              Navigator.pop(context);
              ref.invalidate(itemsWithStockProvider);
            },
            child: Text(isAdd ? 'Add' : 'Remove'),
          ),
        ],
      ),
    );
  }

  void _showEditItemDialog(BuildContext context, WidgetRef ref, Item item) {
    final nameCtrl = TextEditingController(text: item.name);
    final priceCtrl = TextEditingController(text: item.salePrice.toString());
    final minCtrl = TextEditingController(text: item.minQty.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Item'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 16,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: priceCtrl,
                decoration: InputDecoration(
                  labelText: 'Sale price (₦)',
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 16,
                  ),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: minCtrl,
                decoration: const InputDecoration(
                  labelText: 'Low-stock threshold',
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 16,
                  ),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              await _updateItem(
                ref,
                item,
                nameCtrl.text.trim(),
                double.tryParse(priceCtrl.text) ?? item.salePrice,
                double.tryParse(minCtrl.text) ?? item.minQty,
              );
              Navigator.pop(context);
              ref.invalidate(itemsWithStockProvider);
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, WidgetRef ref, Item item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Item'),
        content: Text(
          'Are you sure you want to delete "${item.name}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              await _deleteItem(ref, item);
              Navigator.pop(context);
              ref.invalidate(itemsWithStockProvider);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _adjustStock(
    WidgetRef ref,
    Item item,
    double quantity,
    String type,
  ) async {
    final db = ref.read(dbProvider);
    final sessionManager = SessionManager();
    final currentShopId =
        await sessionManager.getString('shop_id') ?? 'SHOP-LOCAL';
    final stockMovementId = newId();

    await db
        .into(db.stockMovements)
        .insert(
          StockMovementsCompanion.insert(
            id: stockMovementId,
            shopId: currentShopId,
            itemId: item.id,
            type: type,
            qty: quantity,
            unitCost: 0.0,
            unitPrice: item.salePrice,
            reason: drift.Value(type == 'in' ? 'Stock added' : 'Stock removed'),
            byUserId: 'admin',
            at: DateTime.now().toUtc(),
          ),
        );

    // Emit sync operation for stock adjustment
    final syncRepo = SyncOpsRepo(db);
    await syncRepo.emitStockAdjust(
      item.id,
      item.shopId, // Include shop_id
      type == 'in' ? quantity : -quantity,
      type == 'in' ? 'Stock added' : 'Stock removed',
    );
  }

  Future<void> _updateItem(
    WidgetRef ref,
    Item item,
    String name,
    double price,
    double minQty,
  ) async {
    final db = ref.read(dbProvider);

    final updatedItem = item.copyWith(
      name: name,
      salePrice: price,
      minQty: minQty,
      updatedAt: DateTime.now().toUtc(),
    );

    await db.update(db.items).replace(updatedItem);

    // Emit sync operation for item update
    final syncRepo = SyncOpsRepo(db);
    await syncRepo.emitItemUpsert(updatedItem);
    print('DEBUG: Emitted item upsert sync operation for: ${updatedItem.name}');
  }

  Future<void> _deleteItem(WidgetRef ref, Item item) async {
    final db = ref.read(dbProvider);

    // Delete stock movements first
    await (db.delete(
      db.stockMovements,
    )..where((tbl) => tbl.itemId.equals(item.id))).go();

    // Delete the item
    await db.delete(db.items).delete(item);

    // Emit sync operation for item deletion
    final syncRepo = SyncOpsRepo(db);
    await syncRepo.emitItemDelete(item.id, item.shopId);
    print('DEBUG: Emitted item delete sync operation for: ${item.name}');
  }

  Future<double> _getCurrentStock(String itemId) async {
    final db = ref.read(dbProvider);
    final stockMovements = await (db.select(
      db.stockMovements,
    )..where((tbl) => tbl.itemId.equals(itemId))).get();

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
    return currentStock;
  }
}

class _NewItemSheet extends StatefulWidget {
  final WidgetRef ref;
  const _NewItemSheet({required this.ref});

  @override
  State<_NewItemSheet> createState() => _NewItemSheetState();
}

class _NewItemSheetState extends State<_NewItemSheet> {
  final nameCtrl = TextEditingController();
  final priceCtrl = TextEditingController();
  final minCtrl = TextEditingController(text: '0');
  final quantityCtrl = TextEditingController(text: '0');

  @override
  Widget build(BuildContext context) {
    final ref = widget.ref;
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: ListView(
        shrinkWrap: true,
        children: [
          const Text(
            'New Item',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Name',
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 16,
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: priceCtrl,
            decoration: InputDecoration(
              labelText: 'Sale price (₦)',
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 16,
              ),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: minCtrl,
            decoration: const InputDecoration(
              labelText: 'Low-stock threshold',
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 16,
              ),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: quantityCtrl,
            decoration: const InputDecoration(
              labelText: 'Initial quantity',
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 16,
              ),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () async {
              final db = ref.read(dbProvider);
              final sessionManager = SessionManager();
              final currentShopId =
                  await sessionManager.getString('shop_id') ?? 'SHOP-LOCAL';
              final name = nameCtrl.text.trim();
              final price = double.tryParse(priceCtrl.text) ?? 0.0;
              final initialQuantity = double.tryParse(quantityCtrl.text) ?? 0.0;

              // Validate inputs
              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter an item name'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              if (price <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a valid price'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              if (initialQuantity < 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Initial quantity cannot be negative'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              // Check if item with same name and price already exists in current shop
              final existingItems =
                  await (db.select(db.items)..where(
                        (tbl) =>
                            tbl.name.equals(name) &
                            tbl.salePrice.equals(price) &
                            tbl.shopId.equals(currentShopId),
                      ))
                      .get();

              if (existingItems.isNotEmpty) {
                // Update existing item's stock instead of creating duplicate
                final existingItem = existingItems.first;

                if (initialQuantity > 0) {
                  final stockMovementId = newId();
                  await db
                      .into(db.stockMovements)
                      .insert(
                        StockMovementsCompanion.insert(
                          id: stockMovementId,
                          shopId: currentShopId,
                          itemId: existingItem.id,
                          type: 'adjust',
                          qty: initialQuantity,
                          unitCost: 0.0,
                          unitPrice: price,
                          reason: const drift.Value(
                            'Stock added to existing item',
                          ),
                          byUserId: 'admin',
                          at: DateTime.now().toUtc(),
                        ),
                      );

                  // Emit sync operation for the stock adjustment
                  final syncOpsRepo = SyncOpsRepo(db);
                  await syncOpsRepo.emitStockAdjust(
                    existingItem.id,
                    existingItem.shopId, // Include shop_id
                    initialQuantity,
                    'Stock added to existing item',
                  );
                }

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Added ${initialQuantity.toStringAsFixed(0)} units to existing item: $name',
                    ),
                  ),
                );
              } else {
                // Create new item
                final id = newId();

                final newItemCompanion = ItemsCompanion.insert(
                  id: id,
                  shopId: currentShopId,
                  name: name,
                  unit: 'unit',
                  costPrice: 0.0,
                  salePrice: price,
                  minQty: double.tryParse(minCtrl.text) ?? 0.0,
                  isActive: true,
                  updatedAt: DateTime.now().toUtc(),
                );

                await db
                    .into(db.items)
                    .insert(
                      newItemCompanion,
                      mode: drift.InsertMode.insertOrReplace,
                    );

                // Emit sync operation for the new item
                final syncOpsRepo = SyncOpsRepo(db);
                final newItem = Item(
                  id: id,
                  shopId: currentShopId,
                  name: name,
                  unit: 'unit',
                  costPrice: 0.0,
                  salePrice: price,
                  minQty: double.tryParse(minCtrl.text) ?? 0.0,
                  isActive: true,
                  updatedAt: DateTime.now().toUtc(),
                );
                await syncOpsRepo.emitItemUpsert(newItem);
                print(
                  'DEBUG: Emitted new item upsert sync operation for: $name',
                );

                // Create initial stock movement if quantity > 0
                if (initialQuantity > 0) {
                  final stockMovementId = newId();
                  await db
                      .into(db.stockMovements)
                      .insert(
                        StockMovementsCompanion.insert(
                          id: stockMovementId,
                          shopId: currentShopId,
                          itemId: id,
                          type: 'adjust',
                          qty: initialQuantity,
                          unitCost: 0.0,
                          unitPrice: price,
                          reason: const drift.Value('Initial stock'),
                          byUserId: 'admin',
                          at: DateTime.now().toUtc(),
                        ),
                      );

                  // Emit sync operation for the stock adjustment
                  await syncOpsRepo.emitStockAdjust(
                    id,
                    currentShopId, // Include shop_id
                    initialQuantity,
                    'Initial stock',
                  );
                }

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Item "$name" created with ${initialQuantity.toStringAsFixed(0)} units',
                    ),
                  ),
                );
              }

              print('Item saved: $name with quantity: $initialQuantity');

              if (mounted) {
                Navigator.pop(context);
                // Refresh the items list
                ref.invalidate(itemsWithStockProvider);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
