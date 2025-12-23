import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseReportsRepository {
  final SupabaseClient _client;
  SupabaseReportsRepository(this._client);

  Future<Map<String, dynamic>> getSummary({
    required String shopId,
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      // Convert to UTC and ensure proper date filtering
      final fromUtc = DateTime(from.year, from.month, from.day).toUtc();
      final toUtc = DateTime(to.year, to.month, to.day).toUtc();

      // Get totals and order IDs with proper UTC filtering
      final totals = await _client
          .from('orders')
          .select('total_cents, id')
          .gte('created_at', fromUtc.toIso8601String())
          .lt(
            'created_at',
            toUtc.add(const Duration(days: 1)).toIso8601String(),
          )
          .eq('shop_id', shopId)
          .eq('status', 'completed')
          .inFilter('payment_status', ['paid', 'partial'])
          .isFilter('deleted_at', null); // treat soft-deletes as excluded

      int totalSalesCents = 0;
      final orderIds = <String>[];
      for (final row in (totals as List)) {
        totalSalesCents += (row['total_cents'] as num?)?.toInt() ?? 0;
        orderIds.add(row['id'] as String);
      }

      // transactions count
      final txCount = orderIds.length;

      // top selling items (by qty)
      // join order_items + products
      final top = await _client
          .from('order_items')
          .select('product_id, qty, products:product_id(name, sku)')
          .inFilter('order_id', orderIds);

      final qtyByProduct = <String, Map<String, dynamic>>{};
      for (final row in (top as List)) {
        final pid = row['product_id'] as String;
        final product = row['products'] as Map<String, dynamic>?;
        qtyByProduct.putIfAbsent(
          pid,
          () => {
            'product_id': pid,
            'name': (product?['name'] as String?) ?? 'Unknown',
            'sku': (product?['sku'] as String?) ?? '',
            'qty': 0,
          },
        );
        qtyByProduct[pid]!['qty'] =
            (qtyByProduct[pid]!['qty'] as int) +
            ((row['qty'] as num?)?.toInt() ?? 0);
      }

      final topItems = qtyByProduct.values.toList()
        ..sort((a, b) => (b['qty'] as int).compareTo(a['qty'] as int));

      return {
        'totalSalesCents': totalSalesCents,
        'transactionCount': txCount,
        'topItems': topItems.take(10).toList(),
      };
    } catch (e) {
      print('[ERROR] SupabaseReportsRepository.getSummary: $e');
      rethrow;
    }
  }

  Future<String> getCurrencySymbol(String shopId) async {
    try {
      final row = await _client
          .from('shops')
          .select('currency')
          .eq('id', shopId)
          .maybeSingle();

      final code = (row?['currency'] as String?)?.toUpperCase() ?? 'NGN';
      // minimal map; extend if needed
      const map = {
        'NGN': '₦',
        'GHS': '₵',
        'KES': 'KSh',
        'ZAR': 'R',
        'XOF': 'CFA',
        'XAF': 'FCFA',
        'EGP': 'E£',
        'MAD': 'د.م',
        'TND': 'د.ت',
      };
      return map[code] ?? '₦';
    } catch (e) {
      print('[ERROR] SupabaseReportsRepository.getCurrencySymbol: $e');
      return '₦'; // fallback to naira
    }
  }

  /// Get sales breakdown by payment method
  Future<Map<String, dynamic>> getPaymentMethodBreakdown({
    required String shopId,
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      // Convert to UTC and ensure proper date filtering
      final fromUtc = DateTime(from.year, from.month, from.day).toUtc();
      final toUtc = DateTime(to.year, to.month, to.day).toUtc();

      // Get orders with payment method breakdown
      final orders = await _client
          .from('orders')
          .select('total_cents, payment_method')
          .gte('created_at', fromUtc.toIso8601String())
          .lt(
            'created_at',
            toUtc.add(const Duration(days: 1)).toIso8601String(),
          )
          .eq('shop_id', shopId)
          .eq('status', 'completed')
          .inFilter('payment_status', ['paid', 'partial'])
          .isFilter('deleted_at', null);

      // Calculate totals by payment method
      int cashTotal = 0;
      int cardTotal = 0; // POS
      int transferTotal = 0; // Bank
      int cashCount = 0;
      int cardCount = 0;
      int transferCount = 0;

      for (final order in (orders as List)) {
        final totalCents = (order['total_cents'] as num?)?.toInt() ?? 0;
        final paymentMethod = (order['payment_method'] as String?) ?? 'cash';

        switch (paymentMethod) {
          case 'cash':
            cashTotal += totalCents;
            cashCount++;
            break;
          case 'card':
            cardTotal += totalCents;
            cardCount++;
            break;
          case 'transfer':
            transferTotal += totalCents;
            transferCount++;
            break;
          default:
            // Default to cash if unknown
            cashTotal += totalCents;
            cashCount++;
        }
      }

      return {
        'cash': {'total': cashTotal, 'count': cashCount},
        'card': {'total': cardTotal, 'count': cardCount},
        'transfer': {'total': transferTotal, 'count': transferCount},
        'grandTotal': cashTotal + cardTotal + transferTotal,
        'grandCount': cashCount + cardCount + transferCount,
      };
    } catch (e) {
      print('[ERROR] SupabaseReportsRepository.getPaymentMethodBreakdown: $e');
      rethrow;
    }
  }
}
