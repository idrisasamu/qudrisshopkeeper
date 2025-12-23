import 'package:drift/drift.dart';
import '../app_database.dart';

part 'users_dao.g.dart';

@DriftAccessor(tables: [Users])
class UsersDao extends DatabaseAccessor<AppDatabase> with _$UsersDaoMixin {
  UsersDao(AppDatabase db) : super(db);

  Future<User?> findByUsername(String username) {
    return (select(
      users,
    )..where((u) => u.username.equals(username))).getSingleOrNull();
  }

  Future<List<User>> allActiveStaff() {
    return (select(users)
          ..where((u) => u.role.equals('staff'))
          ..where((u) => u.isActive.equals(true)))
        .get();
  }

  Future<void> createUser(UsersCompanion data) async {
    await into(users).insert(data, mode: InsertMode.insertOrReplace);
  }

  Future<void> updateUserSecure({
    required String id,
    required String passwordHash,
    required String salt,
    required String kdf,
    required bool mustChangePassword,
    required DateTime passwordUpdatedAt,
    bool bumpRev = true,
  }) async {
    final existing = await (select(
      users,
    )..where((u) => u.id.equals(id))).getSingle();
    await (update(users)..where((u) => u.id.equals(id))).write(
      UsersCompanion(
        passwordHash: Value(passwordHash),
        salt: Value(salt),
        kdf: Value(kdf),
        mustChangePassword: Value(mustChangePassword),
        passwordUpdatedAt: Value(passwordUpdatedAt),
        rev: Value(bumpRev ? (existing.rev + 1) : existing.rev),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> upsertManyFromConfig(
    int newRev,
    List<UsersCompanion> rows,
  ) async {
    await transaction(() async {
      // replace-by-rev: clear and insert fresh, or do smarter merge if you want
      await delete(users).go();
      for (final r in rows) {
        await into(users).insert(r, mode: InsertMode.insertOrReplace);
      }
    });
  }

  Future<void> deactivateUser(String id) async {
    await (update(users)..where((u) => u.id.equals(id))).write(
      UsersCompanion(
        isActive: const Value(false),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }
}
