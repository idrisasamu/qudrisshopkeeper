import 'package:drift/drift.dart';
import '../app_database.dart';

part 'user_dao.g.dart';

@DriftAccessor(tables: [Users])
class UserDao extends DatabaseAccessor<AppDatabase> with _$UserDaoMixin {
  UserDao(AppDatabase db) : super(db);

  /// Create a new user
  Future<String> createUser({
    required String shopId,
    required String username,
    required String role,
    required String passwordHash,
    required String salt,
    required String kdf,
    int rev = 1,
  }) async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final now = DateTime.now();

    await into(users).insert(
      UsersCompanion.insert(
        id: id,
        shopId: shopId,
        username: username,
        name: username, // Use username as display name
        email: '${username}@shop.local', // Generate email
        role: role,
        isActive: const Value(true),
        passwordHash: passwordHash,
        salt: salt,
        kdf: Value(kdf),
        rev: Value(rev),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
    );

    return id;
  }

  /// Update an existing user
  Future<void> updateUser({
    required String id,
    String? username,
    String? role,
    bool? isActive,
    String? passwordHash,
    String? salt,
    String? kdf,
    int? rev,
  }) async {
    final companion = UsersCompanion(
      username: username != null ? Value(username) : const Value.absent(),
      role: role != null ? Value(role) : const Value.absent(),
      isActive: isActive != null ? Value(isActive) : const Value.absent(),
      passwordHash: passwordHash != null
          ? Value(passwordHash)
          : const Value.absent(),
      salt: salt != null ? Value(salt) : const Value.absent(),
      kdf: kdf != null ? Value(kdf) : const Value.absent(),
      rev: rev != null ? Value(rev) : const Value.absent(),
      updatedAt: Value(DateTime.now()),
    );

    await (update(users)..where((tbl) => tbl.id.equals(id))).write(companion);
  }

  /// Deactivate a user (soft delete)
  Future<void> deactivateUser(String id) async {
    await updateUser(id: id, isActive: false);
  }

  /// Find user by username
  Future<User?> findByUsername(String username) async {
    return await (select(
      users,
    )..where((tbl) => tbl.username.equals(username))).getSingleOrNull();
  }

  /// Find user by username and shop ID
  Future<User?> findByUsernameAndShop(String username, String shopId) async {
    return await (select(users)..where(
          (tbl) => tbl.username.equals(username) & tbl.shopId.equals(shopId),
        ))
        .getSingleOrNull();
  }

  /// Get all active staff users for a shop
  Future<List<User>> getAllActiveStaff(String shopId) async {
    return await (select(users)..where(
          (tbl) =>
              tbl.shopId.equals(shopId) &
              tbl.isActive.equals(true) &
              tbl.role.equals('staff'),
        ))
        .get();
  }

  /// Get all users for a shop (including admin)
  Future<List<User>> getAllUsers(String shopId) async {
    return await (select(
      users,
    )..where((tbl) => tbl.shopId.equals(shopId))).get();
  }

  /// Get admin user for a shop
  Future<User?> getAdminUser(String shopId) async {
    return await (select(
          users,
        )..where((tbl) => tbl.shopId.equals(shopId) & tbl.role.equals('admin')))
        .getSingleOrNull();
  }

  /// Check if username exists in shop
  Future<bool> usernameExists(String username, String shopId) async {
    final user = await findByUsernameAndShop(username, shopId);
    return user != null;
  }

  /// Get the highest revision number for a shop
  Future<int> getMaxRev(String shopId) async {
    final result =
        await (select(users)
              ..where((tbl) => tbl.shopId.equals(shopId))
              ..orderBy([(tbl) => OrderingTerm.desc(tbl.rev)])
              ..limit(1))
            .getSingleOrNull();

    return result?.rev ?? 0;
  }

  /// Replace all users for a shop (used during sync)
  Future<void> replaceUsersForShop(String shopId, List<User> newUsers) async {
    await transaction(() async {
      // Delete existing users for this shop
      await (delete(users)..where((tbl) => tbl.shopId.equals(shopId))).go();

      // Insert new users
      for (final user in newUsers) {
        await into(users).insert(user);
      }
    });
  }

  /// Update user security fields (password, PIN change flags)
  Future<void> updateUserSecure({
    required String id,
    String? passwordHash,
    String? salt,
    String? kdf,
    bool? mustChangePassword,
    DateTime? passwordUpdatedAt,
    bool revBump = false,
  }) async {
    final companion = UsersCompanion(
      passwordHash: passwordHash != null
          ? Value(passwordHash)
          : const Value.absent(),
      salt: salt != null ? Value(salt) : const Value.absent(),
      kdf: kdf != null ? Value(kdf) : const Value.absent(),
      mustChangePassword: mustChangePassword != null
          ? Value(mustChangePassword)
          : const Value.absent(),
      passwordUpdatedAt: passwordUpdatedAt != null
          ? Value(passwordUpdatedAt)
          : const Value.absent(),
      rev: revBump
          ? Value(await getMaxRev(await _getShopIdForUser(id)) + 1)
          : const Value.absent(),
      updatedAt: Value(DateTime.now()),
    );

    await (update(users)..where((tbl) => tbl.id.equals(id))).write(companion);
  }

  /// Get shop ID for a user
  Future<String> _getShopIdForUser(String userId) async {
    final user = await (select(
      users,
    )..where((tbl) => tbl.id.equals(userId))).getSingleOrNull();
    if (user == null) throw Exception('User not found');
    return user.shopId;
  }

  /// Upsert a user (insert or update)
  Future<void> upsertUser({
    required String shopId,
    required String username,
    required String role,
    required String passwordHash,
    required bool mustChangePin,
  }) async {
    final now = DateTime.now();

    // Check if user exists
    final existingUser =
        await (select(users)..where(
              (tbl) =>
                  tbl.shopId.equals(shopId) & tbl.username.equals(username),
            ))
            .getSingleOrNull();

    if (existingUser != null) {
      // Update existing user
      await (update(
        users,
      )..where((tbl) => tbl.id.equals(existingUser.id))).write(
        UsersCompanion(
          role: Value(role),
          passwordHash: Value(passwordHash),
          mustChangePassword: Value(mustChangePin),
          updatedAt: Value(now),
        ),
      );
    } else {
      // Create new user
      final id = DateTime.now().millisecondsSinceEpoch.toString();
      await into(users).insert(
        UsersCompanion.insert(
          id: id,
          shopId: shopId,
          username: username,
          name: username,
          email: '${username}@shop.local',
          role: role,
          isActive: const Value(true),
          passwordHash: passwordHash,
          salt: '', // Will be set by password hasher
          kdf: const Value(''),
          mustChangePassword: Value(mustChangePin),
          rev: const Value(1),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );
    }
  }

  /// Delete user by username and shop
  Future<int> deleteByUsername({
    required String shopId,
    required String username,
  }) {
    return (delete(users)
          ..where((t) => t.shopId.equals(shopId) & t.username.equals(username)))
        .go();
  }

  /// Delete users not in the provided username set
  Future<int> deleteNotInUsernames({
    required String shopId,
    required Set<String> usernames,
  }) {
    return (delete(users)..where(
          (t) =>
              t.shopId.equals(shopId) & t.username.isNotIn(usernames.toList()),
        ))
        .go();
  }

  /// Get active user by username and shop
  Future<User?> getActiveUserByUsername({
    required String shopId,
    required String username,
  }) {
    return (select(users)..where(
          (t) =>
              t.shopId.equals(shopId) &
              t.username.equals(username) &
              t.isActive.equals(true),
        ))
        .getSingleOrNull();
  }

  /// Check if user exists
  Future<bool> exists({
    required String shopId,
    required String username,
  }) async {
    final q =
        (select(users)..where(
              (t) => t.shopId.equals(shopId) & t.username.equals(username),
            ))
            .getSingleOrNull();
    return (await q) != null;
  }

  /// Stream active users for a shop
  Stream<List<User>> watchUsersForShopActive(String shopId) {
    return (select(
      users,
    )..where((t) => t.shopId.equals(shopId) & t.isActive.equals(true))).watch();
  }
}
