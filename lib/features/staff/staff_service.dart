import 'package:flutter/material.dart';
import '../../data/local/app_database.dart';
import '../../data/local/daos/user_dao.dart';
import '../../data/services/config_sync.dart';
import '../../features/sync/drive_client.dart';
import '../../common/session.dart';
import '../auth/password_hasher.dart';

/// Service for managing staff with automatic Drive synchronization
class StaffService {
  final AppDatabase db;
  final SessionManager session;

  StaffService({required this.db, required this.session});

  /// Add a new staff member and push to Drive
  Future<void> addStaff({
    required String username,
    required String pin,
    String role = 'staff',
  }) async {
    final shopId = await session.getString('shop_id');
    if (shopId == null) throw StateError('No shop selected');

    // 1) Hash the PIN (produces hash/salt/kdf)
    final (hash, salt, kdf) = await PasswordHasher.hashPassword(pin);

    // 2) Insert locally
    final userDao = UserDao(db);
    await userDao.createUser(
      shopId: shopId,
      username: username,
      role: role,
      passwordHash: hash,
      salt: salt,
      kdf: kdf,
    );

    // Set must change PIN flag if using default PIN
    if (pin == '0000') {
      final user = await userDao.findByUsernameAndShop(username, shopId);
      if (user != null) {
        await userDao.updateUserSecure(id: user.id, mustChangePassword: true);
      }
    }

    // 3) Immediately push *all users* to Drive
    await _pushUsersToDrive(shopId);
  }

  /// Update staff PIN and push to Drive
  Future<void> updateStaffPin({
    required String username,
    required String newPin,
  }) async {
    final shopId = await session.getString('shop_id');
    if (shopId == null) throw StateError('No shop selected');

    final (hash, salt, kdf) = await PasswordHasher.hashPassword(newPin);
    final userDao = UserDao(db);
    final user = await userDao.findByUsernameAndShop(username, shopId);
    if (user == null) throw StateError('User not found');

    await userDao.updateUserSecure(
      id: user.id,
      passwordHash: hash,
      salt: salt,
      kdf: kdf,
      mustChangePassword: false,
    );

    await _pushUsersToDrive(shopId);
  }

  /// Deactivate staff member (hard delete) and push to Drive
  Future<void> deactivateStaff(String username) async {
    final uname = username.trim().toLowerCase();
    print(
      'DEBUG: StaffService.deactivateStaff() - starting deletion of $uname',
    );

    final shopId = await session.getString('shop_id');
    if (shopId == null) throw StateError('No shop selected');
    print('DEBUG: StaffService.deactivateStaff() - shopId: $shopId');

    final userDao = UserDao(db);
    final user = await userDao.findByUsernameAndShop(uname, shopId);
    if (user == null) {
      print('DEBUG: StaffService.deactivateStaff() - user not found: $uname');
      throw StateError('User not found');
    }
    print(
      'DEBUG: StaffService.deactivateStaff() - found user: ${user.username} (${user.role})',
    );

    // Cache user data for potential rollback
    final userData = {
      'id': user.id,
      'username': user.username,
      'role': user.role,
      'passwordHash': user.passwordHash,
      'salt': user.salt,
      'kdf': user.kdf,
      'mustChangePassword': user.mustChangePassword,
    };

    // 1) Delete local
    print(
      'DEBUG: StaffService.deactivateStaff() - attempting local deletion...',
    );
    final deletedCount = await userDao.deleteByUsername(
      shopId: shopId,
      username: uname,
    );
    print(
      'DEBUG: StaffService.deactivateStaff() - deleted local=$deletedCount',
    );

    // Verify deletion by checking if user still exists
    final userAfterDelete = await userDao.findByUsernameAndShop(uname, shopId);
    print(
      'DEBUG: StaffService.deactivateStaff() - user exists after delete: ${userAfterDelete != null}',
    );

    try {
      // 2) Push remaining active users to Drive (canonical file)
      print('DEBUG: StaffService.deactivateStaff() - pushing to Drive...');
      await _pushUsersToDrive(shopId);

      // 3) Pull back once to normalize this device
      print('DEBUG: StaffService.deactivateStaff() - re-pulling from Drive...');
      final driveClient = DriveClient.defaultConstructor();
      final configSync = ConfigSync(db, driveClient);
      await configSync.pullUsersFromDrive(shopId);

      print(
        'DEBUG: StaffService.deactivateStaff() - deletion process completed successfully',
      );
    } catch (e) {
      // Roll back local delete to avoid divergence if Drive failed
      print(
        'ERROR: StaffService.deactivateStaff() - Drive operation failed: $e — restoring user locally.',
      );

      // Restore the user locally
      await userDao.createUser(
        shopId: shopId,
        username: userData['username'] as String,
        role: userData['role'] as String,
        passwordHash: userData['passwordHash'] as String,
        salt: userData['salt'] as String,
        kdf: userData['kdf'] as String,
      );

      // Set the must change password flag if it was set
      if (userData['mustChangePassword'] == true) {
        final restoredUser = await userDao.findByUsernameAndShop(
          userData['username'] as String,
          shopId,
        );
        if (restoredUser != null) {
          await userDao.updateUserSecure(
            id: restoredUser.id,
            mustChangePassword: true,
          );
        }
      }

      rethrow;
    }
  }

  /// Push all users to Drive
  Future<void> _pushUsersToDrive(String shopId) async {
    try {
      final drive = DriveClient.defaultConstructor();
      final sync = ConfigSync(db, drive);

      await sync.pushLocalUsersToDrive(shopId);
      debugPrint('ConfigSync: users pushed for $shopId');
    } catch (e, st) {
      debugPrint('ConfigSync: push failed $e\n$st');
      // Optionally queue a retry, or show a snackbar
    }
  }
}
