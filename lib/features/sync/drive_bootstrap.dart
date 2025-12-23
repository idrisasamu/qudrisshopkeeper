import 'dart:convert';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as gdrive;
import '../../common/session.dart';
import 'drive_client.dart';
import 'crypto_box.dart';

/// Handles the creation and management of the Drive folder structure for shops
class DriveBootstrap {
  final DriveClient driveClient;
  final GoogleSignIn signIn;

  DriveBootstrap(this.driveClient, this.signIn);

  /// Drive API scope for file access
  static const String driveScope = 'https://www.googleapis.com/auth/drive';

  /// Static method to add staff member to Drive
  static Future<void> addStaff({
    required GoogleSignIn gsignIn,
    required String staffEmail,
  }) async {
    // Preconditions: signed in + drive initialized for this shop
    final me = await gsignIn.signInSilently();
    if (me == null) throw Exception('Sign in with Google first.');

    final sessionManager = SessionManager();
    final shopId = await sessionManager.getString('shop_id');
    final shopName = await sessionManager.getString('shop_name');
    final rootId = await sessionManager.getString('drive_shop_folder_id');
    final broadcastId = await sessionManager.getString(
      'drive_broadcast_folder_id',
    );
    final snapshotsId = await sessionManager.getString(
      'drive_snapshots_folder_id',
    );
    final inboxRootId = await sessionManager.getString('drive_inbox_root_id');

    if ([
      shopId,
      shopName,
      rootId,
      broadcastId,
      snapshotsId,
      inboxRootId,
    ].any((v) => v == null)) {
      throw Exception('Enable Drive sync first.');
    }

    final driveClient = DriveClient(gsignIn);
    final api = await driveClient.getApi();

    // 1) Ensure shop.json (discovery file) exists in the shop root (idempotent)
    await _ensureShopMetadataStatic(
      driveClient: driveClient,
      shopRootId: rootId!,
      shopId: shopId!,
      shopName: shopName!,
      ownerEmail: me.email,
    );

    // 2) Share SHOP ROOT so staff can read shop.json (lets discovery work)
    await api.permissions.create(
      gdrive.Permission(type: 'user', role: 'reader', emailAddress: staffEmail),
      rootId,
      sendNotificationEmail: false,
    );

    // 3) Share broadcast + snapshots as READER
    for (final folderId in [broadcastId, snapshotsId]) {
      await api.permissions.create(
        gdrive.Permission(
          type: 'user',
          role: 'reader',
          emailAddress: staffEmail,
        ),
        folderId!,
        sendNotificationEmail: false,
      );
    }

    // 4) Ensure personal inbox for this staff and share as WRITER
    final inboxUserId =
        await driveClient.findChildFolderId(inboxRootId!, staffEmail) ??
        (await driveClient.createFolder(
          staffEmail,
          parentId: inboxRootId!,
        )).id!;
    await api.permissions.create(
      gdrive.Permission(type: 'user', role: 'writer', emailAddress: staffEmail),
      inboxUserId,
      sendNotificationEmail: false,
    );

    print('DEBUG: Successfully added staff $staffEmail to shop $shopName');

    // Update shop.json to include the new staff member
    await _updateShopJsonWithStaff(
      driveClient: driveClient,
      shopRootId: rootId!,
      staffEmail: staffEmail,
      staffRole: 'sales', // Default role for added staff
      action: 'add',
    );
  }

  /// Updates shop.json file when staff members are added or removed
  static Future<void> _updateShopJsonWithStaff({
    required DriveClient driveClient,
    required String shopRootId,
    required String staffEmail,
    required String staffRole,
    required String action, // 'add' or 'remove'
  }) async {
    final api = await driveClient.getApi();

    try {
      // Find the shop.json file
      final existingFiles = await api.files.list(
        q: "name = 'shop.json' and parents in '$shopRootId' and trashed = false",
        $fields: 'files(id,name)',
      );

      if (existingFiles.files?.isEmpty ?? true) {
        print('DEBUG: No shop.json found to update');
        return;
      }

      final fileId = existingFiles.files!.first.id!;

      // Download current content
      final content = await driveClient.downloadString(fileId);
      final shopData = jsonDecode(content) as Map<String, dynamic>;

      // Get current staff members
      List<Map<String, dynamic>> staffMembers = List<Map<String, dynamic>>.from(
        shopData['staffMembers'] ?? [],
      );

      if (action == 'add') {
        // Add or update staff member
        final existingIndex = staffMembers.indexWhere(
          (staff) => staff['email'] == staffEmail,
        );

        final staffMember = {
          'email': staffEmail,
          'role': staffRole,
          'addedAt': DateTime.now().toIso8601String(),
        };

        if (existingIndex >= 0) {
          staffMembers[existingIndex] = staffMember;
        } else {
          staffMembers.add(staffMember);
        }
      } else if (action == 'remove') {
        // Remove staff member
        staffMembers.removeWhere((staff) => staff['email'] == staffEmail);
      }

      // Update shop data
      shopData['staffMembers'] = staffMembers;
      shopData['updatedAt'] = DateTime.now().toIso8601String();

      // Upload updated content
      final updatedJson = jsonEncode(shopData);
      await api.files.update(
        gdrive.File()..name = 'shop.json',
        fileId,
        uploadMedia: gdrive.Media(
          Stream.fromIterable([utf8.encode(updatedJson)]),
          updatedJson.length,
        ),
      );

      print(
        'DEBUG: Updated shop.json with staff $action action for $staffEmail',
      );
    } catch (e) {
      print('ERROR: Failed to update shop.json: $e');
    }
  }

  /// Helper method to ensure shop metadata exists
  static Future<void> _ensureShopMetadataStatic({
    required DriveClient driveClient,
    required String shopRootId,
    required String shopId,
    required String shopName,
    required String ownerEmail,
  }) async {
    final api = await driveClient.getApi();

    // Check if shop.json already exists
    final existingFiles = await api.files.list(
      q: "name = 'shop.json' and parents in '$shopRootId' and trashed = false",
      $fields: 'files(id,name)',
    );

    // Get existing staff members from current shop.json if it exists
    List<Map<String, dynamic>> staffMembers = [];
    if (existingFiles.files?.isNotEmpty == true) {
      try {
        final fileId = existingFiles.files!.first.id!;
        final content = await driveClient.downloadString(fileId);
        final existingData = jsonDecode(content) as Map<String, dynamic>;
        staffMembers = List<Map<String, dynamic>>.from(
          existingData['staffMembers'] ?? [],
        );
      } catch (e) {
        print('DEBUG: Could not read existing shop.json, starting fresh: $e');
      }
    }

    final shopMetadata = {
      'shopId': shopId,
      'shopName': shopName,
      'ownerEmail': ownerEmail,
      'staffMembers': staffMembers,
      'createdAt': DateTime.now().toIso8601String(),
      'version': '1.1', // Increment version to indicate new structure
    };

    final metadataJson = jsonEncode(shopMetadata);

    if (existingFiles.files?.isNotEmpty == true) {
      // Update existing file
      final fileId = existingFiles.files!.first.id!;
      await api.files.update(
        gdrive.File()..name = 'shop.json',
        fileId,
        uploadMedia: gdrive.Media(
          Stream.fromIterable([utf8.encode(metadataJson)]),
          metadataJson.length,
        ),
      );
      print('DEBUG: Updated shop.json for shop $shopId');
    } else {
      // Create new file
      await api.files.create(
        gdrive.File()
          ..name = 'shop.json'
          ..parents = [shopRootId]
          ..mimeType = 'application/json',
        uploadMedia: gdrive.Media(
          Stream.fromIterable([utf8.encode(metadataJson)]),
          metadataJson.length,
        ),
      );
      print('DEBUG: Created shop.json for shop $shopId');
    }
  }

  /// Ensures the complete Drive layout exists for a shop
  /// Creates: /QSK/<SHOP_ID>/shop.json, broadcast/, snapshots/, inbox_sales/
  Future<ShopDriveLayout> ensureShopLayout({
    required String shopId,
    required String shopName,
    required String ownerEmail,
  }) async {
    // Ensure QSK root folder exists
    final qskRootId = await _ensureQskRoot();

    // Create shop folder: /QSK/<SHOP_ID>/
    final shopRootId = await _ensureShopFolder(qskRootId, shopId);

    // Create shop.json metadata file
    await _ensureShopMetadata(shopRootId, shopId, shopName, ownerEmail);

    // Create subfolders
    final broadcastId = await _ensureSubfolder(shopRootId, 'broadcast');
    final snapshotsId = await _ensureSubfolder(shopRootId, 'snapshots');
    final inboxRootId = await _ensureSubfolder(shopRootId, 'inbox_sales');
    final configId = await _ensureSubfolder(shopRootId, 'config');

    // Generate K_shop if not already present
    final sessionManager = SessionManager();
    final existing = await sessionManager.getString('shop_key_b64');
    if (existing == null) {
      final k = CryptoBox.generateShopKey();
      await sessionManager.setString('shop_key_b64', k);
      await sessionManager.setInt('shop_key_version', 1);
    }

    // Store config folder ID for ConfigSync
    await sessionManager.setString('drive_config_folder_id', configId);

    return ShopDriveLayout(
      shopRootId: shopRootId,
      broadcastId: broadcastId,
      snapshotsId: snapshotsId,
      inboxRootId: inboxRootId,
    );
  }

  /// Ensures shop.json metadata file exists
  Future<void> _ensureShopMetadata(
    String shopRootId,
    String shopId,
    String shopName,
    String ownerEmail,
  ) async {
    final api = await driveClient.getApi();

    // Check if shop.json already exists
    final existingFiles = await api.files.list(
      q: "name = 'shop.json' and parents in '$shopRootId' and trashed = false",
      $fields: 'files(id,name)',
    );

    // Get existing staff members from current shop.json if it exists
    List<Map<String, dynamic>> staffMembers = [];
    if (existingFiles.files?.isNotEmpty == true) {
      try {
        final fileId = existingFiles.files!.first.id!;
        final content = await driveClient.downloadString(fileId);
        final existingData = jsonDecode(content) as Map<String, dynamic>;
        staffMembers = List<Map<String, dynamic>>.from(
          existingData['staffMembers'] ?? [],
        );
      } catch (e) {
        print('DEBUG: Could not read existing shop.json, starting fresh: $e');
      }
    }

    final shopMetadata = {
      'shopId': shopId,
      'shopName': shopName,
      'ownerEmail': ownerEmail,
      'staffMembers': staffMembers,
      'createdAt': DateTime.now().toIso8601String(),
      'version': '1.1', // Increment version to indicate new structure
    };

    final metadataJson = jsonEncode(shopMetadata);

    if (existingFiles.files?.isNotEmpty == true) {
      // Update existing file
      final fileId = existingFiles.files!.first.id!;
      await api.files.update(
        gdrive.File()..name = 'shop.json',
        fileId,
        uploadMedia: gdrive.Media(
          Stream.fromIterable([utf8.encode(metadataJson)]),
          metadataJson.length,
        ),
      );
      print('DEBUG: Updated shop.json for shop $shopId');
    } else {
      // Create new file
      await api.files.create(
        gdrive.File()
          ..name = 'shop.json'
          ..parents = [shopRootId]
          ..mimeType = 'application/json',
        uploadMedia: gdrive.Media(
          Stream.fromIterable([utf8.encode(metadataJson)]),
          metadataJson.length,
        ),
      );
      print('DEBUG: Created shop.json for shop $shopId');
    }
  }

  /// Ensures /QSK root folder exists
  Future<String> _ensureQskRoot() async {
    final api = await driveClient.getApi();

    // Check if QSK folder exists
    final existingFolders = await api.files.list(
      q: "name = 'QSK' and mimeType = 'application/vnd.google-apps.folder' and trashed = false",
      $fields: 'files(id,name)',
    );

    if (existingFolders.files?.isNotEmpty == true) {
      return existingFolders.files!.first.id!;
    }

    // Create QSK folder
    final folder = await api.files.create(
      gdrive.File()
        ..name = 'QSK'
        ..mimeType = 'application/vnd.google-apps.folder',
    );

    print('DEBUG: Created QSK root folder');
    return folder.id!;
  }

  /// Ensures shop folder exists: /QSK/<SHOP_ID>/
  Future<String> _ensureShopFolder(String qskRootId, String shopId) async {
    final api = await driveClient.getApi();

    // Check if shop folder exists
    final existingFolders = await api.files.list(
      q: "name = '$shopId' and parents in '$qskRootId' and mimeType = 'application/vnd.google-apps.folder' and trashed = false",
      $fields: 'files(id,name)',
    );

    if (existingFolders.files?.isNotEmpty == true) {
      return existingFolders.files!.first.id!;
    }

    // Create shop folder
    final folder = await api.files.create(
      gdrive.File()
        ..name = shopId
        ..parents = [qskRootId]
        ..mimeType = 'application/vnd.google-apps.folder',
    );

    print('DEBUG: Created shop folder for $shopId');
    return folder.id!;
  }

  /// Ensures a subfolder exists within the shop folder
  Future<String> _ensureSubfolder(String shopRootId, String folderName) async {
    final api = await driveClient.getApi();

    // Check if subfolder exists
    final existingFolders = await api.files.list(
      q: "name = '$folderName' and parents in '$shopRootId' and mimeType = 'application/vnd.google-apps.folder' and trashed = false",
      $fields: 'files(id,name)',
    );

    if (existingFolders.files?.isNotEmpty == true) {
      return existingFolders.files!.first.id!;
    }

    // Create subfolder
    final folder = await api.files.create(
      gdrive.File()
        ..name = folderName
        ..parents = [shopRootId]
        ..mimeType = 'application/vnd.google-apps.folder',
    );

    print('DEBUG: Created $folderName subfolder');
    return folder.id!;
  }

  /// Shares the shop with a staff member
  Future<void> shareShopWithStaff({
    required ShopDriveLayout layout,
    required String staffEmail,
  }) async {
    final api = await driveClient.getApi();

    try {
      // Share shop root (so staff can see shop.json)
      await api.permissions.create(
        gdrive.Permission(
          type: 'user',
          role: 'reader',
          emailAddress: staffEmail,
        ),
        layout.shopRootId,
        sendNotificationEmail: false,
      );

      // Share broadcast folder (read access)
      await api.permissions.create(
        gdrive.Permission(
          type: 'user',
          role: 'reader',
          emailAddress: staffEmail,
        ),
        layout.broadcastId,
        sendNotificationEmail: false,
      );

      // Share snapshots folder (read access)
      await api.permissions.create(
        gdrive.Permission(
          type: 'user',
          role: 'reader',
          emailAddress: staffEmail,
        ),
        layout.snapshotsId,
        sendNotificationEmail: false,
      );

      // Create and share personal inbox folder (write access)
      final personalInboxId = await _ensurePersonalInbox(
        layout.inboxRootId,
        staffEmail,
      );
      await api.permissions.create(
        gdrive.Permission(
          type: 'user',
          role: 'writer',
          emailAddress: staffEmail,
        ),
        personalInboxId,
        sendNotificationEmail: false,
      );

      print('DEBUG: Shared shop with staff member $staffEmail');
    } catch (e) {
      print('ERROR: Failed to share shop with staff: $e');
      rethrow;
    }
  }

  /// Ensures personal inbox folder exists for staff member
  Future<String> _ensurePersonalInbox(
    String inboxRootId,
    String staffEmail,
  ) async {
    final api = await driveClient.getApi();

    // Check if personal inbox exists
    final existingFolders = await api.files.list(
      q: "name = '$staffEmail' and parents in '$inboxRootId' and mimeType = 'application/vnd.google-apps.folder' and trashed = false",
      $fields: 'files(id,name)',
    );

    if (existingFolders.files?.isNotEmpty == true) {
      return existingFolders.files!.first.id!;
    }

    // Create personal inbox folder
    final folder = await api.files.create(
      gdrive.File()
        ..name = staffEmail
        ..parents = [inboxRootId]
        ..mimeType = 'application/vnd.google-apps.folder',
    );

    print('DEBUG: Created personal inbox for $staffEmail');
    return folder.id!;
  }
}

/// Represents the Drive folder structure for a shop
class ShopDriveLayout {
  final String shopRootId;
  final String broadcastId;
  final String snapshotsId;
  final String inboxRootId;

  ShopDriveLayout({
    required this.shopRootId,
    required this.broadcastId,
    required this.snapshotsId,
    required this.inboxRootId,
  });
}
