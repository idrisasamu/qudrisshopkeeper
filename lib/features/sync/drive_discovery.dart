import 'dart:convert';
import 'package:google_sign_in/google_sign_in.dart';
import 'drive_client.dart';

class DiscoveredShop {
  final String shopId;
  final String shopName;
  final String shopRootId;
  DiscoveredShop(this.shopId, this.shopName, this.shopRootId);
}

class DriveDiscovery {
  final DriveClient drive;
  final GoogleSignIn signIn;
  DriveDiscovery(this.drive, this.signIn);

  /// Find a specific shop folder by shopId
  Future<String?> findShopFolderId(String shopId) async {
    final api = await drive.getApi();

    print('DEBUG: DriveDiscovery - Looking for shop folder: $shopId');

    // Query for folder with specific shopId name that's not trashed
    // Use 'allDrives' corpora to include folders shared with the user
    final res = await api.files.list(
      q: "mimeType = 'application/vnd.google-apps.folder' and name = '$shopId' and trashed = false",
      spaces: 'drive',
      corpora: 'allDrives',
      includeItemsFromAllDrives: true,
      supportsAllDrives: true,
      $fields: 'files(id,name,parents)',
      pageSize: 10,
    );

    if (res.files?.isNotEmpty ?? false) {
      final folderId = res.files!.first.id!;
      print(
        'DEBUG: DriveDiscovery - Found shop folder: $folderId for shop: $shopId',
      );
      return folderId;
    }

    print('DEBUG: DriveDiscovery - No shop folder found for: $shopId');
    return null;
  }

  /// Finds all /QSK/<SHOP_ID>/shop.json files visible to this user.
  Future<List<DiscoveredShop>> listShopsForUser() async {
    final api = await drive.getApi();

    print('DEBUG: DriveDiscovery - Querying for shop.json files');

    // Search shop.json files that are owned by or shared with the user
    // Use 'allDrives' corpora to include files shared with the user
    final res = await api.files.list(
      q: "name = 'shop.json' and trashed = false and ('me' in readers or 'me' in owners or 'me' in writers)",
      spaces: 'drive',
      corpora: 'allDrives',
      includeItemsFromAllDrives: true,
      supportsAllDrives: true,
      $fields: 'files(id,name,parents,modifiedTime,shared)',
      pageSize: 100,
    );

    print(
      'DEBUG: DriveDiscovery - Found ${res.files?.length ?? 0} shop.json files',
    );

    final List<DiscoveredShop> out = [];
    for (final f in res.files ?? const []) {
      try {
        final text = await drive.downloadString(f.id!);
        final obj = jsonDecode(text) as Map<String, dynamic>;
        final shopId = obj['shopId'] as String;
        final shopName = obj['shopName'] as String? ?? shopId;
        // parent is /QSK/<SHOP_ID>
        final parentId = (f.parents?.isNotEmpty ?? false)
            ? f.parents!.first
            : '';
        if (parentId.isEmpty) {
          print(
            'DEBUG: DriveDiscovery - Skipping shop.json with no parent folder',
          );
          continue;
        }

        print('DEBUG: DriveDiscovery - Found shop: $shopName ($shopId)');
        out.add(DiscoveredShop(shopId, shopName, parentId));
      } catch (e) {
        print('DEBUG: DriveDiscovery - Error processing shop.json ${f.id}: $e');
      }
    }

    print('DEBUG: DriveDiscovery - Returning ${out.length} shops');
    return out;
  }
}
