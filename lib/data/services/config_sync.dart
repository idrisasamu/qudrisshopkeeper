import '../local/app_database.dart';
import '../local/daos/user_dao.dart';
import '../repositories/drive_config_repo.dart';
import '../../features/sync/drive_client.dart';
import '../../features/auth/password_hasher.dart';

/// Service for synchronizing user configuration between local database and Drive
class ConfigSync {
  final AppDatabase _db;
  final DriveClient _driveClient;
  final DriveConfigRepo _configRepo;

  ConfigSync(this._db, this._driveClient)
    : _configRepo = DriveConfigRepo(_driveClient);

  /// Push local users to Drive as shop_config.json
  Future<void> pushLocalUsersToDrive(String shopId) async {
    try {
      print(
        'DEBUG: ConfigSync.pushLocalUsersToDrive() - starting for shop: $shopId',
      );

      final userDao = UserDao(_db);
      // Only push active users to Drive
      final users = await userDao
          .getAllUsers(shopId)
          .then((allUsers) => allUsers.where((user) => user.isActive).toList());

      if (users.isEmpty) {
        print(
          'DEBUG: ConfigSync.pushLocalUsersToDrive() - no active users found, skipping',
        );
        return;
      }

      // Get shop info
      final shops = await (_db.select(
        _db.shops,
      )..where((s) => s.id.equals(shopId))).get();

      if (shops.isEmpty) {
        print(
          'DEBUG: ConfigSync.pushLocalUsersToDrive() - no shop found for ID: $shopId',
        );
        return;
      }

      final shop = shops.first;

      // Build shop config
      final config = ShopConfig(
        version: 1,
        shop: ShopInfo(
          id: shop.id,
          name: shop.name,
          country: shop.country,
          city: shop.city,
        ),
        owner: OwnerInfo(email: shop.email),
        users: users
            .map(
              (u) => UserConfig(
                username: u.username,
                role: u.role,
                // New canonical triplet
                passwordHash: u.passwordHash,
                passwordSalt: u.salt,
                passwordKdf: u.kdf,
                // Legacy (keep for old builds)
                pinHash: u.passwordHash,
                updatedAt: u.updatedAt.toIso8601String(),
                mustChangePin: u.mustChangePassword,
              ),
            )
            .toList(),
      );

      print(
        'DEBUG: ConfigSync.pushLocalUsersToDrive() - built config with ${users.length} users',
      );

      // Log user details for debugging
      for (final user in users) {
        print(
          'DEBUG: ConfigSync.pushLocalUsersToDrive() - user: ${user.username} (${user.role})',
        );
      }

      // Write to Drive
      await _configRepo.write(shopId, config);

      print(
        'DEBUG: ConfigSync.pushLocalUsersToDrive() - completed successfully',
      );
    } catch (e) {
      print('DEBUG: ConfigSync.pushLocalUsersToDrive() - error: $e');
      rethrow;
    }
  }

  /// Pull users from Drive and seed local database
  Future<void> pullUsersFromDrive(String shopId) async {
    try {
      print(
        'DEBUG: ConfigSync.pullUsersFromDrive() - starting for shop: $shopId',
      );

      final config = await _configRepo.read(shopId);
      if (config == null) {
        print(
          'DEBUG: ConfigSync.pullUsersFromDrive() - no config found on Drive',
        );
        return;
      }

      print(
        'DEBUG: ConfigSync.pullUsersFromDrive() - found config with ${config.users.length} users',
      );

      final userDao = UserDao(_db);

      // Get usernames present in Drive config
      final usernamesInCfg = <String>{for (final u in config.users) u.username};
      print(
        'DEBUG: ConfigSync.pullUsersFromDrive() - present usernames=${usernamesInCfg.toList()}',
      );

      await _db.transaction(() async {
        // Upsert each user from Drive config (supports new & legacy formats)
        for (final userConfig in config.users) {
          print(
            'DEBUG: ConfigSync.pullUsersFromDrive() - upserting user: ${userConfig.username}',
          );

          // Prefer new triplet; fall back to legacy pinHash-only.
          final hash = userConfig.passwordHash;
          final salt = userConfig.passwordSalt;
          final kdf = userConfig.passwordKdf;

          await userDao.upsertUser(
            shopId: shopId,
            username: userConfig.username,
            role: userConfig.role,
            passwordHash: hash,
            mustChangePin: userConfig.mustChangePin,
          );

          // Update salt and kdf if available
          if (salt.isNotEmpty || kdf.isNotEmpty) {
            final existingUser = await userDao.findByUsernameAndShop(
              userConfig.username,
              shopId,
            );
            if (existingUser != null) {
              await userDao.updateUserSecure(
                id: existingUser.id,
                passwordHash: hash,
                salt: salt.isNotEmpty ? salt : null,
                kdf: kdf.isNotEmpty ? kdf : null,
              );
            }
          }
        }

        // Delete any local users not present in Drive config
        final deletedCount = await userDao.deleteNotInUsernames(
          shopId: shopId,
          usernames: usernamesInCfg,
        );
        if (deletedCount > 0) {
          print(
            'DEBUG: ConfigSync.pullUsersFromDrive() - purged $deletedCount users not in Drive config',
          );
        }
      });

      print('DEBUG: ConfigSync.pullUsersFromDrive() - completed successfully');
    } catch (e) {
      print('DEBUG: ConfigSync.pullUsersFromDrive() - error: $e');
      rethrow;
    }
  }

  /// Create default admin user and push to Drive
  Future<void> createDefaultAdminAndPush(
    String shopId,
    String ownerEmail,
  ) async {
    try {
      print(
        'DEBUG: ConfigSync.createDefaultAdminAndPush() - starting for shop: $shopId',
      );

      final userDao = UserDao(_db);

      // Create default admin user with PIN 0000
      final (hash, salt, kdf) = await PasswordHasher.hashDefaultPin0000();

      await userDao.createUser(
        shopId: shopId,
        username: 'admin',
        role: 'admin',
        passwordHash: hash,
        salt: salt,
        kdf: kdf,
      );

      print(
        'DEBUG: ConfigSync.createDefaultAdminAndPush() - created admin user',
      );

      // Push to Drive
      await pushLocalUsersToDrive(shopId);

      print('DEBUG: ConfigSync.createDefaultAdminAndPush() - pushed to Drive');
    } catch (e) {
      print('DEBUG: ConfigSync.createDefaultAdminAndPush() - error: $e');
      rethrow;
    }
  }
}
