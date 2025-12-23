import 'package:drift/drift.dart';
import '../app_database.dart';
import '../../repositories/sync_ops_repo.dart';

class StaffDao {
  final AppDatabase db;
  StaffDao(this.db);

  Future<void> upsertStaff({
    required String email,
    required String shopId,
    String role = 'sales',
    String? displayName,
    bool active = true,
  }) async {
    final existing = await (db.select(
      db.users,
    )..where((t) => t.email.equals(email))).getSingleOrNull();

    User? user;
    if (existing == null) {
      final userId = DateTime.now().millisecondsSinceEpoch.toString();
      user = await db
          .into(db.users)
          .insertReturning(
            UsersCompanion.insert(
              id: userId,
              shopId: shopId,
              username: email.split('@')[0], // Use email prefix as username
              name: displayName ?? '',
              email: email,
              role: role,
              isActive: Value(active),
              passwordHash: 'temp', // Will be updated by caller
              salt: 'temp', // Will be updated by caller
              createdAt: Value(DateTime.now()),
            ),
          );
    } else {
      await (db.update(db.users)..where((t) => t.email.equals(email))).write(
        UsersCompanion(
          role: Value(role),
          name: Value(displayName ?? existing.name),
          isActive: Value(active),
        ),
      );
      // Get the updated user
      user = await (db.select(
        db.users,
      )..where((t) => t.email.equals(email))).getSingle();
    }

    // Emit sync operation for user upsert
    final syncRepo = SyncOpsRepo(db);
    await syncRepo.emitUserUpsert(user);
    print('DEBUG: Emitted user upsert sync operation for: ${user.email}');
  }

  Future<void> deactivateStaff(String email) async {
    await (db.update(db.users)..where((t) => t.email.equals(email))).write(
      const UsersCompanion(isActive: Value(false)),
    );

    // Get the updated user and emit sync operation
    final user = await (db.select(
      db.users,
    )..where((t) => t.email.equals(email))).getSingleOrNull();

    if (user != null) {
      final syncRepo = SyncOpsRepo(db);
      await syncRepo.emitUserUpsert(user);
      print(
        'DEBUG: Emitted user deactivation sync operation for: ${user.email}',
      );
    }
  }

  Stream<List<User>> watchActiveStaff() {
    return (db.select(
      db.users,
    )..where((t) => t.isActive.equals(true) & t.role.equals('sales'))).watch();
  }

  Future<List<User>> getActiveStaff() async {
    return await (db.select(
      db.users,
    )..where((t) => t.isActive.equals(true) & t.role.equals('sales'))).get();
  }

  Future<void> fixStaffShopId(String email, String correctShopId) async {
    await (db.update(db.users)..where((t) => t.email.equals(email))).write(
      UsersCompanion(shopId: Value(correctShopId)),
    );
  }
}
