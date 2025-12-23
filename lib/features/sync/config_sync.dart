import 'package:drift/drift.dart';
import '../../common/session.dart';
import '../../data/local/app_database.dart';
import '../../data/local/daos/users_dao.dart';
import 'drive_client.dart';
import 'sync_utils.dart';

class ConfigSync {
  final AppDatabase db;
  final DriveClient drive;
  ConfigSync(this.db, this.drive);

  Future<void> pushStaffConfig() async {
    final all = await (db.select(db.users)).get();

    final rev = (all.isEmpty)
        ? 1
        : (all.map((u) => u.rev).reduce((a, b) => a > b ? a : b));
    final payload = {
      'rev': rev,
      'users': all
          .map(
            (u) => {
              'id': u.id,
              'username': u.username,
              'role': u.role,
              'isActive': u.isActive,
              'hash': u.passwordHash,
              'salt': u.salt,
              'kdf': u.kdf,
              'mustChange': u.mustChangePassword,
              'passwordUpdatedAt': u.passwordUpdatedAt
                  ?.toUtc()
                  .toIso8601String(),
              'updatedAt': u.updatedAt.toUtc().toIso8601String(),
            },
          )
          .toList(),
    };

    final enc = await SyncCodec.encryptJson(payload);
    final cfgId = await SessionManager().getString(
      'drive_config_folder_id',
    ); // ensure this is set
    if (cfgId == null) throw Exception('Config folder not set');
    await drive.uploadString(
      cfgId,
      SyncCodec.makeFileName('staff.json'),
      enc,
      mimeType: 'application/json',
    );
  }

  Future<void> pullStaffConfig() async {
    final cfgId = await SessionManager().getString('drive_config_folder_id');
    if (cfgId == null) return;

    // find staff.json or staff.json.enc
    final f = await drive.findFirstInFolder(
      cfgId,
      names: ['staff.json.enc', 'staff.json'],
    );
    if (f == null || f.id == null || f.name == null) return;

    final text = await drive.downloadString(f.id!);
    final obj = await SyncCodec.decodeFromDrive(
      fileName: f.name!,
      content: text,
    );

    final remoteRev = (obj['rev'] as num?)?.toInt() ?? 0;
    final users = (obj['users'] as List).cast<Map>();

    // build companions
    final rows = users.map((m) {
      return UsersCompanion.insert(
        id: m['id'] as String,
        shopId: 'default', // TODO: get from session
        username: m['username'] as String,
        name: m['username'] as String, // Use username as display name
        email: '${m['username']}@shop.local', // Generate email
        role: m['role'] as String,
        isActive: Value(m['isActive'] as bool? ?? true),
        passwordHash: m['hash'] as String,
        salt: m['salt'] as String,
        kdf: Value(m['kdf'] as String? ?? 'pbkdf2-sha256/150000'),
        mustChangePassword: Value(m['mustChange'] as bool? ?? false),
        passwordUpdatedAt: Value(
          m['passwordUpdatedAt'] != null
              ? DateTime.parse(m['passwordUpdatedAt'] as String).toLocal()
              : null,
        ),
        rev: Value(remoteRev),
        createdAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      );
    }).toList();

    final dao = UsersDao(db);
    // replace by rev policy
    final localMaxRev = await (db.select(db.users)).get().then(
      (rows) => rows.isEmpty
          ? 0
          : rows.map((u) => u.rev).reduce((a, b) => a > b ? a : b),
    );
    if (remoteRev > localMaxRev) {
      await dao.upsertManyFromConfig(remoteRev, rows);
    }
  }
}
