import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/sign_in_page.dart';
import '../features/auth/register_page.dart';
import '../features/auth/magic_link_page.dart';
import '../services/supabase_client.dart';
import '../features/auth/continue_as_page.dart';
import '../features/auth/login_admin.dart';
import '../features/auth/login_staff.dart';
import '../features/auth/change_pin_page.dart';
import '../features/auth/change_pin_logged_in_page.dart';
import '../features/onboarding/shop_discovery_page.dart'; // Old Google Drive flow
import '../features/onboarding/supabase_shop_selection_page.dart'; // New Supabase flow
import '../features/shop/shop_setup.dart';
import '../features/staff/shop_join_page.dart';
import '../features/staff/staff_home_page.dart';
import '../features/staff/staff_manage_page.dart';
import '../features/staff/supabase_staff_management_page.dart';
import '../features/dashboard/admin_dashboard_page.dart';
import '../features/dashboard/sales_dashboard_page.dart';
import '../features/inventory/inventory_page_supabase.dart';
import '../features/inventory/low_stock_page_supabase.dart';
import '../features/sales/new_sale_page_supabase.dart';
import '../features/qudris/qudris_ai_page.dart';
import '../features/sales/sales_history_page_supabase.dart';
import '../features/sync/sync_page.dart';
import '../features/reports/reports_page_supabase.dart';
import '../features/owner/owner_settings_page.dart';
import '../features/owner/currency_settings_page.dart';
import '../features/owner/license_page.dart' as eula;
import '../features/staff/staff_settings_page.dart';
import '../common/session.dart';

// Route names
const routeContinueAs = '/continue-as';
const routeShopJoin = '/shop-join';
const routeOwnerHome = '/admin'; // your existing Admin Dashboard
const routeStaffHome = '/staff';
const routeAdminLogin = '/auth/admin-login';
const routeStaffLogin = '/auth/staff-login';
const routeShopSetup = '/shop-setup';

// Session helper functions
Future<bool> _hasSession() async {
  final sessionManager = SessionManager();
  final role = await sessionManager.getString('role');
  final shopId = await sessionManager.getString('shop_id');
  return role != null && shopId != null;
}

Future<String> decideStartRoute() async {
  if (!await _hasSession()) return routeContinueAs;
  final sessionManager = SessionManager();
  final role = await sessionManager.getString('role');
  final shopId = await sessionManager.getString('shop_id');

  if (role == 'admin') {
    return routeOwnerHome;
  } else if (role == 'staff') {
    return shopId != null ? routeStaffHome : routeContinueAs;
  }

  return routeContinueAs;
}

// Simple guards for protected pages
Future<bool> requireAdmin(BuildContext ctx) async {
  final sessionManager = SessionManager();
  final role = await sessionManager.getString('role');
  final ok = role == 'admin' || role == 'owner' || role == 'manager';
  if (!ok) {
    ScaffoldMessenger.of(
      ctx,
    ).showSnackBar(const SnackBar(content: Text('Admin access only')));
  }
  return ok;
}

Future<bool> requireStaff(BuildContext ctx) async {
  final sessionManager = SessionManager();
  final role = await sessionManager.getString('role');
  final ok = role == 'staff' || role == 'cashier';
  if (!ok) {
    ScaffoldMessenger.of(
      ctx,
    ).showSnackBar(const SnackBar(content: Text('Staff access only')));
  }
  return ok;
}

GoRouter buildRouter() {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, __) => const _BootstrapPage()),
      GoRoute(path: '/signin', builder: (_, __) => const SignInPage()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterPage()),
      GoRoute(path: '/magic-link', builder: (_, __) => const MagicLinkPage()),
      GoRoute(
        path: '/onboarding',
        builder: (_, __) =>
            const SupabaseShopSelectionPage(), // ✅ NEW Supabase flow
      ),
      GoRoute(
        path: '/onboarding-legacy',
        builder: (_, __) =>
            const ShopDiscoveryPage(), // Keep old flow for reference
      ),
      GoRoute(
        path: routeContinueAs,
        builder: (_, __) => const ContinueAsPage(),
      ),
      GoRoute(
        path: '/auth/admin-login',
        builder: (_, __) => const LoginAdminPage(),
      ),
      GoRoute(path: '/login-admin', builder: (_, __) => const LoginAdminPage()),
      GoRoute(
        path: '/auth/staff-login',
        builder: (_, __) => const LoginStaffPage(),
      ),
      GoRoute(path: '/login-staff', builder: (_, __) => const LoginStaffPage()),
      GoRoute(
        path: '/staff/change-pin',
        builder: (context, state) {
          final userId = state.extra as String;
          return ChangePinPage(userId: userId);
        },
      ),
      GoRoute(
        path: '/staff/change-pin-logged-in',
        builder: (context, state) => const ChangePinLoggedInPage(),
      ),
      GoRoute(path: routeShopSetup, builder: (_, __) => const ShopSetupPage()),
      GoRoute(path: routeShopJoin, builder: (_, __) => const ShopJoinPage()),
      GoRoute(
        path: routeOwnerHome,
        builder: (_, __) => const AdminDashboardPage(),
      ),
      GoRoute(path: routeStaffHome, builder: (_, __) => const StaffHomePage()),
      GoRoute(path: '/sales', builder: (_, __) => const SalesDashboardPage()),
      GoRoute(
        path: '/inventory',
        builder: (context, state) {
          final readOnly = state.uri.queryParameters['readOnly'] == 'true';
          return InventoryPageSupabase(readOnly: readOnly);
        },
      ),
      GoRoute(
        path: '/inventory/low-stock',
        builder: (context, state) {
          final readOnly = state.uri.queryParameters['readOnly'] == 'true';
          return LowStockPageSupabase(readOnly: readOnly);
        },
      ),
      GoRoute(
        path: '/sale/new',
        builder: (_, __) => const NewSalePageSupabase(),
      ),
      GoRoute(path: '/qudris', builder: (_, __) => const QudrisAiPage()),
      GoRoute(
        path: '/sales/history',
        builder: (context, state) {
          // Use Supabase sales history page instead of local one
          return const SalesHistoryPageSupabase();
        },
      ),
      GoRoute(path: '/sync', builder: (_, __) => const SyncPage()),
      GoRoute(path: '/staff', builder: (_, __) => const StaffManagePage()),
      // Supabase-based staff management (new)
      GoRoute(
        path: '/settings/staff',
        builder: (_, __) => const SupabaseStaffManagementPage(),
      ),
      GoRoute(
        path: '/reports',
        builder: (_, __) => const ReportsPageSupabase(),
      ),
      // Settings routes
      GoRoute(path: '/settings', builder: (_, __) => const OwnerSettingsPage()),
      GoRoute(
        path: '/settings/currency',
        builder: (_, __) => const CurrencySettingsPage(),
      ),
      GoRoute(
        path: '/settings/license',
        builder: (_, __) => const eula.EulaPage(),
      ),
      GoRoute(
        path: '/staff/settings',
        builder: (_, __) => const StaffSettingsPage(),
      ),
    ],
  );
}

/// Bootstrap page that checks for session and routes accordingly
class _BootstrapPage extends ConsumerStatefulWidget {
  const _BootstrapPage();

  @override
  ConsumerState<_BootstrapPage> createState() => _BootstrapPageState();
}

class _BootstrapPageState extends ConsumerState<_BootstrapPage> {
  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<String> _decideStartRoute() async {
    // ✅ Check Supabase auth instead of old Google session
    final isAuthenticated = SupabaseService.isAuthenticated;
    final user = SupabaseService.currentUser;

    print('DEBUG: Supabase auth check: $isAuthenticated');
    print('DEBUG: Current user: ${user?.email}');

    if (!isAuthenticated) {
      print('DEBUG: No Supabase session, routing to signin');
      return '/signin';
    }

    print('DEBUG: User authenticated with Supabase: ${user?.email}');

    // Always route to shop selection page for authenticated users
    // This allows users to switch shops easily
    print('DEBUG: Routing authenticated user to shop selection page');
    return '/onboarding';
  }

  Future<void> _checkSession() async {
    final startRoute = await _decideStartRoute();

    if (mounted) {
      context.go(startRoute);
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
