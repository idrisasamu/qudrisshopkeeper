import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseSalesRepository {
  SupabaseSalesRepository(this._client);
  final SupabaseClient _client;

  // Common select with nested order items + product info
  static const _orderSelect = '''
    id, shop_id, created_at, channel, payment_method, status,
    subtotal_cents, tax_cents, discount_cents, total_cents,
    amount_cents, amount_paid_cents, customer_id,
    order_items (
      id, product_id, qty, unit_price_cents, total_cents,
      products:product_id ( id, name, sku )
    )
  ''';

  /// Fetch orders with pagination
  Future<List<Map<String, dynamic>>> fetchOrders({
    required String shopId,
    int limit = 20,
    int offset = 0,
  }) async {
    if (kDebugMode) {
      print(
        '[DEBUG] fetchOrders: shopId=$shopId, limit=$limit, offset=$offset',
      );
    }

    try {
      final resp = await _client
          .from('orders')
          .select(_orderSelect)
          .eq('shop_id', shopId)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      final orders = resp.cast<Map<String, dynamic>>();

      if (kDebugMode) {
        print('[DEBUG] fetchOrders: returned ${orders.length} orders');
      }

      return orders;
    } catch (e) {
      print('[ERROR] fetchOrders: $e');
      rethrow;
    }
  }

  /// Fetch a single order with all details
  Future<Map<String, dynamic>> fetchOrder({required String orderId}) async {
    if (kDebugMode) {
      print('[DEBUG] fetchOrder: orderId=$orderId');
    }

    try {
      final resp = await _client
          .from('orders')
          .select(_orderSelect)
          .eq('id', orderId)
          .single();

      return resp;
    } catch (e) {
      print('[ERROR] fetchOrder: $e');
      rethrow;
    }
  }

  /// Get sales summary for a date range
  Future<Map<String, dynamic>> getSalesSummary({
    required String shopId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      var query = _client
          .from('orders')
          .select('total_cents, created_at')
          .eq('shop_id', shopId);

      if (startDate != null) {
        query = query.gte('created_at', startDate.toIso8601String());
      }
      if (endDate != null) {
        query = query.lte('created_at', endDate.toIso8601String());
      }

      final orders = await query;
      final totalCents = orders.fold<int>(
        0,
        (sum, order) => sum + (order['total_cents'] as int? ?? 0),
      );
      final orderCount = orders.length;

      return {'total_cents': totalCents, 'order_count': orderCount};
    } catch (e) {
      print('[ERROR] getSalesSummary: $e');
      rethrow;
    }
  }

  /// Optional realtime on orders for this shop
  RealtimeChannel subscribeOrders({
    required String shopId,
    required void Function(PostgresChangePayload payload) onChange,
  }) {
    if (kDebugMode) {
      print('[DEBUG] subscribeOrders: shopId=$shopId');
    }

    final ch = _client.channel('orders-$shopId');
    ch.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'orders',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'shop_id',
        value: shopId,
      ),
      callback: onChange,
    );
    ch.subscribe();
    return ch;
  }
}
