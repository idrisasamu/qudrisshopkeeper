import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/start_page.dart';
import '../features/dashboard/admin_dashboard_page.dart';
import '../features/dashboard/sales_dashboard_page.dart';
import '../features/inventory/inventory_page.dart';
import '../features/sales/new_sale_page.dart';
import '../features/users/users_page.dart';
import '../features/users/invite_qr_page.dart';
import '../features/users/invite.dart';
import '../features/sync/sync_page.dart';
import '../features/sync/email_config_page.dart';

GoRouter buildRouter() {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, __) => const StartPage()),
      GoRoute(path: '/admin', builder: (_, __) => const AdminDashboardPage()),
      GoRoute(path: '/sales', builder: (_, __) => const SalesDashboardPage()),
      GoRoute(path: '/inventory', builder: (_, __) => const InventoryPage()),
      GoRoute(path: '/sale/new', builder: (_, __) => const NewSalePage()),
      GoRoute(path: '/users', builder: (_, __) => const UsersPage()),
      GoRoute(path: '/sync', builder: (_, __) => const SyncPage()),
      GoRoute(path: '/sync/email', builder: (_, __) => const EmailConfigPage()),
      GoRoute(
        path: '/invite',
        builder: (ctx, state) {
          final extra = state.extra as Map<String, Object?>?;
          final payload = extra?['payload'] as InvitePayload;
          final pass = extra?['pass'] as String;
          return InviteQrPage(payload: payload, oneTimePassphrase: pass);
        },
      ),
    ],
  );
}
