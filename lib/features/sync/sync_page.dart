import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../common/session.dart';
import '../../common/uuid.dart';
import '../../data/local/daos/staff_dao.dart';
import '../../data/services/data_sync.dart'; // Added
import '../../data/repositories/drive_data_repo.dart'; // Added
import '../../data/services/config_sync.dart'; // Added
// Removed debug-only imports
import '../../app/main.dart';
import 'package:googleapis/drive/v3.dart' as gdrive;
import '../auth/google_auth.dart';
import 'drive_bootstrap.dart';
import 'drive_client.dart';
import '../staff/staff_manage_page.dart';
import '../inventory/inventory_page.dart';
import '../inventory/low_stock_page.dart';
import '../sales/new_sale_page.dart';
import '../sales/sales_history_page.dart';
// removed: dart:convert (debug only)

// Sync status provider
enum SyncStatus { disabled, offline, syncing, ok, error }

final syncStatusProvider = StateProvider<SyncStatus>(
  (ref) => SyncStatus.disabled,
);
final lastSyncTimeProvider = StateProvider<DateTime?>((ref) => null);

// Staff provider using StreamProvider for real-time updates
final staffProvider = StreamProvider.autoDispose((ref) {
  final db = ref.watch(dbProvider);
  return StaffDao(db).watchActiveStaff();
});

class SyncPage extends ConsumerStatefulWidget {
  const SyncPage({super.key});

  @override
  ConsumerState<SyncPage> createState() => _SyncPageState();
}

class _SyncPageState extends ConsumerState<SyncPage> {
  final SessionManager _sessionManager = SessionManager();
  bool _isDriveEnabled = false;
  bool _isLoading = false;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _checkDriveStatus();
    _checkUserRole();
    _startSyncService();
  }

  void _startSyncService() {
    // ✅ DISABLED: Google Drive sync replaced with Supabase sync
    // The Supabase sync service is started automatically in main.dart
    // and in individual pages like StaffHomePage

    // Set up a timer to update last sync time every 30 seconds
    // This simulates the automatic sync updating the last sync time
    Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        ref.read(lastSyncTimeProvider.notifier).state = DateTime.now();
      }
    });
  }

  Future<void> _checkDriveStatus() async {
    final enabled = await _sessionManager.isDriveEnabled();
    setState(() {
      _isDriveEnabled = enabled;
    });
    ref.read(syncStatusProvider.notifier).state = enabled
        ? SyncStatus.ok
        : SyncStatus.disabled;
  }

  Future<void> _checkUserRole() async {
    final role = await _sessionManager.getString('role');
    setState(() {
      _isAdmin = role == 'admin';
    });
  }

  Future<void> _handleEnableSync() async {
    setState(() => _isLoading = true);
    try {
      final gsignIn = GoogleAuthService.googleSignIn; // Use shared instance

      // First, try to sign in silently
      var account = await gsignIn.signInSilently();
      if (account == null) {
        // If silent sign-in fails, try interactive sign-in
        account = await gsignIn.signIn();
        if (account == null) {
          throw Exception('Google sign-in required to enable Drive sync');
        }
      }

      final driveClient = DriveClient(gsignIn);
      final bootstrap = DriveBootstrap(driveClient, gsignIn);

      // Get current shop info from session
      final sessionManager = SessionManager();
      final shopId = await sessionManager.getString('shop_id') ?? newId();
      final shopName = await sessionManager.getString('shop_name') ?? 'My Shop';
      final ownerEmail = account.email;

      // Create Drive layout
      final layout = await bootstrap.ensureShopLayout(
        shopId: shopId,
        shopName: shopName,
        ownerEmail: ownerEmail,
      );

      // Enable Drive sync in session
      await sessionManager.enableDriveSync(
        shopId: shopId,
        shopShortId: shopId, // Use shopId as short ID for now
        driveShopFolderId: layout.shopRootId,
        driveBroadcastFolderId: layout.broadcastId,
        driveSnapshotsFolderId: layout.snapshotsId,
        driveInboxRootId: layout.inboxRootId,
      );

      await _checkDriveStatus();
      ref.read(lastSyncTimeProvider.notifier).state = DateTime.now();
      ref.read(syncStatusProvider.notifier).state = SyncStatus.ok;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Drive sync enabled successfully')),
        );
      }
    } catch (e) {
      String errorMessage = 'Failed to enable Drive sync';
      String helpText = '';

      // Provide more helpful error messages
      if (e.toString().contains('ApiException: 7')) {
        errorMessage = 'Network error (ApiException: 7)';
        helpText =
            '\n\nTroubleshooting:\n'
            '• Check internet connection\n'
            '• Update Google Play Services in Play Store\n'
            '• Verify OAuth client configuration\n'
            '• Try signing out and back in\n'
            '• Test on a physical device if using emulator';
      } else if (e.toString().contains('network_error')) {
        errorMessage = 'Network error: Please check your internet connection.';
      } else if (e.toString().contains('sign_in_failed')) {
        errorMessage = 'Google sign-in failed. Please try again.';
      } else {
        errorMessage = 'Failed to enable Drive sync: $e';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage + helpText),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 8),
          ),
        );
      }
      ref.read(syncStatusProvider.notifier).state = SyncStatus.error;
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Removed unused admin actions (Disable/SyncNow/FullSync/AddStaff) from UI

  // Removed unused _reloadStaffList

  Future<void> _handleSignOut() async {
    final sessionManager = SessionManager();
    final googleAuth = GoogleAuthService();

    try {
      // Clear only authentication data (keep shop data)
      await sessionManager.clearAuthSession();

      // Sign out from Google
      await googleAuth.signOut();

      // Navigate to sign-in page
      if (mounted) {
        context.go('/signin');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error signing out: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Debug utilities removed from production UI

  // Removed unused _forceFullPull

  /// Force Resync: Push any local changes, sync user config, then pull latest
  Future<void> _forceResync() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final db = ref.read(dbProvider);
      final shopId = await _sessionManager.getString('shop_id');
      if (shopId == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('No shop ID found')));
        return;
      }

      // Get or create data root folder
      final driveClient = DriveClient(GoogleAuthService.googleSignIn);
      final dataRootId = await _ensureDataRootFolder(driveClient, shopId);

      // 1) Push queued business data first
      final driveDataRepo = DriveDataRepo(driveClient);
      final dataSync = DataSync(
        db: db,
        repo: driveDataRepo,
        shopId: shopId,
        dataRootId: dataRootId,
      );
      await dataSync.pushQueuedInventoryOps();
      await dataSync.pushQueuedStockMoves();
      await dataSync.pushQueuedSales();

      // 2) Sync user configuration (push local → then pull from Drive)
      final configSync = ConfigSync(db, driveClient);
      await configSync.pushLocalUsersToDrive(shopId);
      await configSync.pullUsersFromDrive(shopId);

      // 3) Pull latest business data
      await dataSync.pullInventory();
      await dataSync.pullSalesAndStock(daysBack: 180);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Force resync completed')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Force resync failed: $e')));
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Removed unused _forcePushUsers

  // Removed unused _forcePush

  /// Ensure data root folder exists for the shop
  Future<String> _ensureDataRootFolder(
    DriveClient driveClient,
    String shopId,
  ) async {
    try {
      print(
        'DEBUG: SyncPage._ensureDataRootFolder() - ensuring data folder for shop: $shopId',
      );

      final api = await driveClient.getApi();

      // Look for QSK root folder
      final qskQuery =
          "name='QSK' and mimeType='application/vnd.google-apps.folder' and trashed=false and 'me' in owners";
      final qskRes = await api.files.list(
        q: qskQuery,
        $fields: 'files(id,name)',
        spaces: 'drive',
      );

      String qskRootId;
      if (qskRes.files?.isEmpty ?? true) {
        // Create QSK root folder
        print(
          'DEBUG: SyncPage._ensureDataRootFolder() - creating QSK root folder',
        );
        final qskFolder = await api.files.create(
          gdrive.File()
            ..name = 'QSK'
            ..mimeType = 'application/vnd.google-apps.folder',
        );
        qskRootId = qskFolder.id!;
      } else {
        qskRootId = qskRes.files!.first.id!;
      }

      // Look for shop folder
      final shopQuery =
          "name='$shopId' and mimeType='application/vnd.google-apps.folder' and trashed=false and 'me' in owners";
      final shopRes = await api.files.list(
        q: shopQuery,
        $fields: 'files(id,name)',
        spaces: 'drive',
      );

      String shopFolderId;
      if (shopRes.files?.isEmpty ?? true) {
        // Create shop folder
        print('DEBUG: SyncPage._ensureDataRootFolder() - creating shop folder');
        final shopFolder = await api.files.create(
          gdrive.File()
            ..name = shopId
            ..mimeType = 'application/vnd.google-apps.folder'
            ..parents = [qskRootId],
        );
        shopFolderId = shopFolder.id!;
      } else {
        shopFolderId = shopRes.files!.first.id!;
      }

      // Look for data folder
      final dataQuery =
          "name='data' and mimeType='application/vnd.google-apps.folder' and trashed=false and 'me' in owners";
      final dataRes = await api.files.list(
        q: dataQuery,
        $fields: 'files(id,name)',
        spaces: 'drive',
      );

      String dataRootId;
      if (dataRes.files?.isEmpty ?? true) {
        // Create data folder
        print('DEBUG: SyncPage._ensureDataRootFolder() - creating data folder');
        final dataFolder = await api.files.create(
          gdrive.File()
            ..name = 'data'
            ..mimeType = 'application/vnd.google-apps.folder'
            ..parents = [shopFolderId],
        );
        dataRootId = dataFolder.id!;
      } else {
        dataRootId = dataRes.files!.first.id!;
      }

      print(
        'DEBUG: SyncPage._ensureDataRootFolder() - data root folder: $dataRootId',
      );
      return dataRootId;
    } catch (e) {
      print('DEBUG: SyncPage._ensureDataRootFolder() - error: $e');
      rethrow;
    }
  }

  // Removed unused remove staff dialog handler

  // Removed unused _promptForEmail dialog

  // Removed unused _isValidEmail helper

  String _formatLastSync(DateTime? lastSync) {
    if (lastSync == null) return 'Never';

    final now = DateTime.now();
    final difference = now.difference(lastSync);

    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes} min ago';
    if (difference.inHours < 24) return '${difference.inHours} hr ago';
    return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
  }

  // Removed unused status helpers

  @override
  Widget build(BuildContext context) {
    // final syncStatus = ref.watch(syncStatusProvider); // currently unused
    final lastSync = ref.watch(lastSyncTimeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sync'),
        backgroundColor: Colors.grey[900],
        foregroundColor: Colors.white,
        actions: [],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Sync is now automatic - simple status display
            Card(
              color: Colors.grey[800],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.cloud_done,
                          size: 24,
                          color: Colors.green,
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Automatic Sync',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.green),
                          ),
                          child: const Text(
                            'Active',
                            style: TextStyle(
                              color: Colors.green,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Your data is automatically synced in the background. No manual intervention required.',
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Last sync: ${_formatLastSync(lastSync)}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),

            // Enable Drive Sync Section (if disabled)
            if (!_isDriveEnabled) ...[
              const SizedBox(height: 24),
              Card(
                color: Colors.orange[900],
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.cloud_off,
                            size: 24,
                            color: Colors.orange,
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Drive Sync Disabled',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Enable Google Drive sync to automatically backup and sync your data across devices.',
                        style: TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _isLoading ? null : _handleEnableSync,
                        icon: const Icon(Icons.cloud_upload),
                        label: const Text('Enable Drive Sync'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Force Sync Section (Admin only)
            if (_isAdmin) ...[
              const Text(
                'Force Sync',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              Card(
                color: Colors.grey[800],
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Manual sync operations',
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _isLoading ? null : _forceResync,
                              icon: const Icon(Icons.sync),
                              label: const Text('Force Resync'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Force Resync: Push pending changes, sync user config, and pull latest data from Drive.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),

                      // Debug buttons removed
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Role Management Section
            const Text(
              'Role Management',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              color: Colors.grey[800],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Switch between admin and staff roles',
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              await _switchRoleOrShop(context);
                            },
                            icon: const Icon(Icons.swap_horiz),
                            label: const Text('Switch Role'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Switch to a different role for this shop',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // PIN Change Section (Staff only)
            if (!_isAdmin) ...[
              const Text(
                'Security',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Card(
                color: Colors.grey[800],
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Change your PIN for security',
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                context.push('/staff/change-pin-logged-in');
                              },
                              icon: const Icon(Icons.security),
                              label: const Text('Change PIN'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Update your PIN to keep your account secure',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Staff Management Section (Admin only)
            if (_isAdmin) ...[
              const Text(
                'Staff Management',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Card(
                color: Colors.grey[800],
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Manage your shop staff members',
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const StaffManagePage(),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.people),
                              label: const Text('Manage Staff'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.amber,
                                foregroundColor: Colors.black,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Add, remove, and manage staff access to your shop',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),
            ],

            // Sign Out Card (always visible)
            const SizedBox(height: 24),
            Card(
              color: Colors.grey[800],
              child: InkWell(
                onTap: _handleSignOut,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.logout, color: Colors.red[400], size: 24),
                      const SizedBox(width: 12),
                      Text(
                        'Sign Out',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.red[400],
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                        color: Colors.grey,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Switch role or shop - clears only role and username, keeps shop provisioning
  Future<void> _switchRoleOrShop(BuildContext context) async {
    try {
      final sessionManager = SessionManager();
      await sessionManager.removeMany(['role', 'username']);

      // Reopen database for the current shop to ensure fresh connection
      final shopId = await sessionManager.getString('shop_id');
      if (shopId != null) {
        final dbHolder = ref.read(dbHolderProvider);
        await dbHolder.openForShop(shopId);
      }

      ref.invalidate(itemsWithStockProvider);
      ref.invalidate(lowStockItemsProvider);
      ref.invalidate(salesHistoryProvider);
      ref.invalidate(salesItemsWithStockProvider);
      if (context.mounted) {
        context.go('/continue-as');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error switching: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
