import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../features/auth/google_auth.dart';

/// Session management for persisting admin authentication
class SessionManager {
  static const _storage = FlutterSecureStorage();

  // Keys for storing session data
  static const String _googleEmailKey = 'google_email';
  static const String _googleDisplayNameKey = 'google_display_name';
  static const String _googleIdKey = 'google_id';
  static const String _roleKey = 'role';
  static const String _authProviderKey = 'auth_provider';
  static const String _avatarUrlKey = 'avatar_url';

  // Drive sync keys
  static const String _driveEnabledKey = 'drive_enabled';
  static const String _shopIdKey = 'shop_id';
  static const String _shopNameKey = 'shop_name';
  static const String _shopShortIdKey = 'shop_short_id';
  static const String _driveShopFolderIdKey = 'drive_shop_folder_id';
  static const String _driveBroadcastFolderIdKey = 'drive_broadcast_folder_id';
  static const String _driveSnapshotsFolderIdKey = 'drive_snapshots_folder_id';
  static const String _driveInboxRootIdKey = 'drive_inbox_root_id';
  static const String _driveInboxMyIdKey = 'drive_inbox_my_id';

  // Shop provisioning
  static const String _shopProvisionedKey = 'shop_provisioned';

  /// Save Google session data to secure storage (without role - user chooses later)
  Future<void> saveAdminSession(GoogleUser user) async {
    try {
      print('DEBUG: Saving Google session for: ${user.email}');
      await Future.wait([
        _storage.write(key: _googleEmailKey, value: user.email),
        _storage.write(key: _googleDisplayNameKey, value: user.displayName),
        _storage.write(key: _googleIdKey, value: user.id),
        // Don't set role here - user will choose owner/staff later
        _storage.write(key: _authProviderKey, value: 'google'),
        _storage.write(key: _avatarUrlKey, value: user.photoUrl),
      ]);
      print('DEBUG: Google session saved successfully');
    } catch (e) {
      print('Error saving admin session: $e');
    }
  }

  /// Clear all session data
  Future<void> clearSession() async {
    try {
      await _storage.deleteAll();
      print('Session cleared successfully');
    } catch (e) {
      print('Error clearing session: $e');
    }
  }

  /// Clear only authentication data (keep shop data)
  Future<void> clearAuthSession() async {
    try {
      await Future.wait([
        _storage.delete(key: _googleEmailKey),
        _storage.delete(key: _googleDisplayNameKey),
        _storage.delete(key: _googleIdKey),
        _storage.delete(key: _authProviderKey),
        _storage.delete(key: _avatarUrlKey),
        _storage.delete(key: _roleKey),
        // Keep shop data: shop_id, shop_name, drive settings
      ]);
      print('Authentication session cleared successfully');
    } catch (e) {
      print('Error clearing authentication session: $e');
    }
  }

  /// Sign out everywhere - clears all session data including shop provisioning
  Future<void> signOutEverywhere() async {
    try {
      await _storage.deleteAll();
      print('All session data cleared - signed out everywhere');
    } catch (e) {
      print('Error signing out everywhere: $e');
    }
  }

  /// Clear shop provisioning (for shop deletion or complete reset)
  /// This should only be called when the user explicitly deletes their shop
  Future<void> clearShopProvisioning() async {
    try {
      await _storage.delete(key: _shopProvisionedKey);
      print('Shop provisioning cleared');
    } catch (e) {
      print('Error clearing shop provisioning: $e');
    }
  }

  /// Clear only role and shop data (keep Google session and shop provisioning)
  /// NOTE: This does NOT clear shop_provisioned - that should only be cleared on sign out
  Future<void> clearRoleData() async {
    try {
      await Future.wait([
        _storage.delete(key: _roleKey),
        _storage.delete(key: _shopIdKey),
        _storage.delete(key: _shopShortIdKey),
        _storage.delete(key: _shopNameKey),
        // DO NOT clear shop_provisioned - keep it for existing shops
      ]);
      print('Role and shop data cleared successfully');
    } catch (e) {
      print('Error clearing role data: $e');
    }
  }

  /// Check if admin session exists (legacy method for backward compatibility)
  Future<bool> hasAdminSession() async {
    try {
      final email = await _storage.read(key: _googleEmailKey);
      final role = await _storage.read(key: _roleKey);
      final provider = await _storage.read(key: _authProviderKey);

      // Check for both legacy 'admin' role and new 'owner' role
      return email != null &&
          (role == 'admin' || role == 'owner') &&
          provider == 'google';
    } catch (e) {
      print('Error checking admin session: $e');
      return false;
    }
  }

  /// Check if user has any valid Google session
  Future<bool> hasGoogleSession() async {
    try {
      final email = await _storage.read(key: _googleEmailKey);
      final provider = await _storage.read(key: _authProviderKey);

      print('DEBUG: hasGoogleSession - email: $email, provider: $provider');
      final result = email != null && provider == 'google';
      print('DEBUG: hasGoogleSession result: $result');
      return result;
    } catch (e) {
      print('Error checking Google session: $e');
      return false;
    }
  }

  /// Get stored admin email
  Future<String?> getAdminEmail() async {
    try {
      return await _storage.read(key: _googleEmailKey);
    } catch (e) {
      print('Error getting admin email: $e');
      return null;
    }
  }

  /// Get stored admin display name
  Future<String?> getAdminDisplayName() async {
    try {
      return await _storage.read(key: _googleDisplayNameKey);
    } catch (e) {
      print('Error getting admin display name: $e');
      return null;
    }
  }

  /// Get stored admin avatar URL
  Future<String?> getAdminAvatarUrl() async {
    try {
      return await _storage.read(key: _avatarUrlKey);
    } catch (e) {
      print('Error getting admin avatar URL: $e');
      return null;
    }
  }

  /// Drive sync management methods

  /// Enable Drive sync and store folder IDs
  Future<void> enableDriveSync({
    required String shopId,
    required String shopShortId,
    required String driveShopFolderId,
    required String driveBroadcastFolderId,
    required String driveSnapshotsFolderId,
    required String driveInboxRootId,
  }) async {
    try {
      await Future.wait([
        _storage.write(key: _driveEnabledKey, value: 'true'),
        _storage.write(key: _shopIdKey, value: shopId),
        _storage.write(key: _shopShortIdKey, value: shopShortId),
        _storage.write(key: _driveShopFolderIdKey, value: driveShopFolderId),
        _storage.write(
          key: _driveBroadcastFolderIdKey,
          value: driveBroadcastFolderId,
        ),
        _storage.write(
          key: _driveSnapshotsFolderIdKey,
          value: driveSnapshotsFolderId,
        ),
        _storage.write(key: _driveInboxRootIdKey, value: driveInboxRootId),
      ]);
    } catch (e) {
      print('Error enabling Drive sync: $e');
    }
  }

  /// Check if Drive sync is enabled
  Future<bool> isDriveEnabled() async {
    try {
      final enabled = await _storage.read(key: _driveEnabledKey);
      return enabled == 'true';
    } catch (e) {
      print('Error checking Drive sync status: $e');
      return false;
    }
  }

  /// Disable Drive sync
  Future<void> disableDriveSync() async {
    try {
      await _storage.write(key: _driveEnabledKey, value: 'false');
    } catch (e) {
      print('Error disabling Drive sync: $e');
    }
  }

  /// Get Drive folder IDs
  Future<Map<String, String?>> getDriveFolderIds() async {
    try {
      final results = await Future.wait([
        _storage.read(key: _shopIdKey),
        _storage.read(key: _shopShortIdKey),
        _storage.read(key: _driveShopFolderIdKey),
        _storage.read(key: _driveBroadcastFolderIdKey),
        _storage.read(key: _driveSnapshotsFolderIdKey),
        _storage.read(key: _driveInboxRootIdKey),
        _storage.read(key: _driveInboxMyIdKey),
      ]);

      return {
        'shopId': results[0],
        'shopShortId': results[1],
        'driveShopFolderId': results[2],
        'driveBroadcastFolderId': results[3],
        'driveSnapshotsFolderId': results[4],
        'driveInboxRootId': results[5],
        'driveInboxMyId': results[6],
      };
    } catch (e) {
      print('Error getting Drive folder IDs: $e');
      return {};
    }
  }

  /// Set personal inbox folder ID (for sales users)
  Future<void> setPersonalInboxId(String inboxId) async {
    try {
      await _storage.write(key: _driveInboxMyIdKey, value: inboxId);
    } catch (e) {
      print('Error setting personal inbox ID: $e');
    }
  }

  /// Get string value by key
  Future<String?> getString(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (e) {
      print('Error getting string value for key $key: $e');
      return null;
    }
  }

  /// Set string value by key
  Future<void> setString(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
    } catch (e) {
      print('Error setting string value for key $key: $e');
    }
  }

  /// Get integer value by key
  Future<int?> getInt(String key) async {
    try {
      final value = await _storage.read(key: key);
      return value != null ? int.tryParse(value) : null;
    } catch (e) {
      print('Error getting int value for key $key: $e');
      return null;
    }
  }

  /// Set integer value by key
  Future<void> setInt(String key, int value) async {
    try {
      await _storage.write(key: key, value: value.toString());
    } catch (e) {
      print('Error setting int value for key $key: $e');
    }
  }

  /// Get boolean value by key
  Future<bool> getBool(String key) async {
    try {
      final value = await _storage.read(key: key);
      return value == 'true';
    } catch (e) {
      print('Error getting bool value for key $key: $e');
      return false;
    }
  }

  /// Set boolean value by key
  Future<void> setBool(String key, bool value) async {
    try {
      await _storage.write(key: key, value: value.toString());
    } catch (e) {
      print('Error setting bool value for key $key: $e');
    }
  }

  /// Check if shop is provisioned
  Future<bool> isShopProvisioned() async {
    return await getBool(_shopProvisionedKey);
  }

  /// Mark shop as provisioned
  Future<void> markShopProvisioned() async {
    await setBool(_shopProvisionedKey, true);
  }

  /// Remove specific session keys (for role switching)
  /// NOTE: This is used for role switching and should NOT include shop_provisioned
  Future<void> removeMany(List<String> keys) async {
    try {
      await Future.wait(keys.map((key) => _storage.delete(key: key)));
      print('Removed session keys: $keys');
    } catch (e) {
      print('Error removing session keys: $e');
    }
  }
}
