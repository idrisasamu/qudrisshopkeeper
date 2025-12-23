import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/reports_providers.dart';

class ReportsPageSupabase extends ConsumerWidget {
  const ReportsPageSupabase({super.key});

  String _fmt(int cents, String symbol) {
    final v = (cents / 100).toStringAsFixed(2);
    return '$symbol$v';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(salesSummaryProvider);
    const currency = '₦'; // Naira symbol

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) async {
              final now = DateTime.now();
              DateTimeRange newRange;

              if (v == 'today') {
                final today = DateTime(now.year, now.month, now.day);
                newRange = DateTimeRange(
                  start: today,
                  end: today.add(const Duration(days: 1)),
                );
              } else if (v == '7') {
                final end = DateTime(
                  now.year,
                  now.month,
                  now.day,
                ).add(const Duration(days: 1));
                newRange = DateTimeRange(
                  start: end.subtract(const Duration(days: 7)),
                  end: end,
                );
              } else if (v == '30') {
                final end = DateTime(
                  now.year,
                  now.month,
                  now.day,
                ).add(const Duration(days: 1));
                newRange = DateTimeRange(
                  start: end.subtract(const Duration(days: 30)),
                  end: end,
                );
              } else if (v == 'custom') {
                final picked = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                  initialDateRange: ref.read(reportRangeProvider),
                );
                if (picked != null) {
                  newRange = picked;
                } else {
                  return; // User cancelled
                }
              } else {
                return; // Unknown option
              }

              ref.read(reportRangeProvider.notifier).state = newRange;
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'today', child: Text('Today')),
              PopupMenuItem(value: '7', child: Text('Last 7 days')),
              PopupMenuItem(value: '30', child: Text('Last 30 days')),
              PopupMenuItem(value: 'custom', child: Text('Custom range...')),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.refresh(salesSummaryProvider),
          ),
        ],
      ),
      body: summary.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                'Failed to load reports',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                '$e',
                style: const TextStyle(fontSize: 12),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => ref.refresh(salesSummaryProvider),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (map) {
          final total = (map['totalSalesCents'] as int? ?? 0);
          final count = (map['transactionCount'] as int? ?? 0);
          final top = (map['topItems'] as List?) ?? <Map<String, dynamic>>[];

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Date range info
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.date_range, color: Colors.blue),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Consumer(
                          builder: (context, ref, child) {
                            final range = ref.watch(reportRangeProvider);
                            return Text(
                              '${_formatDate(range.start)} - ${_formatDate(range.end.subtract(const Duration(days: 1)))}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Summary cards
              Card(
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.green,
                    child: Text(
                      '₦',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: const Text('Total Sales'),
                  subtitle: Text('$count transactions'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _fmt(total, currency),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.chevron_right, color: Colors.grey),
                    ],
                  ),
                  onTap: () => _showPaymentMethodBreakdown(context, ref),
                ),
              ),

              const SizedBox(height: 16),

              // Top selling items
              const Text(
                'Top Selling Items',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),

              if (top.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.inventory_2_outlined,
                            size: 48,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 8),
                          Text('No sales data for this period'),
                        ],
                      ),
                    ),
                  ),
                )
              else
                ...top.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: _getRankColor(index),
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        item['name'] as String? ?? 'Unknown Product',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      subtitle: Text(
                        'SKU: ${(item['sku'] as String?) ?? 'N/A'}',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'x${item['qty']}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'units sold',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),

              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Color _getRankColor(int index) {
    switch (index) {
      case 0:
        return Colors.amber[700]!; // Gold
      case 1:
        return Colors.grey[600]!; // Silver
      case 2:
        return Colors.brown[600]!; // Bronze
      default:
        return Colors.blue[600]!; // Default
    }
  }

  void _showPaymentMethodBreakdown(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Consumer(
          builder: (context, ref, child) {
            final breakdownAsync = ref.watch(paymentMethodBreakdownProvider);
            const currency = '₦';

            return breakdownAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(48),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Failed to load breakdown',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$error',
                      style: const TextStyle(fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              data: (breakdown) {
                final cashData =
                    breakdown['cash'] as Map<String, dynamic>? ?? {};
                final cardData =
                    breakdown['card'] as Map<String, dynamic>? ?? {};
                final transferData =
                    breakdown['transfer'] as Map<String, dynamic>? ?? {};
                final grandTotal = breakdown['grandTotal'] as int? ?? 0;
                final grandCount = breakdown['grandCount'] as int? ?? 0;

                final cashTotal = cashData['total'] as int? ?? 0;
                final cashCount = cashData['count'] as int? ?? 0;
                final cardTotal = cardData['total'] as int? ?? 0;
                final cardCount = cardData['count'] as int? ?? 0;
                final transferTotal = transferData['total'] as int? ?? 0;
                final transferCount = transferData['count'] as int? ?? 0;

                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Sales Breakdown',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(ctx),
                            icon: const Icon(Icons.close),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'By Payment Method',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                      const Divider(height: 24),

                      // Cash
                      _buildPaymentMethodRow(
                        icon: '💵',
                        label: 'Cash',
                        total: cashTotal,
                        count: cashCount,
                        currency: currency,
                        color: Colors.green,
                      ),
                      const SizedBox(height: 12),

                      // POS
                      _buildPaymentMethodRow(
                        icon: '🧾',
                        label: 'POS',
                        total: cardTotal,
                        count: cardCount,
                        currency: currency,
                        color: Colors.blue,
                      ),
                      const SizedBox(height: 12),

                      // Bank
                      _buildPaymentMethodRow(
                        icon: '🏦',
                        label: 'Bank',
                        total: transferTotal,
                        count: transferCount,
                        currency: currency,
                        color: Colors.orange,
                      ),
                      const Divider(height: 24),

                      // Total
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total Sales',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                _fmt(grandTotal, currency),
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                              Text(
                                '$grandCount transaction${grandCount != 1 ? 's' : ''}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildPaymentMethodRow({
    required String icon,
    required String label,
    required int total,
    required int count,
    required String currency,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '$count transaction${count != 1 ? 's' : ''}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Text(
            _fmt(total, currency),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
