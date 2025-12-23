import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/sales_providers.dart';

/// Format payment method label from backend value
String formatPaymentMethod(String? method) {
  switch (method) {
    case 'cash':
      return 'Cash';
    case 'card':
      return 'POS';
    case 'transfer':
      return 'Bank';
    default:
      return method ?? 'Cash';
  }
}

/// Get payment method icon
String getPaymentMethodIcon(String? method) {
  switch (method) {
    case 'cash':
      return '💵';
    case 'card':
      return '🧾';
    case 'transfer':
      return '🏦';
    default:
      return '💵';
  }
}

class SalesHistoryPageSupabase extends ConsumerWidget {
  const SalesHistoryPageSupabase({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(salesPagerProvider);
    final currencyAsync = ref.watch(currencySymbolProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales History'),
        actions: [
          IconButton(
            onPressed: () => ref.read(salesPagerProvider.notifier).refresh(),
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh sales',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(salesPagerProvider.notifier).refresh(),
        child: ordersAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => _buildErrorView(context, error.toString()),
          data: (orders) {
            return currencyAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) =>
                  _buildErrorView(context, 'Failed to load currency settings'),
              data: (symbol) => _buildOrdersList(context, ref, orders, symbol),
            );
          },
        ),
      ),
    );
  }

  Widget _buildErrorView(BuildContext context, String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'Failed to load sales',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            Consumer(
              builder: (context, ref, child) {
                return ElevatedButton(
                  onPressed: () {
                    // Refresh the data
                    ref.read(salesPagerProvider.notifier).refresh();
                  },
                  child: const Text('Retry'),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrdersList(
    BuildContext context,
    WidgetRef ref,
    List<Map<String, dynamic>> orders,
    String symbol,
  ) {
    if (orders.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No sales yet',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Start making sales to see them here!',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    // Group orders by date (yyyy-MM-dd)
    final dateFormatter = DateFormat('EEE, MMM d');
    final groups = <String, List<Map<String, dynamic>>>{};

    for (final order in orders) {
      final createdAt = DateTime.parse(order['created_at'] as String);
      final dateKey = DateFormat('yyyy-MM-dd').format(createdAt);
      (groups[dateKey] ??= []).add(order);
    }

    // Sort dates in descending order (newest first)
    final sortedDates = groups.keys.toList()..sort((a, b) => b.compareTo(a));

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        // Load more when scrolling near the bottom
        if (notification.metrics.extentAfter < 400) {
          ref.read(salesPagerProvider.notifier).load();
        }
        return false;
      },
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 24),
        itemCount: sortedDates.length,
        itemBuilder: (context, index) {
          final dateKey = sortedDates[index];
          final dayOrders = groups[dateKey]!;
          final date = DateTime.parse('${dateKey}T00:00:00Z');
          final dayLabel = dateFormatter.format(date);

          // Calculate total for the day
          final dayTotal = dayOrders.fold<int>(
            0,
            (sum, order) => sum + (order['total_cents'] as int? ?? 0),
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Day header
              Container(
                color: Colors.grey[200],
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      dayLabel,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                    ),
                    Text(
                      formatMoney(dayTotal, symbol),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Colors.green[700],
                      ),
                    ),
                  ],
                ),
              ),
              // Orders for the day
              ...dayOrders.map(
                (order) => _OrderTile(order: order, symbol: symbol),
              ),
              const Divider(height: 1),
            ],
          );
        },
      ),
    );
  }
}

class _OrderTile extends StatelessWidget {
  const _OrderTile({required this.order, required this.symbol});

  final Map<String, dynamic> order;
  final String symbol;

  @override
  Widget build(BuildContext context) {
    final createdAt = DateTime.parse(order['created_at'] as String);
    final time = DateFormat('h:mm a').format(createdAt);
    final total = order['total_cents'] as int? ?? 0;
    final orderItems = (order['order_items'] as List<dynamic>? ?? []);
    final paymentMethod = order['payment_method'] as String?;
    final methodLabel = formatPaymentMethod(paymentMethod);
    final methodIcon = getPaymentMethodIcon(paymentMethod);

    // Get first item name and count additional items
    String firstItemName = 'Order';
    String moreText = '';

    if (orderItems.isNotEmpty) {
      final firstItem = orderItems.first;
      final product = firstItem['products'] as Map<String, dynamic>?;
      firstItemName = product?['name'] as String? ?? 'Item';

      if (orderItems.length > 1) {
        moreText = ' +${orderItems.length - 1} more';
      }
    }

    return ListTile(
      title: Text('$firstItemName$moreText'),
      subtitle: Text('$time • $methodIcon $methodLabel'),
      trailing: Text(
        formatMoney(total, symbol),
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w500,
          color: Colors.green[700],
        ),
      ),
      onTap: () => _showOrderDetails(context, order, symbol),
    );
  }

  void _showOrderDetails(
    BuildContext context,
    Map<String, dynamic> order,
    String symbol,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _OrderDetailPage(order: order, symbol: symbol),
      ),
    );
  }
}

class _OrderDetailPage extends StatelessWidget {
  const _OrderDetailPage({required this.order, required this.symbol});

  final Map<String, dynamic> order;
  final String symbol;

  @override
  Widget build(BuildContext context) {
    final orderItems = (order['order_items'] as List<dynamic>? ?? []);
    final total = order['total_cents'] as int? ?? 0;
    final createdAt = DateTime.parse(order['created_at'] as String);
    final orderId = order['id'] as String? ?? '';
    final paymentMethod = order['payment_method'] as String?;
    final methodLabel = formatPaymentMethod(paymentMethod);
    final methodIcon = getPaymentMethodIcon(paymentMethod);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sale Details'),
        actions: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Order header
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Order #${orderId.substring(0, 8)}',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        formatMoney(total, symbol),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.green[700],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    DateFormat('MMM d, yyyy • h:mm a').format(createdAt),
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(methodIcon, style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 4),
                      Text(
                        'Payment: $methodLabel',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: Colors.blue[700],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Items list
          Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Items (${orderItems.length})',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Divider(height: 1),
                ...orderItems.map((item) {
                  final product = item['products'] as Map<String, dynamic>?;
                  final name = product?['name'] as String? ?? 'Item';
                  final sku = product?['sku'] as String? ?? '';
                  final qty = item['qty'] as num? ?? 0;
                  final unitPrice = item['unit_price_cents'] as int? ?? 0;
                  final lineTotal =
                      item['total_cents'] as int? ?? (qty * unitPrice).round();

                  return ListTile(
                    title: Text(name),
                    subtitle: Text('SKU: $sku'),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'x${qty.toStringAsFixed(0)}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        Text(
                          formatMoney(lineTotal, symbol),
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  );
                }),

                const Divider(height: 1),

                // Total
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        formatMoney(total, symbol),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.green[700],
                        ),
                      ),
                    ],
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
