import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../common/session.dart';
import '../../data/local/app_database.dart';
import '../../data/local/daos/user_dao.dart';
import '../../data/services/config_sync.dart';
import '../sync/drive_client.dart';
import '../../app/main.dart';
import 'staff_service.dart';

/// Staff management page for admins
class StaffManagePage extends ConsumerStatefulWidget {
  const StaffManagePage({super.key});

  @override
  ConsumerState<StaffManagePage> createState() => _StaffManagePageState();
}

class _StaffManagePageState extends ConsumerState<StaffManagePage> {
  late final UserDao _userDao;
  final SessionManager _sessionManager = SessionManager();
  late final DriveClient _driveClient;
  late final ConfigSync _configSync;
  late final StaffService _staffService;

  List<User> _staff = [];
  bool _isLoading = true;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    final db = ref.read(dbProvider);
    _userDao = UserDao(db);
    _driveClient = DriveClient.defaultConstructor();
    _configSync = ConfigSync(db, _driveClient);
    _staffService = StaffService(db: db, session: _sessionManager);
    _initializeStaff();
  }

  Future<void> _initializeStaff() async {
    // First pull latest users from Drive
    final shopId = await _sessionManager.getString('shop_id');
    if (shopId != null) {
      try {
        await _configSync.pullUsersFromDrive(shopId);
        print('DEBUG: StaffManagePage - pulled users from Drive');
      } catch (e) {
        print('DEBUG: StaffManagePage - error pulling users: $e');
      }
    }

    // Then load staff from local DB
    await _loadStaff();
  }

  Future<void> _loadStaff() async {
    print('DEBUG: StaffManagePage._loadStaff() - starting...');
    setState(() {
      _isLoading = true;
    });

    try {
      final shopId = await _sessionManager.getString('shop_id');
      print('DEBUG: StaffManagePage._loadStaff() - shopId: $shopId');
      if (shopId != null) {
        final staff = await _userDao.getAllActiveStaff(shopId);
        print(
          'DEBUG: StaffManagePage._loadStaff() - found ${staff.length} staff members',
        );
        for (final s in staff) {
          print(
            'DEBUG: StaffManagePage._loadStaff() - staff: ${s.username} (${s.role})',
          );
        }
        setState(() {
          _staff = staff;
          _isLoading = false;
        });
        print(
          'DEBUG: StaffManagePage._loadStaff() - UI updated with ${_staff.length} staff',
        );
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('DEBUG: StaffManagePage._loadStaff() - error: $e');
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading staff: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _syncStaffConfig() async {
    setState(() {
      _isSyncing = true;
    });

    try {
      final shopId = await _sessionManager.getString('shop_id');
      if (shopId != null) {
        await _configSync.pushLocalUsersToDrive(shopId);
      }
      await _loadStaff();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Staff configuration synced successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error syncing staff: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isSyncing = false;
      });
    }
  }

  Future<void> _addStaff() async {
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(builder: (context) => const AddStaffDialog()),
    );

    if (result != null) {
      try {
        await _staffService.addStaff(
          username: result['username'],
          pin: '0000', // Default PIN for new staff
          role: 'staff',
        );
        await _loadStaff();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Staff created with default PIN 0000. They must change it on first login.',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error adding staff: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _deactivateStaff(User user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Staff'),
        content: Text(
          'Are you sure you want to remove ${user.username}? '
          'This will remove them from all devices and they will no longer be able to log in.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Show immediate feedback
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Removing staff...'),
              backgroundColor: Colors.orange,
            ),
          );
        }

        await _staffService.deactivateStaff(user.username);
        await _loadStaff();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Staff removed. Syncing to all devices...'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error removing staff: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff Management'),
        actions: [
          IconButton(
            onPressed: _isSyncing ? null : _syncStaffConfig,
            icon: _isSyncing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync),
            tooltip: 'Sync Staff Configuration',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Staff Members (${_staff.length})',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _addStaff,
                        icon: const Icon(Icons.add),
                        label: const Text('Add Staff'),
                      ),
                    ],
                  ),
                ),

                // Staff list
                Expanded(
                  child: _staff.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.people, size: 64, color: Colors.grey),
                              SizedBox(height: 16),
                              Text(
                                'No staff members yet',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Add your first staff member to get started',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: _staff.length,
                          itemBuilder: (context, index) {
                            final user = _staff[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 4,
                              ),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.green,
                                  child: Text(user.username[0].toUpperCase()),
                                ),
                                title: Text(user.username),
                                subtitle: Text('Role: ${user.role}'),
                                trailing: PopupMenuButton(
                                  itemBuilder: (context) => [
                                    PopupMenuItem(
                                      value: 'deactivate',
                                      child: const Row(
                                        children: [
                                          Icon(
                                            Icons.person_off,
                                            color: Colors.orange,
                                          ),
                                          SizedBox(width: 8),
                                          Text('Deactivate'),
                                        ],
                                      ),
                                    ),
                                  ],
                                  onSelected: (value) {
                                    if (value == 'deactivate') {
                                      _deactivateStaff(user);
                                    }
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}

/// Dialog for adding new staff members
class AddStaffDialog extends StatefulWidget {
  const AddStaffDialog({super.key});

  @override
  State<AddStaffDialog> createState() => _AddStaffDialogState();
}

class _AddStaffDialogState extends State<AddStaffDialog> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Staff Member'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: 'Username',
                prefixIcon: Icon(Icons.person),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a username';
                }
                if (value.trim().length < 3) {
                  return 'Username must be at least 3 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            const Card(
              color: Colors.blue,
              child: Padding(
                padding: EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    Icon(Icons.info, color: Colors.white),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'New staff will be created with default PIN 0000. They must change it on first login.',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.of(
                context,
              ).pop({'username': _usernameController.text.trim()});
            }
          },
          child: const Text('Add Staff'),
        ),
      ],
    );
  }
}
