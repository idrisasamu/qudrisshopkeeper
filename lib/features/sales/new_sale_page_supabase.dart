import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/supabase_inventory_repository.dart';
import '../../providers/inventory_provider.dart';
import '../../common/session.dart';

/// Payment method UI options
enum PaymentMethodUi { cash, pos, bank }

extension PaymentMethodUiX on PaymentMethodUi {
  String get label => switch (this) {
    PaymentMethodUi.cash => 'Cash',
    PaymentMethodUi.pos => 'POS',
    PaymentMethodUi.bank => 'Bank',
  };

  /// Value expected by Supabase perform_sale(p_payment_method)
  String get toBackend => switch (this) {
    PaymentMethodUi.cash => 'cash',
    PaymentMethodUi.pos => 'card',
    PaymentMethodUi.bank => 'transfer',
  };

  String get icon => switch (this) {
    PaymentMethodUi.cash => '💵',
    PaymentMethodUi.pos => '🧾',
    PaymentMethodUi.bank => '🏦',
  };
}

/// New sale page using Supabase backend
class NewSalePageSupabase extends ConsumerStatefulWidget {
  const NewSalePageSupabase({super.key});

  @override
  ConsumerState<NewSalePageSupabase> createState() =>
      _NewSalePageSupabaseState();
}

class _NewSalePageSupabaseState extends ConsumerState<NewSalePageSupabase> {
  // Cart: productId -> (qty, unitPriceCents)
  final _cart = <String, ({num qty, int unitPriceCents, String name})>{};
  bool _isProcessingSale = false;
  String _searchQuery = '';

  String _getCurrencySymbol() {
    // For now, use default Naira symbol
    // Can be enhanced to use shop.currencySymbol when activeShopProvider is properly set up
    return '₦';
  }

  int get _subtotalCents => _cart.values.fold(
    0,
    (sum, line) => sum + (line.unitPriceCents * line.qty).toInt(),
  );

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider);
    final symbol = _getCurrencySymbol();

    return Scaffold(
      appBar: AppBar(
        title: const Text('New Sale'),
        actions: [
          if (_cart.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () {
                setState(() => _cart.clear());
              },
              tooltip: 'Clear cart',
            ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search products...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
              ),
              onChanged: (value) {
                setState(() => _searchQuery = value.toLowerCase());
              },
            ),
          ),

          // Products list
          Expanded(
            child: productsAsync.when(
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
                              ? 'No products available.\nAdd products in Inventory first.'
                              : 'No products found matching "$_searchQuery"',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                if (products.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 64,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No products available.\nAdd products in Inventory first.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: filteredProducts.length,
                  itemBuilder: (context, index) {
                    final product = filteredProducts[index];
                    final stock = product.inventory?.onHandQty ?? 0;
                    final inCart = _cart[product.id];
                    final qtyInCart = inCart?.qty ?? 0;

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: stock > 0
                              ? Colors.green
                              : Colors.red,
                          child: Text(
                            stock.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          product.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (product.sku != null)
                              Text('SKU: ${product.sku}'),
                            Text(
                              '$symbol${product.price.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                        trailing: stock > 0
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.remove_circle_outline,
                                    ),
                                    onPressed: qtyInCart > 0
                                        ? () {
                                            setState(() {
                                              if (qtyInCart == 1) {
                                                _cart.remove(product.id);
                                              } else {
                                                _cart[product.id] = (
                                                  qty: qtyInCart - 1,
                                                  unitPriceCents:
                                                      product.priceCents,
                                                  name: product.name,
                                                );
                                              }
                                            });
                                          }
                                        : null,
                                  ),
                                  InkWell(
                                    onTap: () => _showQuantityInput(
                                      context,
                                      product,
                                      stock,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      width: 70,
                                      height: 44,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: qtyInCart > 0
                                            ? Colors.blue.shade50
                                            : Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: qtyInCart > 0
                                              ? Colors.blue
                                              : Colors.grey.shade300,
                                          width: 2,
                                        ),
                                      ),
                                      child: Center(
                                        child: Text(
                                          qtyInCart.toString(),
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            color: qtyInCart > 0
                                                ? Colors.blue.shade900
                                                : Colors.grey.shade600,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.add_circle_outline),
                                    onPressed: () {
                                      if (qtyInCart >= stock) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text('Not enough stock'),
                                            backgroundColor: Colors.orange,
                                          ),
                                        );
                                        return;
                                      }
                                      setState(() {
                                        _cart[product.id] = (
                                          qty: qtyInCart + 1,
                                          unitPriceCents: product.priceCents,
                                          name: product.name,
                                        );
                                      });
                                    },
                                  ),
                                ],
                              )
                            : const Text(
                                'Out of stock',
                                style: TextStyle(color: Colors.red),
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
            ),
          ),

          // Cart summary and checkout
          if (_cart.isNotEmpty)
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 12,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Cart items
                    Container(
                      color: Colors.grey.shade50,
                      padding: const EdgeInsets.all(16),
                      constraints: const BoxConstraints(maxHeight: 200),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _cart.length,
                        itemBuilder: (context, index) {
                          final entry = _cart.entries.elementAt(index);
                          final line = entry.value;
                          final lineTotal = (line.unitPriceCents * line.qty)
                              .toInt();

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${line.name} × ${line.qty}',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.black87,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                Text(
                                  '$symbol${(lineTotal / 100).toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const Divider(height: 1, thickness: 2),

                    // Total
                    Container(
                      color: Colors.grey.shade200,
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'TOTAL',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                              letterSpacing: 1.2,
                            ),
                          ),
                          Text(
                            '$symbol${(_subtotalCents / 100).toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Complete sale button
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _isProcessingSale ? null : _completeSale,
                          icon: _isProcessingSale
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.check_circle),
                          label: Text(
                            _isProcessingSale
                                ? 'Processing...'
                                : 'Complete Sale',
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Show payment method picker dialog
  Future<PaymentMethodUi?> _pickPaymentMethod(BuildContext context) async {
    return showModalBottomSheet<PaymentMethodUi>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (ctx) {
        Widget tile(PaymentMethodUi m) => ListTile(
          leading: Text(m.icon, style: const TextStyle(fontSize: 28)),
          title: Text(m.label),
          onTap: () => Navigator.pop(ctx, m),
        );
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              const Text(
                'Select payment method',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              ),
              const Divider(height: 16),
              tile(PaymentMethodUi.cash),
              tile(PaymentMethodUi.pos),
              tile(PaymentMethodUi.bank),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _completeSale() async {
    if (_cart.isEmpty) return;

    // Prompt for payment method first
    final method = await _pickPaymentMethod(context);
    if (method == null || !mounted) return; // User cancelled

    setState(() => _isProcessingSale = true);

    try {
      final sessionManager = SessionManager();
      final shopId = await sessionManager.getString('shop_id');

      if (shopId == null) {
        throw Exception('No shop selected');
      }

      // Prepare sale items
      final items = _cart.entries
          .where((e) => e.value.qty > 0)
          .map(
            (e) => SaleLine(
              productId: e.key,
              qty: e.value.qty,
              unitPriceCents: e.value.unitPriceCents,
            ),
          )
          .toList();

      if (items.isEmpty) {
        throw Exception('Cart is empty');
      }

      // Call perform_sale RPC with selected payment method
      final repository = ref.read(inventoryRepositoryProvider);
      final result = await repository.performSale(
        shopId: shopId,
        items: items,
        channel: 'in_store',
        paymentMethod: method.toBackend, // Pass the selected payment method
        amountCents: _subtotalCents,
      );

      if (!mounted) return;

      // Clear cart
      setState(() {
        _cart.clear();
        _isProcessingSale = false;
      });

      // Show success message with payment method
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Sale completed via ${method.label}! Order: ${result.orderId.substring(0, 8)}...',
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );

      // Inventory will update automatically via real-time subscription
    } catch (e) {
      if (!mounted) return;

      setState(() => _isProcessingSale = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sale failed: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  void _showQuantityInput(BuildContext context, dynamic product, int maxStock) {
    final qtyController = TextEditingController();
    final currentQty = _cart[product.id]?.qty ?? 0;
    if (currentQty > 0) {
      qtyController.text = currentQty.toString();
    }

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Set Quantity: ${product.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: qtyController,
              decoration: InputDecoration(
                labelText: 'Quantity',
                border: const OutlineInputBorder(),
                helperText: 'Available stock: $maxStock',
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              autofocus: true,
              onSubmitted: (_) => _submitQuantity(
                dialogContext,
                product,
                qtyController,
                maxStock,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => _submitQuantity(
              dialogContext,
              product,
              qtyController,
              maxStock,
            ),
            child: const Text('Set'),
          ),
        ],
      ),
    );
  }

  void _submitQuantity(
    BuildContext dialogContext,
    dynamic product,
    TextEditingController qtyController,
    int maxStock,
  ) {
    final qty = int.tryParse(qtyController.text);

    if (qty == null || qty < 0) {
      ScaffoldMessenger.of(dialogContext).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid quantity'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (qty > maxStock) {
      ScaffoldMessenger.of(dialogContext).showSnackBar(
        SnackBar(
          content: Text('Only $maxStock units available'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    Navigator.pop(dialogContext);

    setState(() {
      if (qty == 0) {
        _cart.remove(product.id);
      } else {
        _cart[product.id] = (
          qty: qty,
          unitPriceCents: product.priceCents,
          name: product.name,
        );
      }
    });
  }
}
