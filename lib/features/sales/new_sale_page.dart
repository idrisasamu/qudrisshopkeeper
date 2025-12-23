import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import '../../app/main.dart';
import '../../data/local/app_database.dart';
import '../../data/repositories/sync_ops_repo.dart';
import '../../common/uuid.dart';
import '../../common/session.dart';
import '../inventory/inventory_page.dart';
import '../inventory/low_stock_page.dart';
import 'sales_history_page.dart';

// Provider for items with current stock (for sales) - now using StreamProvider for live updates
final salesItemsWithStockProvider =
    StreamProvider.autoDispose<List<ItemWithStock>>((ref) async* {
      final db = ref.read(dbProvider);
      final sessionManager = SessionManager();
      final currentShopId =
          await sessionManager.getString('shop_id') ?? 'SHOP-LOCAL';

      // Watch items for this shop - this will emit whenever items change
      yield* (db.select(db.items)
            ..where((tbl) => tbl.shopId.equals(currentShopId)))
          .watch()
          .asyncMap((items) async {
            print('DEBUG: Found ${items.length} items for shop $currentShopId');

            // Calculate current stock for each item
            final itemsWithStock = <ItemWithStock>[];
            for (final item in items) {
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

              itemsWithStock.add(
                ItemWithStock(item: item, currentStock: currentStock),
              );
            }

            // If no items in database, add some test items for debugging
            if (itemsWithStock.isEmpty) {
              print('DEBUG: No items found, adding test items');
              final testItems = [
                ItemWithStock(
                  item: Item(
                    id: 'test1',
                    shopId: currentShopId,
                    name: 'Test Item 1',
                    sku: 'TEST001',
                    barcode: null,
                    category: 'Test',
                    unit: 'unit',
                    costPrice: 10.0,
                    salePrice: 15.0,
                    minQty: 5.0,
                    isActive: true,
                    updatedAt: DateTime.now(),
                  ),
                  currentStock: 10.0,
                ),
                ItemWithStock(
                  item: Item(
                    id: 'test2',
                    shopId: currentShopId,
                    name: 'Test Item 2',
                    sku: 'TEST002',
                    barcode: null,
                    category: 'Test',
                    unit: 'unit',
                    costPrice: 20.0,
                    salePrice: 25.0,
                    minQty: 3.0,
                    isActive: true,
                    updatedAt: DateTime.now(),
                  ),
                  currentStock: 5.0,
                ),
              ];
              itemsWithStock.addAll(testItems);
            }

            print('DEBUG: Returning ${itemsWithStock.length} items with stock');
            return itemsWithStock;
          });
    });

class ItemWithStock {
  final Item item;
  final double currentStock;

  ItemWithStock({required this.item, required this.currentStock});
}

class SaleItem {
  final ItemWithStock itemWithStock;
  final double quantity;

  SaleItem({required this.itemWithStock, required this.quantity});
}

class NewSalePage extends ConsumerStatefulWidget {
  const NewSalePage({super.key});

  @override
  ConsumerState<NewSalePage> createState() => _NewSalePageState();
}

class _NewSalePageState extends ConsumerState<NewSalePage> {
  final searchCtrl = TextEditingController();
  final qtyCtrl = TextEditingController(text: '1');
  final FocusNode _searchFocusNode = FocusNode();

  List<SaleItem> saleItems = [];
  ItemWithStock? selectedItem;
  bool showDropdown = false;
  List<ItemWithStock> filteredItems = [];

  @override
  void initState() {
    super.initState();
    searchCtrl.addListener(_onSearchChanged);
    _searchFocusNode.addListener(_onFocusChanged);

    // Auto-focus search to surface the dropdown immediately
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _searchFocusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    searchCtrl.removeListener(_onSearchChanged);
    _searchFocusNode.removeListener(_onFocusChanged);
    searchCtrl.dispose();
    qtyCtrl.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = searchCtrl.text.toLowerCase();
    final itemsAsync = ref.read(salesItemsWithStockProvider);

    itemsAsync.when(
      data: (items) {
        setState(() {
          if (query.isEmpty) {
            // Show all items when search is empty
            filteredItems = items;
          } else {
            // Filter items based on search query
            filteredItems = items.where((item) {
              return item.item.name.toLowerCase().contains(query);
            }).toList();
          }
          // Always show dropdown when focused and there are items
          showDropdown = _searchFocusNode.hasFocus && filteredItems.isNotEmpty;
          print(
            'Search changed - Query: "$query", Items: ${items.length}, Filtered: ${filteredItems.length}, Focus: ${_searchFocusNode.hasFocus}, Show dropdown: $showDropdown',
          );
        });
      },
      loading: () {
        print('Loading items for search...');
      },
      error: (error, stack) {
        print('Error loading items for search: $error');
      },
    );
  }

  void _onFocusChanged() {
    print('Focus changed - hasFocus: ${_searchFocusNode.hasFocus}');

    if (_searchFocusNode.hasFocus) {
      // When focused, load items and show dropdown
      final itemsAsync = ref.read(salesItemsWithStockProvider);

      itemsAsync.when(
        data: (items) {
          setState(() {
            if (searchCtrl.text.isEmpty) {
              filteredItems = items;
            }
            showDropdown = filteredItems.isNotEmpty;
            print(
              'Focus gained - Items: ${items.length}, Filtered: ${filteredItems.length}, Show dropdown: $showDropdown',
            );
          });
        },
        loading: () {
          print('Loading items on focus...');
        },
        error: (error, stack) {
          print('Error loading items on focus: $error');
        },
      );
    } else {
      // When unfocused, hide dropdown
      setState(() {
        showDropdown = false;
        print('Focus lost - hiding dropdown');
      });
    }
  }

  void _selectItem(ItemWithStock itemWithStock) {
    setState(() {
      selectedItem = itemWithStock;
      searchCtrl.text = itemWithStock.item.name;
      showDropdown = false;
      _searchFocusNode.unfocus();
    });
  }

  void _addItemToSale() async {
    if (selectedItem == null) return;

    final quantity = double.tryParse(qtyCtrl.text) ?? 1.0;
    if (quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid quantity'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Check if item already exists in sale
    final existingIndex = saleItems.indexWhere(
      (saleItem) => saleItem.itemWithStock.item.id == selectedItem!.item.id,
    );

    double totalQuantity = quantity;
    if (existingIndex != -1) {
      totalQuantity += saleItems[existingIndex].quantity;
    }

    // Refresh stock data to ensure we have the latest information
    ref.invalidate(salesItemsWithStockProvider);
    final freshItemsAsync = ref.read(salesItemsWithStockProvider);

    // Get fresh data
    List<ItemWithStock> freshItems;
    if (freshItemsAsync.hasValue) {
      freshItems = freshItemsAsync.value!;
    } else {
      // If no fresh data available, use current selected item
      freshItems = [selectedItem!];
    }

    final freshItemWithStock = freshItems.firstWhere(
      (item) => item.item.id == selectedItem!.item.id,
      orElse: () => selectedItem!,
    );

    // Check stock availability - prevent sales that would result in negative stock
    if (totalQuantity > freshItemWithStock.currentStock) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Not enough stock! Available: ${freshItemWithStock.currentStock.toStringAsFixed(0)}, Requested: ${totalQuantity.toStringAsFixed(0)}',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Additional check: prevent sales if current stock is already negative
    if (freshItemWithStock.currentStock < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Cannot sell items with negative stock! Please add stock first.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Additional check: prevent sales if it would result in negative stock
    if (freshItemWithStock.currentStock - totalQuantity < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Sale would result in negative stock! Available: ${freshItemWithStock.currentStock.toStringAsFixed(0)}, After sale: ${(freshItemWithStock.currentStock - totalQuantity).toStringAsFixed(0)}',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (existingIndex != -1) {
      // Update existing item quantity
      setState(() {
        saleItems[existingIndex] = SaleItem(
          itemWithStock: saleItems[existingIndex].itemWithStock,
          quantity: totalQuantity,
        );
      });
    } else {
      // Add new item to sale
      setState(() {
        saleItems.add(
          SaleItem(itemWithStock: selectedItem!, quantity: quantity),
        );
      });
    }

    // Reset form
    setState(() {
      selectedItem = null;
      searchCtrl.clear();
      qtyCtrl.text = '1';
    });
  }

  void _removeItemFromSale(int index) {
    setState(() {
      saleItems.removeAt(index);
    });
  }

  Future<void> _saveSale() async {
    if (saleItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No items to save'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final db = ref.read(dbProvider);
      final now = DateTime.now().toUtc();
      final saleId = newId();

      // Calculate total amount
      final totalAmount = saleItems.fold(
        0.0,
        (sum, saleItem) =>
            sum + (saleItem.itemWithStock.item.salePrice * saleItem.quantity),
      );

      // Get current user identity (staff username preferred)
      final sessionManager = SessionManager();
      final currentRole = await sessionManager.getString('role');
      String byUserId;
      if (currentRole == 'staff') {
        byUserId = await sessionManager.getString('username') ?? 'staff';
      } else {
        byUserId = await sessionManager.getString('google_email') ?? 'admin';
      }

      // Get current shop ID
      final currentShopId =
          await sessionManager.getString('shop_id') ?? 'SHOP-LOCAL';

      // Create the sale record
      await db
          .into(db.sales)
          .insert(
            SalesCompanion.insert(
              id: saleId,
              shopId: currentShopId,
              totalAmount: totalAmount,
              byUserId: byUserId,
              createdAt: now,
            ),
          );

      // Create sale items and stock movements for each item in the sale
      for (final saleItem in saleItems) {
        final stockMovementId = newId();
        final saleItemId = newId();

        // Create sale item record
        await db
            .into(db.saleItems)
            .insert(
              SaleItemsCompanion.insert(
                id: saleItemId,
                saleId: saleId,
                itemId: saleItem.itemWithStock.item.id,
                itemName: saleItem.itemWithStock.item.name,
                quantity: saleItem.quantity,
                unitPrice: saleItem.itemWithStock.item.salePrice,
                totalPrice:
                    saleItem.itemWithStock.item.salePrice * saleItem.quantity,
              ),
            );

        // Create stock movement
        await db
            .into(db.stockMovements)
            .insert(
              StockMovementsCompanion.insert(
                id: stockMovementId,
                shopId: currentShopId,
                itemId: saleItem.itemWithStock.item.id,
                type: 'out', // Sale reduces stock
                qty: saleItem.quantity,
                unitCost: 0.0, // We don't track cost in sales
                unitPrice: saleItem.itemWithStock.item.salePrice,
                reason: const drift.Value('Sale - Item sold'),
                byUserId: byUserId,
                at: now,
              ),
            );
      }

      // Emit sync operation for sale creation
      final syncRepo = SyncOpsRepo(db);
      final sale = await (db.select(
        db.sales,
      )..where((t) => t.id.equals(saleId))).getSingle();
      final saleItemsFromDb = await (db.select(
        db.saleItems,
      )..where((t) => t.saleId.equals(saleId))).get();
      await syncRepo.emitSaleCreate(sale, saleItemsFromDb);

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Sale saved successfully! ${saleItems.length} items processed.',
          ),
          backgroundColor: Colors.green,
        ),
      );

      // Clear the sale and go back
      setState(() {
        saleItems.clear();
        selectedItem = null;
        searchCtrl.clear();
        qtyCtrl.text = '1';
      });

      // Refresh the items provider to update stock levels
      ref.invalidate(salesItemsWithStockProvider);

      // Also refresh the inventory page provider
      ref.invalidate(itemsWithStockProvider);

      // Refresh the low stock provider for staff alerts
      ref.invalidate(lowStockItemsProvider);

      // Refresh the sales history provider
      ref.invalidate(salesHistoryProvider);

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving sale: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Keep dropdown data in sync with provider emissions (must be in build)
    ref.listen<AsyncValue<List<ItemWithStock>>>(salesItemsWithStockProvider, (
      previous,
      next,
    ) {
      next.when(
        data: (items) {
          // Update filtered list based on current query and focus
          final query = searchCtrl.text.toLowerCase();
          if (!mounted) return;
          setState(() {
            if (query.isEmpty) {
              filteredItems = items;
            } else {
              filteredItems = items
                  .where((it) => it.item.name.toLowerCase().contains(query))
                  .toList();
            }
            showDropdown =
                _searchFocusNode.hasFocus && filteredItems.isNotEmpty;
          });
        },
        loading: () {},
        error: (_, __) {},
      );
    });

    return Scaffold(
      appBar: AppBar(title: const Text('New Sale - UPDATED')),
      body: Column(
        children: [
          // Search and quantity section
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Search field with dropdown
                Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: searchCtrl,
                            focusNode: _searchFocusNode,
                            decoration: const InputDecoration(
                              labelText: 'Search or scan item',
                              prefixIcon: Icon(Icons.search),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () {
                            // Refresh the items list and related providers
                            ref.invalidate(salesItemsWithStockProvider);
                            ref.invalidate(itemsWithStockProvider);
                            ref.invalidate(lowStockItemsProvider);
                            setState(() {
                              // Clear current selection and refresh filtered items
                              selectedItem = null;
                              searchCtrl.clear();
                              filteredItems = [];
                              showDropdown = false;
                            });
                          },
                          icon: const Icon(Icons.refresh),
                          tooltip: 'Refresh items',
                        ),
                      ],
                    ),
                    if (showDropdown && filteredItems.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        decoration: BoxDecoration(
                          color: Colors.grey[900],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[600]!),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        constraints: const BoxConstraints(maxHeight: 200),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: filteredItems.length,
                          itemBuilder: (context, index) {
                            final itemWithStock = filteredItems[index];
                            final item = itemWithStock.item;
                            final stock = itemWithStock.currentStock;

                            return ListTile(
                              dense: true,
                              title: Text(
                                item.name,
                                style: const TextStyle(color: Colors.white),
                              ),
                              subtitle: Text(
                                'Stock: ${stock.toStringAsFixed(0)} | Price: ₦${item.salePrice.toStringAsFixed(2)}',
                                style: const TextStyle(color: Colors.grey),
                              ),
                              onTap: () => _selectItem(itemWithStock),
                            );
                          },
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                // Quantity row
                Row(
                  children: [
                    const Text('Qty'),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 90,
                      child: TextField(
                        controller: qtyCtrl,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Add to sale button
                if (selectedItem != null)
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.add),
                      label: Text('Add ${selectedItem!.item.name} to Sale'),
                      onPressed: _addItemToSale,
                    ),
                  ),
              ],
            ),
          ),

          // Sale items list
          Expanded(
            child: saleItems.isEmpty
                ? const Center(
                    child: Text(
                      'No items in sale yet.\nSearch and add items above.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: saleItems.length,
                    itemBuilder: (context, index) {
                      final saleItem = saleItems[index];
                      final item = saleItem.itemWithStock.item;
                      final stock = saleItem.itemWithStock.currentStock;
                      final total = item.salePrice * saleItem.quantity;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(item.name),
                          subtitle: Text(
                            'Qty: ${saleItem.quantity.toStringAsFixed(0)} | Stock: ${stock.toStringAsFixed(0)} | ₦${item.salePrice.toStringAsFixed(2)} each',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '₦${total.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.remove_circle,
                                  color: Colors.red,
                                ),
                                onPressed: () => _removeItemFromSale(index),
                                tooltip: 'Remove from sale',
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // Total and save section
          if (saleItems.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                border: Border(top: BorderSide(color: Colors.grey[300]!)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total:',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        '₦${saleItems.fold(0.0, (sum, saleItem) => sum + (saleItem.itemWithStock.item.salePrice * saleItem.quantity)).toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.save),
                      label: const Text('Save Sale'),
                      onPressed: () async {
                        await _saveSale();
                      },
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
