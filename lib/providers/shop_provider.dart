import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Active shop ID provider
final activeShopIdProvider = StateProvider<String?>((ref) => null);

/// Current user's role in the active shop
final currentRoleProvider = FutureProvider.autoDispose<String?>((ref) async {
  final shopId = ref.watch(activeShopIdProvider);
  if (shopId == null) return null;

  final sb = Supabase.instance.client;
  final uid = sb.auth.currentUser?.id;
  if (uid == null) return null;

  try {
    final row = await sb
        .from('staff')
        .select('role')
        .eq('shop_id', shopId)
        .eq('user_id', uid)
        .eq('is_active', true)
        .maybeSingle();

    return row?['role'] as String?;
  } catch (e) {
    print('Error fetching user role: $e');
    return null;
  }
});

/// Permission helpers based on role
class Permissions {
  final String role;

  const Permissions(this.role);

  /// Can edit catalog (products, categories)
  bool get canEditCatalog => role == 'owner' || role == 'manager';

  /// Can sell products
  bool get canSell => role == 'owner' || role == 'manager' || role == 'cashier';

  /// Can view reports
  bool get canViewReports => role == 'owner' || role == 'manager';

  /// Can manage staff
  bool get canManageStaff => role == 'owner';

  /// Can modify settings
  bool get canModifySettings => role == 'owner' || role == 'manager';

  /// Can delete orders
  bool get canDeleteOrders => role == 'owner' || role == 'manager';

  /// Can give discounts
  bool get canGiveDiscounts => role == 'owner' || role == 'manager';

  /// Can process refunds
  bool get canProcessRefunds => role == 'owner' || role == 'manager';
}

/// Permissions provider based on current role
final permissionsProvider = Provider.autoDispose<Permissions?>((ref) {
  final roleAsync = ref.watch(currentRoleProvider);

  return roleAsync.when(
    data: (role) => role != null ? Permissions(role) : null,
    loading: () => null,
    error: (_, __) => null,
  );
});
