import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';
import '../services/shop_service.dart';

/// Auth service provider
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

/// Profile service provider
final profileServiceProvider = Provider<ProfileService>((ref) {
  return ProfileService();
});

/// Shop service provider
final shopServiceProvider = Provider<ShopService>((ref) {
  return ShopService();
});

/// Current auth state provider
final authStateProvider = StreamProvider<AuthState>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.authStateChanges;
});

/// Current user provider
final currentUserProvider = Provider<User?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.maybeWhen(
    data: (state) => state.session?.user,
    orElse: () => null,
  );
});

/// Current user ID provider
final currentUserIdProvider = Provider<String?>((ref) {
  return ref.watch(currentUserProvider)?.id;
});

/// Is authenticated provider
final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(currentUserProvider) != null;
});

/// Current user profile provider
final currentProfileProvider = FutureProvider<Profile?>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return null;

  final profileService = ref.watch(profileServiceProvider);
  return profileService.getCurrentProfile();
});

/// Current user's shops provider
final userShopsProvider = FutureProvider<List<StaffMembership>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return [];

  final shopService = ref.watch(shopServiceProvider);
  return shopService.getUserShops();
});

/// Active shop ID state provider (persisted in shared preferences)
final activeShopIdProvider = StateProvider<String?>((ref) => null);

/// Active shop provider
final activeShopProvider = FutureProvider<Shop?>((ref) async {
  final shopId = ref.watch(activeShopIdProvider);
  if (shopId == null) return null;

  final shopService = ref.watch(shopServiceProvider);
  return shopService.getShop(shopId);
});

/// Active shop role provider
final activeShopRoleProvider = FutureProvider<String?>((ref) async {
  final shopId = ref.watch(activeShopIdProvider);
  if (shopId == null) return null;

  final shopService = ref.watch(shopServiceProvider);
  return shopService.getUserRole(shopId);
});

/// Check if user is owner of active shop
final isShopOwnerProvider = Provider<bool>((ref) {
  final role = ref.watch(activeShopRoleProvider);
  return role.maybeWhen(data: (r) => r == 'owner', orElse: () => false);
});

/// Check if user is manager or owner of active shop
final isShopManagerProvider = Provider<bool>((ref) {
  final role = ref.watch(activeShopRoleProvider);
  return role.maybeWhen(
    data: (r) => r == 'owner' || r == 'manager',
    orElse: () => false,
  );
});

/// Auth loading state provider
final authLoadingProvider = StateProvider<bool>((ref) => false);

/// Auth error provider
final authErrorProvider = StateProvider<String?>((ref) => null);
