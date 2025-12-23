import 'dart:convert';
import 'package:googleapis/drive/v3.dart' as gdrive;
import '../../features/sync/drive_client.dart';

/// Service for discovering existing shops and data on Google Drive
class DriveDiscovery {
  final DriveClient _driveClient;

  DriveDiscovery(this._driveClient);

  /// Check if the current account has an existing shop on Drive
  /// This provides self-healing for the shop_provisioned flag
  Future<bool> hasShopForCurrentAccount() async {
    try {
      print(
        'DEBUG: DriveDiscovery.hasShopForCurrentAccount() - starting search...',
      );
      final api = await _driveClient.getApi();
      print(
        'DEBUG: DriveDiscovery.hasShopForCurrentAccount() - got API client',
      );

      // Look for shop.json files that indicate an existing shop
      final query = "name='shop.json' and trashed=false and 'me' in owners";
      print('DEBUG: DriveDiscovery.hasShopForCurrentAccount() - query: $query');

      final res = await api.files.list(
        q: query,
        $fields: 'files(id,name,parents)',
        spaces: 'drive',
        pageSize: 10,
      );

      final hasShop = (res.files?.isNotEmpty ?? false);
      print(
        'DEBUG: DriveDiscovery.hasShopForCurrentAccount() - found ${res.files?.length ?? 0} shop.json files',
      );

      if (res.files?.isNotEmpty == true) {
        for (final file in res.files!) {
          print('DEBUG: Found shop.json file: ${file.name} (id: ${file.id})');
        }
      }

      return hasShop;
    } catch (e) {
      print('DEBUG: DriveDiscovery.hasShopForCurrentAccount() - error: $e');
      return false;
    }
  }

  /// Check if there's a QSK root folder for the current account
  Future<bool> hasQskRootFolder() async {
    try {
      final api = await _driveClient.getApi();

      // Look for QSK root folder
      final res = await api.files.list(
        q: "name='QSK' and mimeType='application/vnd.google-apps.folder' and trashed=false and 'me' in owners",
        $fields: 'files(id,name)',
        spaces: 'drive',
        pageSize: 1,
      );

      final hasQskRoot = (res.files?.isNotEmpty ?? false);
      print(
        'DEBUG: DriveDiscovery.hasQskRootFolder() - found QSK root: $hasQskRoot',
      );

      return hasQskRoot;
    } catch (e) {
      print('DEBUG: DriveDiscovery.hasQskRootFolder() - error: $e');
      return false;
    }
  }

  /// Get the QSK root folder ID if it exists
  Future<String?> getQskRootFolderId() async {
    try {
      final api = await _driveClient.getApi();

      final res = await api.files.list(
        q: "name='QSK' and mimeType='application/vnd.google-apps.folder' and trashed=false and 'me' in owners",
        $fields: 'files(id,name)',
        spaces: 'drive',
        pageSize: 1,
      );

      if (res.files?.isNotEmpty ?? false) {
        final folderId = res.files!.first.id;
        print(
          'DEBUG: DriveDiscovery.getQskRootFolderId() - found QSK root: $folderId',
        );
        return folderId;
      }

      return null;
    } catch (e) {
      print('DEBUG: DriveDiscovery.getQskRootFolderId() - error: $e');
      return null;
    }
  }

  /// List all shop folders under QSK root
  Future<List<gdrive.File>> listShopFolders() async {
    try {
      final qskRootId = await getQskRootFolderId();
      if (qskRootId == null) return [];

      final api = await _driveClient.getApi();
      final res = await api.files.list(
        q: "'$qskRootId' in parents and mimeType='application/vnd.google-apps.folder' and trashed=false",
        $fields: 'files(id,name,modifiedTime)',
        spaces: 'drive',
        pageSize: 100,
        orderBy: 'name',
      );

      return res.files ?? [];
    } catch (e) {
      print('DEBUG: DriveDiscovery.listShopFolders() - error: $e');
      return [];
    }
  }

  /// Find the user's shop by searching for shop.json files
  /// This is the primary method for shop discovery on fresh devices
  Future<ShopInfo?> findMyShop() async {
    try {
      print('DEBUG: DriveDiscovery.findMyShop() - starting search...');
      final api = await _driveClient.getApi();
      print('DEBUG: DriveDiscovery.findMyShop() - got API client');

      // Verify we have Drive scope before making API calls
      final hasDriveScope = await _driveClient.hasDriveScope();
      if (!hasDriveScope) {
        print(
          'DEBUG: DriveDiscovery.findMyShop() - missing Drive scope, cannot search',
        );
        return null;
      }
      print('DEBUG: DriveDiscovery.findMyShop() - Drive scope verified');

      // Look for shop.json files that indicate an existing shop
      final query = "name='shop.json' and trashed=false and 'me' in owners";
      print('DEBUG: DriveDiscovery.findMyShop() - query: $query');

      final res = await api.files.list(
        q: query,
        $fields: 'files(id,name,parents)',
        spaces: 'drive',
        pageSize: 10,
      );

      print(
        'DEBUG: DriveDiscovery.findMyShop() - found ${res.files?.length ?? 0} shop.json files',
      );

      if (res.files == null || res.files!.isEmpty) {
        print('DEBUG: DriveDiscovery.findMyShop() - no shop.json files found');
        return null;
      }

      // Load the first shop.json file content
      final fileId = res.files!.first.id!;
      print(
        'DEBUG: DriveDiscovery.findMyShop() - loading shop.json content from file: $fileId',
      );

      // Get file content using the correct API method
      final media =
          await api.files.get(
                fileId,
                downloadOptions: gdrive.DownloadOptions.fullMedia,
              )
              as gdrive.Media;
      final content = await utf8.decoder.bind(media.stream).join();
      final json = jsonDecode(content);

      print('DEBUG: DriveDiscovery.findMyShop() - parsed shop.json: $json');

      return ShopInfo(
        id: json['shopId'] as String,
        name: json['shopName'] as String,
        ownerEmail: json['ownerEmail'] as String,
        createdAt: json['createdAt'] as String?,
        version: json['version'] as String?,
      );
    } catch (e) {
      print('DEBUG: DriveDiscovery.findMyShop() - error: $e');
      return null;
    }
  }
}

/// Shop information extracted from shop.json
class ShopInfo {
  final String id;
  final String name;
  final String ownerEmail;
  final String? createdAt;
  final String? version;

  ShopInfo({
    required this.id,
    required this.name,
    required this.ownerEmail,
    this.createdAt,
    this.version,
  });
}
