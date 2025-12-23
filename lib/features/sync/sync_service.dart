import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/main.dart';
import '../../common/session.dart';
import '../auth/google_auth.dart';
import 'drive_client.dart';
import 'drive_sync_service.dart';
import '../../data/repositories/sync_ops_repo.dart';
import '../../data/services/data_sync.dart'; // Added
import '../../data/repositories/drive_data_repo.dart'; // Added
import '../../data/services/config_sync.dart'; // Added
import '../../data/local/app_database.dart';
import '../../data/local/daos/user_dao.dart'; // Added for session guard
import 'package:googleapis/drive/v3.dart' as gdrive; // Added

/// Sync service provider
final syncServiceProvider = Provider<SyncService>((ref) {
  final db = ref.watch(dbProvider);
  // Use the same GoogleSignIn instance as GoogleAuthService
  final googleSignIn = GoogleAuthService.googleSignIn;
  final driveClient = DriveClient(googleSignIn);

  return SyncService(
    db: db,
    drive: DriveSyncService(db, googleSignIn, driveClient),
    isAdmin: false, // Will be determined dynamically in syncNow()
    email: 'unknown@example.com', // Will be determined dynamically in syncNow()
  );
});

/// Sync service for Drive operations
class SyncService {
  final AppDatabase db;
  final DriveSyncService drive;
  final bool isAdmin;
  final String email;
  Timer? _timer;

  SyncService({
    required this.db,
    required this.drive,
    required this.isAdmin,
    required this.email,
  });

  void start() {
    // ✅ DISABLED: Google Drive sync replaced with Supabase sync
    print(
      'DEBUG: SyncService.start() - Google Drive sync DISABLED, using Supabase instead',
    );
    // _timer?.cancel();
    // print('DEBUG: SyncService.start() called - starting sync timer');
    // // Real-time sync every 30 seconds
    // _timer = Timer.periodic(const Duration(seconds: 30), (_) => syncNow());
    // // also call on foreground/resume if you have lifecycle hooks
  }

  Future<void> syncNow() async {
    try {
      // Get current session info dynamically
      final sessionManager = SessionManager();
      final role = await sessionManager.getString('role') ?? 'staff';
      final userEmail =
          await sessionManager.getString('google_email') ??
          'unknown@example.com';
      final isAdminRole = role == 'admin' || role == 'owner';
      final shopId = await sessionManager.getString('shop_id');

      print(
        'DEBUG: SyncService - Role: $role, Email: $userEmail, IsAdmin: $isAdminRole, ShopId: $shopId',
      );

      if (shopId == null) {
        print('DEBUG: SyncService - No shop ID found, skipping sync');
        return;
      }

      // Sync user configuration
      await drive.syncNow(isAdmin: isAdminRole, myEmail: userEmail);

      // Sync users (pull from Drive to get latest staff changes)
      await _syncUsers(shopId);

      // Sync business data
      await _syncBusinessData(shopId);

      // Update last sync time on successful sync
      print('DEBUG: Sync completed successfully, updating last sync time');
    } catch (e) {
      print('Sync failed: $e');
    }
  }

  Future<void> rotateShopKey() async {
    await drive.rotateShopKey();
  }

  /// Sync users from Drive (pull latest staff changes)
  Future<void> _syncUsers(String shopId) async {
    try {
      final driveClient = DriveClient(GoogleAuthService.googleSignIn);
      final configSync = ConfigSync(db, driveClient);

      // Always pull to learn about other devices' changes
      await configSync.pullUsersFromDrive(shopId);

      // Check if current staff user still exists after pull
      await _checkCurrentUserStillExists(shopId);

      print('DEBUG: SyncService._syncUsers() - completed successfully');
    } catch (e) {
      print('DEBUG: SyncService._syncUsers() - error: $e');
    }
  }

  /// Check if current staff user still exists, sign out if not
  Future<void> _checkCurrentUserStillExists(String shopId) async {
    try {
      final sessionManager = SessionManager();
      final role = await sessionManager.getString('role');
      final username = await sessionManager.getString('username');

      if (role == 'staff' && username != null) {
        final userDao = UserDao(db);
        final stillExists = await userDao.exists(
          shopId: shopId,
          username: username,
        );

        if (!stillExists) {
          print(
            'DEBUG: SyncService - staff user $username no longer exists, signing out',
          );
          // Clear session and sign out
          await sessionManager.removeMany(['role', 'username']);
          // Note: We can't show UI here as this runs in background
          // The user will be redirected on next navigation
        }
      }
    } catch (e) {
      print('DEBUG: SyncService._checkCurrentUserStillExists() - error: $e');
    }
  }

  /// Sync business data (inventory, stock, sales) to Drive
  Future<void> _syncBusinessData(String shopId) async {
    try {
      print(
        'DEBUG: SyncService._syncBusinessData() - starting for shop: $shopId',
      );

      final driveClient = DriveClient(GoogleAuthService.googleSignIn);
      final driveDataRepo = DriveDataRepo(driveClient);

      // Get or create data root folder
      final dataRootId = await _ensureDataRootFolder(driveClient, shopId);

      final dataSync = DataSync(
        db: db,
        repo: driveDataRepo,
        shopId: shopId,
        dataRootId: dataRootId,
      );

      // Push queued operations to Drive
      await dataSync.pushQueuedInventoryOps();
      await dataSync.pushQueuedStockMoves();
      await dataSync.pushQueuedSales();

      // Pull latest data from Drive (inventory, stock, sales)
      await dataSync.pullInventory();
      await dataSync.pullSalesAndStock(daysBack: 90);

      print('DEBUG: SyncService._syncBusinessData() - completed successfully');
    } catch (e) {
      print('DEBUG: SyncService._syncBusinessData() - error: $e');
    }
  }

  /// Ensure data root folder exists for the shop
  Future<String> _ensureDataRootFolder(
    DriveClient driveClient,
    String shopId,
  ) async {
    try {
      print(
        'DEBUG: SyncService._ensureDataRootFolder() - ensuring data folder for shop: $shopId',
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
          'DEBUG: SyncService._ensureDataRootFolder() - creating QSK root folder',
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
        print(
          'DEBUG: SyncService._ensureDataRootFolder() - creating shop folder',
        );
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
        print(
          'DEBUG: SyncService._ensureDataRootFolder() - creating data folder',
        );
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
        'DEBUG: SyncService._ensureDataRootFolder() - data root folder: $dataRootId',
      );
      return dataRootId;
    } catch (e) {
      print('DEBUG: SyncService._ensureDataRootFolder() - error: $e');
      rethrow;
    }
  }

  /// Trigger a full sync of all existing data for the current shop
  /// This is useful when a user logs in on a new device
  Future<void> syncAllExistingData() async {
    try {
      final sessionManager = SessionManager();
      final shopId = await sessionManager.getString('shop_id');

      if (shopId == null) {
        print('DEBUG: No shop ID found, cannot sync existing data');
        return;
      }

      print('DEBUG: Starting full sync of existing data for shop: $shopId');

      // Get the sync repository
      final syncRepo = SyncOpsRepo(db);

      // Sync all existing data
      await syncRepo.syncAllExistingData(shopId);

      // Now trigger a regular sync to push all the operations
      await syncNow();

      print('DEBUG: Completed full sync of existing data');
    } catch (e) {
      print('Full sync failed: $e');
    }
  }

  void dispose() => _timer?.cancel();
}
