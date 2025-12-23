import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/repositories/supabase_reports_repository.dart';
import '../common/session.dart';

final reportsRepoProvider = Provider<SupabaseReportsRepository>((ref) {
  return SupabaseReportsRepository(Supabase.instance.client);
});

final shopIdProvider = FutureProvider<String>((ref) async {
  final sessionManager = SessionManager();
  final shopId = await sessionManager.getString('shop_id');
  if (shopId == null || shopId.isEmpty) {
    throw Exception('Shop ID not found');
  }
  return shopId;
});

final reportRangeProvider = StateProvider<DateTimeRange>((ref) {
  final now = DateTime.now();
  final start = DateTime(now.year, now.month, 1);
  final end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
  return DateTimeRange(start: start, end: end);
});

final currencySymbolProvider = FutureProvider<String>((ref) async {
  final repo = ref.read(reportsRepoProvider);
  final shopIdAsync = ref.watch(shopIdProvider);
  return shopIdAsync.when(
    data: (shopId) => repo.getCurrencySymbol(shopId),
    loading: () => '₦', // fallback while loading
    error: (_, __) => '₦', // fallback on error
  );
});

final salesSummaryProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final repo = ref.read(reportsRepoProvider);
  final shopIdAsync = ref.watch(shopIdProvider);
  final range = ref.watch(reportRangeProvider);

  return shopIdAsync.when(
    data: (shopId) =>
        repo.getSummary(shopId: shopId, from: range.start, to: range.end),
    loading: () => throw Exception('Shop ID loading'),
    error: (error, _) => throw Exception('Shop ID error: $error'),
  );
});

final paymentMethodBreakdownProvider = FutureProvider<Map<String, dynamic>>((
  ref,
) async {
  final repo = ref.read(reportsRepoProvider);
  final shopIdAsync = ref.watch(shopIdProvider);
  final range = ref.watch(reportRangeProvider);

  return shopIdAsync.when(
    data: (shopId) => repo.getPaymentMethodBreakdown(
      shopId: shopId,
      from: range.start,
      to: range.end,
    ),
    loading: () => throw Exception('Shop ID loading'),
    error: (error, _) => throw Exception('Shop ID error: $error'),
  );
});
