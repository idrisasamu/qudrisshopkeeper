import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../common/session.dart';
import '../../services/supabase_client.dart';

/// Owner settings page with various configuration options
class OwnerSettingsPage extends ConsumerWidget {
  const OwnerSettingsPage({super.key});

  Future<void> _signOut(BuildContext context) async {
    try {
      // Clear session data
      final sessionManager = SessionManager();
      await sessionManager.clearSession();

      // Sign out from Supabase
      await SupabaseService.signOut();

      // Navigate to sign in page
      if (context.mounted) {
        context.go('/signin');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error signing out: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings'), elevation: 0),
      body: ListView(
        children: [
          // Shop Settings Section
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Shop Settings',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          ListTile(
            leading: const Text(
              '₦',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            title: const Text('Currency'),
            subtitle: const Text('Set your shop currency'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/currency'),
          ),
          const Divider(),

          // Staff Management Section
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Staff Management',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.people),
            title: const Text('Manage Staff'),
            subtitle: const Text('Add and manage staff members'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/staff'),
          ),
          const Divider(),

          // Account Section
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Account',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.swap_horiz),
            title: const Text('Switch Shop'),
            subtitle: const Text('Change to a different shop'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/onboarding'),
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Sign Out'),
            subtitle: const Text('Sign out of your account'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _signOut(context),
          ),
          const Divider(),

          // About Section
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'About',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('License Agreement'),
            subtitle: const Text('View End User License Agreement'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/license'),
          ),
        ],
      ),
    );
  }
}
