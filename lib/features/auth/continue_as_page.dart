import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/theme.dart';
import '../../common/session.dart';

/// Page for choosing between Admin and Staff login
class ContinueAsPage extends ConsumerStatefulWidget {
  const ContinueAsPage({super.key});

  @override
  ConsumerState<ContinueAsPage> createState() => _ContinueAsPageState();
}

class _ContinueAsPageState extends ConsumerState<ContinueAsPage> {
  final SessionManager _sessionManager = SessionManager();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkShopSetup();
  }

  Future<void> _checkShopSetup() async {
    try {
      final shopId = await _sessionManager.getString('shop_id');
      if (shopId == null) {
        // No shop ID, redirect to shop discovery
        print(
          'DEBUG: ContinueAsPage - no shop ID found, redirecting to shop discovery',
        );
        if (mounted) {
          context.go('/onboarding');
        }
        return;
      }

      print('DEBUG: ContinueAsPage - checking shop setup for shop: $shopId');

      // Note: With Supabase, user roles are stored in the 'staff' table in Supabase,
      // not in the local database. The local UserDao is for the old Google Drive system.
      // For now, we'll skip the user check and allow the user to proceed.
      // The actual authentication will happen when they select Admin or Staff login.

      print('DEBUG: ContinueAsPage - using Supabase auth, skipping Drive sync');

      // Everything is set up, show the continue-as options
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Error checking shop setup: $e');
      // Show continue-as page anyway
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _roleCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppTheme.gold,
                    child: Icon(icon, color: AppTheme.gray900),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Choose your role')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 24),
        children: [
          _roleCard(
            icon: Icons.admin_panel_settings,
            title: 'Admin',
            subtitle: 'Manage inventory, prices, staff and sync',
            onTap: () => context.go('/auth/admin-login'),
          ),
          _roleCard(
            icon: Icons.badge,
            title: 'Staff',
            subtitle: 'Record sales and view stock levels',
            onTap: () => context.go('/auth/staff-login'),
          ),
          const SizedBox(height: 24),
          Center(
            child: TextButton.icon(
              onPressed: () => _handleSignOut(context),
              icon: const Icon(Icons.logout),
              label: const Text('Sign Out'),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSignOut(BuildContext context) async {
    final sessionManager = SessionManager();
    await sessionManager.clearAuthSession();

    if (context.mounted) {
      context.go('/signin');
    }
  }
}
