import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as gdrive;
import '../../features/sync/drive_client.dart';
import '../../features/sync/drive_discovery.dart';

/// Repository for Drive operations including shop management
class DriveRepository {
  final DriveClient driveClient;
  final DriveDiscovery discovery;
  final GoogleSignIn signIn;

  DriveRepository({
    required this.driveClient,
    required this.discovery,
    required this.signIn,
  });

  /// Factory constructor to create DriveRepository with GoogleSignIn
  factory DriveRepository.create(GoogleSignIn signIn) {
    final driveClient = DriveClient(signIn);
    final discovery = DriveDiscovery(driveClient, signIn);
    return DriveRepository(
      driveClient: driveClient,
      discovery: discovery,
      signIn: signIn,
    );
  }

  /// Delete a shop from Drive (soft delete to trash)
  Future<void> deleteShop(String shopId) async {
    print('DEBUG: DriveRepository - Starting deletion of shop: $shopId');

    try {
      // Find the shop folder
      final folderId = await discovery.findShopFolderId(shopId);

      if (folderId != null) {
        print(
          'DEBUG: DriveRepository - Found shop folder: $folderId, moving to trash',
        );

        // Soft delete by moving to trash
        final api = await driveClient.getApi();
        await api.files.update(gdrive.File()..trashed = true, folderId);

        print(
          'DEBUG: DriveRepository - Successfully moved shop folder to trash: $folderId',
        );
      } else {
        print('DEBUG: DriveRepository - No shop folder found for: $shopId');
      }

      // Also try to find and delete shop.json files
      await _deleteShopJsonFiles(shopId);
    } catch (e) {
      print('ERROR: DriveRepository - Failed to delete shop $shopId: $e');
      rethrow;
    }
  }

  /// Delete shop.json files for a specific shop
  Future<void> _deleteShopJsonFiles(String shopId) async {
    try {
      final api = await driveClient.getApi();

      // Find shop.json files that might contain this shopId
      // Use 'allDrives' corpora to include files shared with the user
      final res = await api.files.list(
        q: "name = 'shop.json' and trashed = false and ('me' in readers or 'me' in owners)",
        spaces: 'drive',
        corpora: 'allDrives',
        includeItemsFromAllDrives: true,
        supportsAllDrives: true,
        $fields: 'files(id,name,parents)',
        pageSize: 100,
      );

      for (final file in res.files ?? const []) {
        try {
          // Download and check if this shop.json contains our shopId
          final content = await driveClient.downloadString(file.id!);
          if (content.contains('"shopId":"$shopId"')) {
            print(
              'DEBUG: DriveRepository - Found shop.json for shop $shopId, moving to trash',
            );
            await api.files.update(gdrive.File()..trashed = true, file.id!);
            print(
              'DEBUG: DriveRepository - Successfully moved shop.json to trash',
            );
          }
        } catch (e) {
          print(
            'DEBUG: DriveRepository - Error processing shop.json ${file.id}: $e',
          );
        }
      }
    } catch (e) {
      print('DEBUG: DriveRepository - Error deleting shop.json files: $e');
    }
  }

  /// List all shops for the current user (excluding trashed)
  Future<List<DiscoveredShop>> listOwnerShops() async {
    return await discovery.listShopsForUser();
  }

  /// Clear any cached data for a specific shop
  Future<void> clearShopCache(String shopId) async {
    // For now, just log - could implement actual cache clearing if needed
    print('DEBUG: DriveRepository - Clearing cache for shop: $shopId');
  }
}
