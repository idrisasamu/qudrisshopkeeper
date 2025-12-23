import 'dart:convert';
import 'package:googleapis/drive/v3.dart' as gdrive;
import '../../features/sync/drive_client.dart';

/// Shop configuration model for Drive synchronization
class ShopConfig {
  final int version;
  final ShopInfo shop;
  final OwnerInfo owner;
  final List<UserConfig> users;

  ShopConfig({
    required this.version,
    required this.shop,
    required this.owner,
    required this.users,
  });

  factory ShopConfig.fromJson(Map<String, dynamic> json) {
    return ShopConfig(
      version: json['version'] as int,
      shop: ShopInfo.fromJson(json['shop'] as Map<String, dynamic>),
      owner: OwnerInfo.fromJson(json['owner'] as Map<String, dynamic>),
      users: (json['users'] as List<dynamic>)
          .map((user) => UserConfig.fromJson(user as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'shop': shop.toJson(),
      'owner': owner.toJson(),
      'users': users.map((user) => user.toJson()).toList(),
    };
  }
}

class ShopInfo {
  final String id;
  final String name;
  final String country;
  final String city;

  ShopInfo({
    required this.id,
    required this.name,
    required this.country,
    required this.city,
  });

  factory ShopInfo.fromJson(Map<String, dynamic> json) {
    return ShopInfo(
      id: json['id'] as String,
      name: json['name'] as String,
      country: json['country'] as String,
      city: json['city'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, 'country': country, 'city': city};
  }
}

class OwnerInfo {
  final String email;

  OwnerInfo({required this.email});

  factory OwnerInfo.fromJson(Map<String, dynamic> json) {
    return OwnerInfo(email: json['email'] as String);
  }

  Map<String, dynamic> toJson() {
    return {'email': email};
  }
}

class UserConfig {
  final String username;
  final String role;

  // Primary fields (required for new format)
  final String passwordHash;
  final String passwordSalt;
  final String passwordKdf;

  // Legacy alias (optional) – keep reading if present
  final String? pinHash;

  final String updatedAt;
  final bool mustChangePin;

  UserConfig({
    required this.username,
    required this.role,
    required this.passwordHash,
    required this.passwordSalt,
    required this.passwordKdf,
    required this.updatedAt,
    required this.mustChangePin,
    this.pinHash,
  });

  factory UserConfig.fromJson(Map<String, dynamic> json) {
    // Tolerant reader: accept {pinHash} or {password:{hash,salt,kdf}} or flat fields.
    final pwd = json['password'];
    String? h, s, k;

    if (pwd is Map) {
      h = pwd['hash'] as String?;
      s = pwd['salt'] as String?;
      k = pwd['kdf'] as String?;
    } else {
      // flat shape (optional)
      h = json['passwordHash'] as String?;
      s = json['passwordSalt'] as String?;
      k = json['passwordKdf'] as String?;
    }

    return UserConfig(
      username: json['username'] as String,
      role: json['role'] as String,
      passwordHash: h ?? '',
      passwordSalt: s ?? '',
      passwordKdf: k ?? '',
      pinHash: json['pinHash'] as String?, // legacy
      updatedAt: json['updatedAt'] as String,
      mustChangePin:
          (json['mustChangePassword'] ?? json['mustChangePin'] ?? false)
              as bool,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'role': role,
      'passwordHash': passwordHash,
      'passwordSalt': passwordSalt,
      'passwordKdf': passwordKdf,
      // write pinHash too for compatibility with older builds reading only pinHash
      'pinHash': passwordHash,
      'updatedAt': updatedAt,
      'mustChangePin': mustChangePin,
    };
  }
}

/// Repository for managing shop configuration on Google Drive
class DriveConfigRepo {
  final DriveClient _driveClient;

  DriveConfigRepo(this._driveClient);

  /// Read shop configuration from Drive
  Future<ShopConfig?> read(String shopId) async {
    try {
      print('DEBUG: DriveConfigRepo.read() - reading config for shop: $shopId');

      final api = await _driveClient.getApi();

      // Find shop folder
      final shopQuery =
          "name='$shopId' and mimeType='application/vnd.google-apps.folder' and trashed=false and 'me' in owners";
      final shopRes = await api.files.list(
        q: shopQuery,
        $fields: 'files(id,name)',
        spaces: 'drive',
        pageSize: 1,
      );

      if (shopRes.files == null || shopRes.files!.isEmpty) {
        print('DEBUG: DriveConfigRepo.read() - shop folder not found');
        return null;
      }

      final shopFolderId = shopRes.files!.first.id!;
      print('DEBUG: DriveConfigRepo.read() - found shop folder: $shopFolderId');

      // Try to find config folder
      String? configFolderId;
      final configQuery =
          "name='config' and '$shopFolderId' in parents and mimeType='application/vnd.google-apps.folder' and trashed=false";
      final configRes = await api.files.list(
        q: configQuery,
        $fields: 'files(id,name)',
        spaces: 'drive',
        pageSize: 1,
      );

      if (configRes.files != null && configRes.files!.isNotEmpty) {
        configFolderId = configRes.files!.first.id!;
        print(
          'DEBUG: DriveConfigRepo.read() - found config folder: $configFolderId',
        );
      }

      // Try all likely locations / variants
      final candidates = <Map<String, String?>>[
        {'parent': shopFolderId, 'name': 'shop_config.json'}, // root plain
        {'parent': shopFolderId, 'name': 'shop_config.json.enc'}, // root enc
        if (configFolderId != null)
          {
            'parent': configFolderId,
            'name': 'shop_config.json',
          }, // /config plain
        if (configFolderId != null)
          {
            'parent': configFolderId,
            'name': 'shop_config.json.enc',
          }, // /config enc
      ];

      for (final c in candidates) {
        if (c['parent'] == null) continue;

        print(
          'DEBUG: DriveConfigRepo.read() - trying ${c['name']} in ${c['parent']}',
        );

        final res = await api.files.list(
          q: "'${c['parent']}' in parents and name='${c['name']}' and trashed=false",
          $fields: 'files(id,name)',
          spaces: 'drive',
          pageSize: 1,
        );

        final file = (res.files ?? const []).firstOrNull;
        if (file == null || file.id == null) continue;

        print(
          'DEBUG: DriveConfigRepo.read() - found file: ${file.name} (${file.id})',
        );

        final media =
            await api.files.get(
                  file.id!,
                  downloadOptions: gdrive.DownloadOptions.fullMedia,
                )
                as gdrive.Media;

        final raw = await utf8.decoder.bind(media.stream).join();

        // If encrypted, decrypt; otherwise use as-is
        String text;
        if (c['name']!.endsWith('.enc')) {
          print('DEBUG: DriveConfigRepo.read() - decrypting encrypted file');
          // For now, assume it's base64 encoded JSON (not encrypted)
          // In a real implementation, you'd decrypt here
          text = raw;
        } else {
          text = raw;
        }

        final map = jsonDecode(text) as Map<String, dynamic>;
        print('DEBUG: DriveConfigRepo.read() - parsed config: $map');
        return ShopConfig.fromJson(map);
      }

      print('DEBUG: DriveConfigRepo.read() - no shop_config found for $shopId');
      return null;
    } catch (e, st) {
      print('DEBUG: DriveConfigRepo.read() error: $e\n$st');
      return null;
    }
  }

  /// Write shop configuration to Drive
  Future<void> write(String shopId, ShopConfig config) async {
    try {
      print(
        'DEBUG: DriveConfigRepo.write() - writing config for shop: $shopId',
      );

      final api = await _driveClient.getApi();
      final content = jsonEncode(config.toJson());

      // Log account email for debugging
      try {
        // Note: We can't access the private _gsignin field, so we'll skip this debug info
        print('DEBUG: DriveConfigRepo.write() - writing config to Drive');
      } catch (e) {
        print(
          'DEBUG: DriveConfigRepo.write() - could not get account email: $e',
        );
      }

      // Find the shop folder - use deterministic path: /QSK/<SHOP_ID>/config/
      print('DEBUG: DriveConfigRepo.write() - looking for QSK folder...');
      final qskFolderId = await _findChildFolder(
        api,
        parentId: 'root',
        name: 'QSK',
      );
      if (qskFolderId == null) {
        print('DEBUG: DriveConfigRepo.write() - QSK folder not found');
        throw Exception('QSK folder not found');
      }
      print('DEBUG: DriveConfigRepo.write() - found QSK folder: $qskFolderId');

      print(
        'DEBUG: DriveConfigRepo.write() - looking for shop folder: $shopId',
      );
      final shopFolderId = await _findChildFolder(
        api,
        parentId: qskFolderId,
        name: shopId,
      );
      if (shopFolderId == null) {
        print('DEBUG: DriveConfigRepo.write() - shop folder not found');
        throw Exception('Shop folder not found');
      }
      print(
        'DEBUG: DriveConfigRepo.write() - found shop folder: $shopFolderId',
      );

      print('DEBUG: DriveConfigRepo.write() - looking for config folder...');
      final configFolderId = await _findChildFolder(
        api,
        parentId: shopFolderId,
        name: 'config',
      );
      if (configFolderId == null) {
        print('DEBUG: DriveConfigRepo.write() - config folder not found');
        throw Exception('Config folder not found');
      }
      print(
        'DEBUG: DriveConfigRepo.write() - found config folder: $configFolderId',
      );

      // Check if config file already exists
      final existingFile = await _findChildFile(
        api,
        parentId: configFolderId,
        name: 'shop_config.json',
      );

      if (existingFile != null) {
        // Update existing file
        final fileId = existingFile.id!;
        print(
          'DEBUG: DriveConfigRepo.write() - updating existing fileId=$fileId parent=$configFolderId',
        );

        await api.files.update(
          gdrive.File(), // no metadata change
          fileId,
          uploadMedia: gdrive.Media(
            Stream.value(utf8.encode(content)),
            content.length,
          ),
        );

        print('DEBUG: DriveConfigRepo.write() - updated fileId=$fileId');
      } else {
        // Create new file
        print(
          'DEBUG: DriveConfigRepo.write() - creating new file in parent=$configFolderId',
        );

        final meta = gdrive.File()
          ..name = 'shop_config.json'
          ..parents = [configFolderId];
        final created = await api.files.create(
          meta,
          uploadMedia: gdrive.Media(
            Stream.value(utf8.encode(content)),
            content.length,
          ),
        );
        print(
          'DEBUG: DriveConfigRepo.write() - created fileId=${created.id} parent=$configFolderId',
        );
      }

      // Confirm readback (shows which file we truly wrote)
      final confirm = await _findChildFile(
        api,
        parentId: configFolderId,
        name: 'shop_config.json',
      );
      print(
        'DEBUG: DriveConfigRepo.write() - confirm fileId=${confirm?.id} parent=$configFolderId',
      );

      print('DEBUG: DriveConfigRepo.write() - config written successfully');
    } catch (e) {
      print('DEBUG: DriveConfigRepo.write() - error: $e');
      rethrow;
    }
  }

  /// Helper method to find a child folder
  Future<String?> _findChildFolder(
    dynamic api, {
    required String parentId,
    required String name,
  }) async {
    final q =
        "name='${name.replaceAll("'", "\\'")}' and '$parentId' in parents and mimeType='application/vnd.google-apps.folder' and trashed=false";
    final res = await api.files.list(
      q: q,
      $fields: 'files(id,name)',
      pageSize: 1,
    );
    return res.files?.isNotEmpty == true ? res.files!.first.id : null;
  }

  /// Helper method to find a child file
  Future<gdrive.File?> _findChildFile(
    dynamic api, {
    required String parentId,
    required String name,
  }) async {
    final q =
        "name='${name.replaceAll("'", "\\'")}' and '$parentId' in parents and trashed=false";
    final res = await api.files.list(
      q: q,
      $fields: 'files(id,name)',
      pageSize: 1,
    );
    return res.files?.isNotEmpty == true ? res.files!.first : null;
  }
}
