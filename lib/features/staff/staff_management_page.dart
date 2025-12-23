import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../app/main.dart';
import '../../common/session.dart';
import '../../data/local/daos/staff_dao.dart';
import '../../data/local/app_database.dart';
import '../sync/drive_bootstrap.dart';
import '../sync/drive_client.dart';

class StaffManagementPage extends ConsumerStatefulWidget {
  const StaffManagementPage({super.key});

  @override
  ConsumerState<StaffManagementPage> createState() =>
      _StaffManagementPageState();
}

class _StaffManagementPageState extends ConsumerState<StaffManagementPage> {
  final _emailController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _addStaff() async {
    final email = _emailController.text.trim();
    final name = _nameController.text.trim();

    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter an email address'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid email address'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final sessionManager = SessionManager();
      final shopId = await sessionManager.getString('shop_id');

      if (shopId == null) {
        throw Exception('No shop ID found. Please enable Drive sync first.');
      }

      // Add staff to database
      final db = ref.read(dbProvider);
      final staffDao = StaffDao(db);
      await staffDao.upsertStaff(
        email: email,
        shopId: shopId,
        role: 'sales',
        displayName: name.isNotEmpty ? name : email.split('@')[0],
      );

      // Share shop with staff via Drive
      await _shareShopWithStaff(email);

      // Clear form
      _emailController.clear();
      _nameController.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Staff member $email added successfully!\nIt may take up to 2 minutes for Google Drive permissions to propagate and the shop to appear on their device.',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 8),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add staff: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _shareShopWithStaff(String staffEmail) async {
    try {
      final gsignIn = GoogleSignIn(
        scopes: const [
          'email',
          'profile',
          'https://www.googleapis.com/auth/drive.file',
        ],
      );

      final account = await gsignIn.signInSilently();
      if (account == null) {
        throw Exception('Google sign-in required to share shop');
      }

      final driveClient = DriveClient(gsignIn);
      final bootstrap = DriveBootstrap(driveClient, gsignIn);

      // Get current Drive folder IDs from session
      final sessionManager = SessionManager();
      final shopRootId = await sessionManager.getString('drive_shop_folder_id');
      final broadcastId = await sessionManager.getString(
        'drive_broadcast_folder_id',
      );
      final snapshotsId = await sessionManager.getString(
        'drive_snapshots_folder_id',
      );
      final inboxRootId = await sessionManager.getString('drive_inbox_root_id');

      if (shopRootId == null ||
          broadcastId == null ||
          snapshotsId == null ||
          inboxRootId == null) {
        throw Exception(
          'Drive sync not properly configured. Please re-enable Drive sync.',
        );
      }

      final layout = ShopDriveLayout(
        shopRootId: shopRootId,
        broadcastId: broadcastId,
        snapshotsId: snapshotsId,
        inboxRootId: inboxRootId,
      );

      await bootstrap.shareShopWithStaff(
        layout: layout,
        staffEmail: staffEmail,
      );

      print('DEBUG: Successfully shared shop with $staffEmail');
    } catch (e) {
      print('ERROR: Failed to share shop with staff: $e');
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Staff'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {});
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Add Staff Member',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email Address',
                hintText: 'staff@example.com',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Display Name (Optional)',
                hintText: 'John Doe',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _addStaff,
                child: _isLoading
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 8),
                          Text('Adding Staff...'),
                        ],
                      )
                    : const Text('Add Staff Member'),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Current Staff',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Expanded(child: _buildStaffList()),
          ],
        ),
      ),
    );
  }

  Widget _buildStaffList() {
    return FutureBuilder<List<User>>(
      future: _getStaffList(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error loading staff: ${snapshot.error}'));
        }

        final staff = snapshot.data ?? [];

        if (staff.isEmpty) {
          return const Center(
            child: Text(
              'No staff members yet.\nAdd staff members to share your shop.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          );
        }

        return ListView.builder(
          itemCount: staff.length,
          itemBuilder: (context, index) {
            final member = staff[index];
            return Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.blue,
                  child: Text(
                    member.name.isNotEmpty
                        ? member.name[0].toUpperCase()
                        : member.email[0].toUpperCase(),
                  ),
                ),
                title: Text(
                  member.name.isNotEmpty ? member.name : member.email,
                ),
                subtitle: Text(member.email),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) async {
                    if (value == 'remove') {
                      await _removeStaff(member.email);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'remove',
                      child: Row(
                        children: [
                          Icon(Icons.remove_circle, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Remove'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<List<User>> _getStaffList() async {
    final db = ref.read(dbProvider);
    final staffDao = StaffDao(db);
    return await staffDao.getActiveStaff();
  }

  Future<void> _removeStaff(String email) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Staff Member'),
        content: Text('Are you sure you want to remove $email?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final db = ref.read(dbProvider);
        final staffDao = StaffDao(db);
        await staffDao.deactivateStaff(email);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Staff member $email removed'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to remove staff: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}
