import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/repositories/supabase_sales_repository.dart';
import '../services/supabase_client.dart';
import '../common/session.dart';

/// Supabase client provider
final supabaseProvider = Provider<SupabaseClient>(
  (ref) => SupabaseService.client,
);

/// Sales repository provider
final salesRepoProvider = Provider<SupabaseSalesRepository>(
  (ref) => SupabaseSalesRepository(ref.read(supabaseProvider)),
);

/// Currency symbol provider - gets from shop settings
final currencySymbolProvider = FutureProvider<String>((ref) async {
  final sessionManager = SessionManager();
  final shopId = await sessionManager.getString('shop_id');

  if (shopId == null || shopId.isEmpty) {
    return '₦'; // Default to Naira
  }

  try {
    final supabase = ref.read(supabaseProvider);
    final shop = await supabase
        .from('shops')
        .select('currency_code')
        .eq('id', shopId)
        .single();

    final currencyCode = shop['currency_code'] as String? ?? 'NGN';

    // Convert currency code to symbol
    switch (currencyCode.toUpperCase()) {
      case 'NGN':
        return '₦';
      case 'GHS':
        return '₵';
      case 'KES':
        return 'KSh';
      case 'ZAR':
        return 'R';
      case 'EGP':
        return 'E£';
      case 'XOF':
        return 'CFA';
      case 'XAF':
        return 'FCFA';
      default:
        return '₦'; // Default to Naira
    }
  } catch (e) {
    if (kDebugMode) {
      print('[DEBUG] currencySymbolProvider: error fetching currency: $e');
    }
    return '₦'; // Default to Naira on error
  }
});

/// Money formatting helper
String formatMoney(int cents, String symbol) {
  final value = cents / 100.0;
  return '$symbol${value.toStringAsFixed(2)}';
}

/// Paged orders list with real-time updates
class SalesPager extends StateNotifier<AsyncValue<List<Map<String, dynamic>>>> {
  SalesPager(this.ref) : super(const AsyncLoading()) {
    _initialize();
  }

  final Ref ref;
  late final String _shopId;
  static const _pageSize = 20;
  int _offset = 0;
  bool _done = false;
  RealtimeChannel? _subscription;

  Future<void> _initialize() async {
    final sessionManager = SessionManager();
    _shopId = await sessionManager.getString('shop_id') ?? '';

    if (_shopId.isEmpty) {
      state = AsyncError('No shop ID found', StackTrace.current);
      return;
    }

    // Load initial data
    await load(reset: true);

    // Subscribe to real-time updates
    _subscription = ref
        .read(salesRepoProvider)
        .subscribeOrders(
          shopId: _shopId,
          onChange: (payload) {
            if (kDebugMode) {
              print('[DEBUG] SalesPager: real-time update received');
            }
            // Reload data when orders change
            load(reset: true);
          },
        );
  }

  Future<void> load({bool reset = false}) async {
    if (reset) {
      _offset = 0;
      _done = false;
      if (state.value == null) {
        state = const AsyncLoading();
      }
    }

    if (_done) return;

    try {
      final repo = ref.read(salesRepoProvider);
      final current = state.value ?? [];

      if (kDebugMode) {
        print('[DEBUG] SalesPager: loading orders, offset=$_offset');
      }

      final next = await repo.fetchOrders(
        shopId: _shopId,
        limit: _pageSize,
        offset: _offset,
      );

      _offset += next.length;
      _done = next.length < _pageSize;

      final newOrders = reset ? next : [...current, ...next];
      state = AsyncData(newOrders);

      if (kDebugMode) {
        print(
          '[DEBUG] SalesPager: loaded ${next.length} orders, total: ${newOrders.length}',
        );
      }
    } catch (e, stack) {
      if (kDebugMode) {
        print('[ERROR] SalesPager: failed to load orders: $e');
      }
      state = AsyncError(e, stack);
    }
  }

  /// Refresh data (pull-to-refresh)
  Future<void> refresh() async {
    await load(reset: true);
  }

  @override
  void dispose() {
    _subscription?.unsubscribe();
    super.dispose();
  }
}

/// Sales pager provider
final salesPagerProvider =
    StateNotifierProvider<SalesPager, AsyncValue<List<Map<String, dynamic>>>>(
      (ref) => SalesPager(ref),
    );

/// Sales summary provider for dashboard widgets
final salesSummaryProvider =
    FutureProvider.family<
      Map<String, dynamic>,
      ({String shopId, DateTime? startDate, DateTime? endDate})
    >((ref, args) async {
      final repo = ref.read(salesRepoProvider);
      return repo.getSalesSummary(
        shopId: args.shopId,
        startDate: args.startDate,
        endDate: args.endDate,
      );
    });
