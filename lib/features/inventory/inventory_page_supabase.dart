import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/product.dart';
import '../../providers/inventory_provider.dart';
import '../../common/session.dart';

// Debug flag - set to false for production
const bool kShowInventoryDebug = false;

/// Inventory page using Supabase backend
class InventoryPageSupabase extends ConsumerStatefulWidget {
  final bool readOnly;

  const InventoryPageSupabase({super.key, this.readOnly = false});

  @override
  ConsumerState<InventoryPageSupabase> createState() =>
      _InventoryPageSupabaseState();
}

class _InventoryPageSupabaseState extends ConsumerState<InventoryPageSupabase> {
  String _searchQuery = '';
  String _shopIdPreview = '';
  bool _showDebugBanner = false; // Set to false for production

  @override
  void initState() {
    super.initState();
    _loadShopIdPreview();
  }

  Future<void> _loadShopIdPreview() async {
    final sessionManager = SessionManager();
    final shopId = await sessionManager.getString('shop_id');
    if (mounted) {
      setState(() {
        _shopIdPreview = shopId?.substring(0, 8) ?? 'NULL';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(productsProvider);
            },
            tooltip: 'Refresh',
          ),
        ],
      ),
      floatingActionButton: widget.readOnly
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _showAddProductDialog(context),
              label: const Text('Add Product'),
              icon: const Icon(Icons.add),
            ),
      body: Column(
        children: [
          // DEBUG BANNER (TODO: Remove in production)
          if (_showDebugBanner)
            Container(
              width: double.infinity,
              color: Colors.amber.shade100,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: productsAsync.when(
                data: (products) => Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '🔍 DEBUG: Shop: $_shopIdPreview | Source: Supabase | Count: ${products.length}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 16),
                      onPressed: () => setState(() => _showDebugBanner = false),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                loading: () => const Text(
                  '🔍 DEBUG: Loading...',
                  style: TextStyle(fontSize: 11),
                ),
                error: (_, __) => const Text(
                  '🔍 DEBUG: Error',
                  style: TextStyle(fontSize: 11),
                ),
              ),
            ),
          // DEV TEST BUTTONS (hidden in production)
          if (kShowInventoryDebug && !widget.readOnly)
            Container(
              width: double.infinity,
              color: Colors.blue.shade50,
              padding: const EdgeInsets.all(8),
              child: Column(
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _runDevTest(),
                    icon: const Icon(Icons.science, size: 16),
                    label: const Text(
                      'DEV: Create Test Product',
                      style: TextStyle(fontSize: 12),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () => _fixMissingInventory(),
                    icon: const Icon(Icons.build, size: 16),
                    label: const Text(
                      'DEV: Fix Missing Inventory',
                      style: TextStyle(fontSize: 12),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade700,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search products...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
          ),
          // Products list
          Expanded(
            child: productsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    Text('Error: $error'),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => ref.invalidate(productsProvider),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
              data: (products) {
                // Filter products by search query
                final filteredProducts = _searchQuery.isEmpty
                    ? products
                    : products.where((p) {
                        return p.name.toLowerCase().contains(_searchQuery) ||
                            (p.sku?.toLowerCase().contains(_searchQuery) ??
                                false) ||
                            (p.barcode?.toLowerCase().contains(_searchQuery) ??
                                false);
                      }).toList();

                if (filteredProducts.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _searchQuery.isEmpty
                              ? Icons.inventory_2_outlined
                              : Icons.search_off,
                          size: 64,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isEmpty
                              ? 'No products yet.\nTap the + button to add your first product!'
                              : 'No products found matching "$_searchQuery"',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  itemCount: filteredProducts.length,
                  itemBuilder: (context, index) {
                    final product = filteredProducts[index];
                    return _ProductCard(
                      product: product,
                      readOnly: widget.readOnly,
                      onTap: () => _showProductDetails(context, product),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showAddProductDialog(BuildContext context) {
    if (kDebugMode)
      print('[DEBUG] Add Product button clicked, showing modal...');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        if (kDebugMode) print('[DEBUG] Building _AddProductSheet...');
        return _AddProductSheet();
      },
    ).then((value) {
      if (kDebugMode) print('[DEBUG] Add Product modal closed');
    });
  }

  void _showProductDetails(BuildContext context, Product product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) =>
          _ProductDetailsSheet(product: product, readOnly: widget.readOnly),
    );
  }

  // DEV TEST METHOD (hidden in production)
  Future<void> _runDevTest() async {
    try {
      if (kDebugMode) print('[DEV TEST] Starting inventory test...');

      final createProduct = ref.read(createProductProvider);
      final sessionManager = SessionManager();
      final shopId = await sessionManager.getString('shop_id');

      if (kDebugMode) print('[DEV TEST] ShopId: $shopId');

      // Create dummy product
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final product = await createProduct(
        name: 'Test Product $timestamp',
        priceCents: 9999,
        sku: 'TEST-$timestamp',
        initialQty: 10,
        reorderLevel: 5,
      );

      if (kDebugMode) {
        print(
          '[DEV TEST] Product created: id=${product.id}, name=${product.name}',
        );
      }

      // Wait a moment for inventory to be created
      await Future.delayed(const Duration(milliseconds: 500));

      // Adjust stock
      final adjustStock = ref.read(adjustStockProvider);
      final movementId = await adjustStock(
        productId: product.id,
        qtyDelta: 10,
        type: StockMovementType.adjustment,
        reason: 'DEV TEST: Adding stock',
      );

      if (kDebugMode)
        print('[DEV TEST] Stock adjusted: movementId=$movementId');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ DEV TEST: Created "${product.name}" with 20 units total',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e, stack) {
      print('[DEV TEST ERROR] $e');
      print('[DEV TEST STACK] $stack');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ DEV TEST FAILED: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  // DEV METHOD: Fix missing inventory records
  Future<void> _fixMissingInventory() async {
    try {
      if (kDebugMode) print('[DEV FIX] Starting inventory fix...');

      final fixProvider = ref.read(fixMissingInventoryProvider.future);
      final fixedCount = await fixProvider;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ FIX: Created $fixedCount inventory records for existing products',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }

      // Refresh the products list
      ref.invalidate(productsProvider);
    } catch (e, stack) {
      print('[DEV FIX ERROR] $e');
      print('[DEV FIX STACK] $stack');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ FIX FAILED: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }
}

/// Product card widget
class _ProductCard extends StatelessWidget {
  final Product product;
  final bool readOnly;
  final VoidCallback onTap;

  const _ProductCard({
    required this.product,
    required this.readOnly,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final currentStock = product.availableQty;
    final isLowStock = product.isLowStock;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: isLowStock
              ? Colors.red.shade100
              : Colors.blue.shade100,
          child: Icon(
            Icons.inventory_2,
            color: isLowStock ? Colors.red : Colors.blue,
          ),
        ),
        title: Text(
          product.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (product.sku != null) Text('SKU: ${product.sku}'),
            Text('₦${product.price.toStringAsFixed(2)}'),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              currentStock.toString(),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isLowStock ? Colors.red : Colors.black,
              ),
            ),
            Text(
              isLowStock ? 'Low Stock' : 'In Stock',
              style: TextStyle(
                fontSize: 12,
                color: isLowStock ? Colors.red : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Add product bottom sheet
class _AddProductSheet extends ConsumerStatefulWidget {
  @override
  ConsumerState<_AddProductSheet> createState() => _AddProductSheetState();
}

class _AddProductSheetState extends ConsumerState<_AddProductSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _skuController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _priceController = TextEditingController();
  final _costController = TextEditingController();
  final _reorderLevelController = TextEditingController(text: '0');
  final _initialQtyController = TextEditingController(text: '0');

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    if (kDebugMode) print('[DEBUG] _AddProductSheet initialized');
  }

  @override
  void dispose() {
    if (kDebugMode) print('[DEBUG] _AddProductSheet disposed');
    _nameController.dispose();
    _skuController.dispose();
    _barcodeController.dispose();
    _priceController.dispose();
    _costController.dispose();
    _reorderLevelController.dispose();
    _initialQtyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (kDebugMode) print('[DEBUG] _AddProductSheet building UI...');
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Add New Product',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Product Name *',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter product name';
                  }
                  return null;
                },
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _skuController,
                      decoration: const InputDecoration(
                        labelText: 'SKU',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _barcodeController,
                      decoration: const InputDecoration(
                        labelText: 'Barcode',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _priceController,
                      decoration: const InputDecoration(
                        labelText: 'Sale Price *',
                        border: OutlineInputBorder(),
                        prefixText: '₦ ',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d{0,2}'),
                        ),
                      ],
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Required';
                        }
                        final price = double.tryParse(value);
                        if (price == null || price < 0) {
                          return 'Invalid price';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _costController,
                      decoration: const InputDecoration(
                        labelText: 'Cost Price',
                        border: OutlineInputBorder(),
                        prefixText: '₦ ',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d{0,2}'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _reorderLevelController,
                      decoration: const InputDecoration(
                        labelText: 'Reorder Level',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _initialQtyController,
                      decoration: const InputDecoration(
                        labelText: 'Initial Quantity',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSubmitting
                          ? null
                          : () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: FilledButton(
                      onPressed: _isSubmitting ? null : _handleSubmit,
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Add Product'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleSubmit() async {
    if (kDebugMode) print('[DEBUG] Submit button clicked');

    if (!_formKey.currentState!.validate()) {
      if (kDebugMode) print('[DEBUG] Form validation failed');
      return;
    }

    if (kDebugMode) print('[DEBUG] Form validated, submitting...');
    setState(() => _isSubmitting = true);

    try {
      final createProduct = ref.read(createProductProvider);

      final price = double.parse(_priceController.text);
      final priceCents = (price * 100).toInt();

      int? costCents;
      if (_costController.text.isNotEmpty) {
        final cost = double.parse(_costController.text);
        costCents = (cost * 100).toInt();
      }

      final name = _nameController.text.trim();
      final qty = int.tryParse(_initialQtyController.text) ?? 0;

      if (kDebugMode)
        print(
          '[DEBUG] Creating product: name=$name, price=\$${price}, qty=$qty',
        );

      final product = await createProduct(
        name: name,
        priceCents: priceCents,
        sku: _skuController.text.trim().isEmpty
            ? null
            : _skuController.text.trim(),
        barcode: _barcodeController.text.trim().isEmpty
            ? null
            : _barcodeController.text.trim(),
        costCents: costCents,
        reorderLevel: int.tryParse(_reorderLevelController.text) ?? 0,
        initialQty: qty,
      );

      if (kDebugMode)
        print('[DEBUG] Product created successfully: id=${product.id}');

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Product "${product.name}" added successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e, stack) {
      if (kDebugMode) {
        print('[ERROR] Failed to create product: $e');
        print('[ERROR] Stack trace: $stack');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}

/// Product details bottom sheet
class _ProductDetailsSheet extends ConsumerStatefulWidget {
  final Product product;
  final bool readOnly;

  const _ProductDetailsSheet({required this.product, required this.readOnly});

  @override
  ConsumerState<_ProductDetailsSheet> createState() =>
      _ProductDetailsSheetState();
}

class _ProductDetailsSheetState extends ConsumerState<_ProductDetailsSheet> {
  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      widget.product.name,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  if (!widget.readOnly)
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'delete') {
                          _handleDelete();
                        }
                        // TODO: Add edit functionality
                      },
                      itemBuilder: (context) => [
                        // const PopupMenuItem(value: 'edit', child: Text('Edit')), // TODO: Implement edit
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text(
                            'Delete',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              const Divider(),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    _InfoRow(label: 'SKU', value: widget.product.sku ?? '-'),
                    _InfoRow(
                      label: 'Barcode',
                      value: widget.product.barcode ?? '-',
                    ),
                    _InfoRow(
                      label: 'Price',
                      value: '₦${widget.product.price.toStringAsFixed(2)}',
                    ),
                    _InfoRow(
                      label: 'Cost',
                      value: widget.product.cost != null
                          ? '₦${widget.product.cost!.toStringAsFixed(2)}'
                          : '-',
                    ),
                    _InfoRow(
                      label: 'Current Stock',
                      value: widget.product.availableQty.toString(),
                      highlight: widget.product.isLowStock,
                    ),
                    _InfoRow(
                      label: 'Reorder Level',
                      value: widget.product.reorderLevel.toString(),
                    ),
                    _InfoRow(
                      label: 'Status',
                      value: widget.product.isActive ? 'Active' : 'Inactive',
                    ),
                    const SizedBox(height: 24),
                    if (!widget.readOnly) ...[
                      const Text(
                        'Stock Adjustment',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () => _showStockAdjustment(
                                context,
                                isAddition: true,
                              ),
                              icon: const Icon(Icons.add),
                              label: const Text('Add Stock'),
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.green,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _showStockAdjustment(
                                context,
                                isAddition: false,
                              ),
                              icon: const Icon(Icons.remove),
                              label: const Text('Remove Stock'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showStockAdjustment(BuildContext context, {required bool isAddition}) {
    final qtyController = TextEditingController();
    final reasonController = TextEditingController();
    final parentContext = context; // Capture parent context

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(isAddition ? 'Add Stock' : 'Remove Stock'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: qtyController,
              decoration: const InputDecoration(
                labelText: 'Quantity',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final qty = int.tryParse(qtyController.text);
              if (qty == null || qty <= 0) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a valid quantity'),
                  ),
                );
                return;
              }

              // Close the adjustment dialog first
              Navigator.pop(dialogContext);

              try {
                final adjustStock = ref.read(adjustStockProvider);
                await adjustStock(
                  productId: widget.product.id,
                  qtyDelta: isAddition ? qty : -qty,
                  type: StockMovementType.adjustment,
                  reason: reasonController.text.trim().isEmpty
                      ? null
                      : reasonController.text.trim(),
                );

                if (mounted) {
                  // Show success message
                  ScaffoldMessenger.of(parentContext).showSnackBar(
                    const SnackBar(
                      content: Text('Stock adjusted successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  // Close the product details sheet
                  Navigator.pop(parentContext);
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(parentContext).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Product'),
        content: Text(
          'Are you sure you want to delete "${widget.product.name}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final deleteProduct = ref.read(deleteProductProvider);
        await deleteProduct(widget.product.id);

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Product deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }
}

/// Info row widget
class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;

  const _InfoRow({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: highlight ? Colors.red : null,
            ),
          ),
        ],
      ),
    );
  }
}
