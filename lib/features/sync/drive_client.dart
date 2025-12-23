import 'dart:convert';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as gdrive;
import 'package:http/http.dart' as http;

class DriveClient {
  final GoogleSignIn _gsignin;
  DriveClient(this._gsignin);

  /// Default constructor for new usage
  DriveClient.defaultConstructor() : _gsignin = GoogleSignIn();

  /// Check if we have Drive scope permissions
  Future<bool> hasDriveScope() async {
    try {
      final account = await _gsignin.signInSilently();
      if (account == null) return false;

      final authHeaders = await account.authHeaders;
      final hasDrive = authHeaders != null;
      print(
        'DEBUG: DriveClient.hasDriveScope() - authHeaders: ${authHeaders != null ? 'present' : 'null'}, hasDrive: $hasDrive',
      );
      return hasDrive;
    } catch (e) {
      print('DEBUG: DriveClient.hasDriveScope() - error: $e');
      return false;
    }
  }

  Future<gdrive.DriveApi> getApi() async {
    print('DEBUG: DriveClient.getApi() - attempting to get account');
    final account = await _gsignin.signInSilently();
    print('DEBUG: DriveClient.getApi() - account: ${account?.email}');

    if (account == null) {
      print('DEBUG: DriveClient.getApi() - no account, attempting sign in');
      final signedInAccount = await _gsignin.signIn();
      if (signedInAccount == null) {
        throw Exception('No Google account available');
      }
      final authHeaders = await signedInAccount.authHeaders;
      if (authHeaders == null)
        throw Exception('No Google auth headers after sign in');
      final client = _GoogleAuthClient(authHeaders);
      return gdrive.DriveApi(client);
    }

    // ensure we have Drive scope; caller handles re-auth if null
    final authHeaders = await account.authHeaders;
    print(
      'DEBUG: DriveClient.getApi() - authHeaders: ${authHeaders != null ? 'present' : 'null'}',
    );
    if (authHeaders == null) throw Exception('No Google auth headers');
    final client = _GoogleAuthClient(authHeaders);
    return gdrive.DriveApi(client);
  }

  Future<gdrive.File> createFolder(String name, {String? parentId}) async {
    final api = await getApi();
    final file = gdrive.File()
      ..name = name
      ..mimeType = 'application/vnd.google-apps.folder'
      ..parents = parentId == null ? null : [parentId];
    return await api.files.create(file);
  }

  Future<String?> findChildFolderId(String parentId, String name) async {
    final api = await getApi();
    final q =
        "name='${name.replaceAll("'", "\\'")}' and '${parentId}' in parents and mimeType='application/vnd.google-apps.folder' and trashed=false";
    final res = await api.files.list(
      q: q,
      $fields: 'files(id,name)',
      pageSize: 10,
    );
    return res.files?.isNotEmpty == true ? res.files!.first.id : null;
  }

  Future<void> grantViewerOnFolder(String folderId, String email) async {
    final api = await getApi();
    final perm = gdrive.Permission()
      ..type = 'user'
      ..role = 'reader'
      ..emailAddress = email;
    await api.permissions.create(perm, folderId, sendNotificationEmail: false);
  }

  Future<void> grantEditorOnFolder(String folderId, String email) async {
    final api = await getApi();
    final perm = gdrive.Permission()
      ..type = 'user'
      ..role = 'writer'
      ..emailAddress = email;
    await api.permissions.create(perm, folderId, sendNotificationEmail: false);
  }

  Future<String> downloadString(String fileId) async {
    final api = await getApi();
    final media =
        await api.files.get(
              fileId,
              downloadOptions: gdrive.DownloadOptions.fullMedia,
            )
            as gdrive.Media;
    final bytes = <int>[];
    await for (final chunk in media.stream) {
      bytes.addAll(chunk);
    }
    return String.fromCharCodes(bytes);
  }

  /// Upload a small text/JSON file to a folder.
  Future<gdrive.File> uploadString(
    String parentId,
    String name,
    String text, {
    String mimeType = 'text/plain',
  }) async {
    final api = await getApi();
    final file = gdrive.File()
      ..name = name
      ..parents = [parentId];
    final media = gdrive.Media(Stream.value(utf8.encode(text)), text.length);
    return api.files.create(file, uploadMedia: media);
  }

  /// Upload binary data to a folder
  Future<gdrive.File> uploadFile({
    required String parentFolderId,
    required String fileName,
    required List<int> content,
    String mimeType = 'application/octet-stream',
  }) async {
    final api = await getApi();
    final file = gdrive.File()
      ..name = fileName
      ..parents = [parentFolderId];
    final media = gdrive.Media(Stream.value(content), content.length);
    return api.files.create(file, uploadMedia: media);
  }

  /// Download binary data from a file
  Future<List<int>?> downloadFile({
    required String parentFolderId,
    required String fileName,
  }) async {
    final api = await getApi();

    // First, find the file by name in the parent folder
    final q =
        "'$parentFolderId' in parents and name='$fileName' and trashed=false";
    final res = await api.files.list(
      q: q,
      $fields: 'files(id,name)',
      pageSize: 1,
    );

    if (res.files?.isEmpty ?? true) {
      return null;
    }

    final fileId = res.files!.first.id!;

    // Download the file content
    final media =
        await api.files.get(
              fileId,
              downloadOptions: gdrive.DownloadOptions.fullMedia,
            )
            as gdrive.Media;

    final bytes = <int>[];
    await for (final chunk in media.stream) {
      bytes.addAll(chunk);
    }
    return bytes;
  }

  /// List subfolders of a folder (id + name).
  Future<List<gdrive.File>> listChildFolders(String parentId) async {
    final api = await getApi();
    final q =
        "'$parentId' in parents and mimeType='application/vnd.google-apps.folder' and trashed=false";
    final res = await api.files.list(
      q: q,
      $fields: 'files(id,name,modifiedTime)',
      pageSize: 100,
      orderBy: 'name',
    );
    return res.files ?? const [];
  }

  /// List new JSON files by modifiedTime > sinceModifiedMs.
  Future<List<gdrive.File>> listNewJsonFiles(
    String parentId, {
    required int sinceModifiedMs,
  }) async {
    final api = await getApi();
    final sinceIso = DateTime.fromMillisecondsSinceEpoch(
      sinceModifiedMs,
      isUtc: true,
    ).toUtc().toIso8601String();
    final q = [
      "'$parentId' in parents",
      "mimeType='application/json'",
      "trashed=false",
      if (sinceModifiedMs > 0) "modifiedTime > '$sinceIso'",
    ].join(' and ');
    final res = await api.files.list(
      q: q,
      $fields: 'files(id,name,modifiedTime,size)',
      pageSize: 100,
      orderBy: 'modifiedTime desc',
    );
    return res.files ?? const [];
  }
}

/// Minimal client that injects auth headers.
class _GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _inner = http.Client();
  _GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _inner.send(request);
  }
}

// DriveClient helpers extension
extension DriveHelpers on DriveClient {
  // Expose the API instance (or adapt to your internal getter)
  Future<gdrive.DriveApi> api() => getApi();

  Future<String> ensureFolderNamed(
    String name, {
    required String parentId,
  }) async {
    final existing = await findChildFolderId(parentId, name);
    if (existing != null) return existing;
    final created = await createFolder(name, parentId: parentId);
    return created.id!;
  }

  Future<String?> findChildFolderId(String parentId, String name) async {
    final api = await getApi();
    final q =
        "'$parentId' in parents and name = '$name' and mimeType = 'application/vnd.google-apps.folder' and trashed = false";
    final res = await api.files.list(
      q: q,
      $fields: 'files(id,name)',
      pageSize: 1,
      orderBy: 'name',
    );
    if ((res.files?.isNotEmpty ?? false)) return res.files!.first.id;
    return null;
  }

  Future<gdrive.File> createFolder(
    String name, {
    required String parentId,
  }) async {
    final api = await getApi();
    final f = gdrive.File()
      ..name = name
      ..mimeType = 'application/vnd.google-apps.folder'
      ..parents = [parentId];
    return api.files.create(f);
  }

  Future<String> downloadString(String fileId) async {
    final api = await getApi();
    final media =
        await api.files.get(
              fileId,
              downloadOptions: gdrive.DownloadOptions.fullMedia,
            )
            as gdrive.Media;
    final bytes = await media.stream.fold<List<int>>(<int>[], (a, b) {
      a.addAll(b);
      return a;
    });
    return utf8.decode(bytes);
  }

  Future<void> uploadString(
    String parentId,
    String name,
    String data, {
    String mimeType = 'text/plain',
  }) async {
    final api = await getApi();
    final f = gdrive.File()
      ..name = name
      ..parents = [parentId]
      ..mimeType = mimeType;
    await api.files.create(
      f,
      uploadMedia: gdrive.Media(Stream.value(utf8.encode(data)), data.length),
    );
  }

  /// Move a folder to trash
  Future<void> trashFolder(String folderId) async {
    final api = await getApi();
    final file = gdrive.File()..trashed = true;
    await api.files.update(file, folderId);
  }

  /// Revoke all permissions on a folder
  Future<void> revokeAllPermissions(String folderId) async {
    final api = await getApi();

    // Get all permissions for the folder
    final permissions = await api.permissions.list(folderId);

    // Revoke each permission (except owner)
    for (final permission in permissions.permissions ?? []) {
      if (permission.role != 'owner' && permission.id != null) {
        try {
          await api.permissions.delete(folderId, permission.id!);
        } catch (e) {
          print('Warning: Failed to revoke permission ${permission.id}: $e');
        }
      }
    }
  }

  /// Create a tombstone file to mark a shop as deleted
  Future<void> createTombstone(String folderId, String shopId) async {
    final tombstoneData = {
      'deleted': true,
      'deletedAt': DateTime.now().toIso8601String(),
      'shopId': shopId,
    };

    await uploadString(
      folderId,
      'deleted.json',
      jsonEncode(tombstoneData),
      mimeType: 'application/json',
    );
  }

  /// Find first file in folder matching any of the given names
  Future<gdrive.File?> findFirstInFolder(
    String folderId, {
    required List<String> names,
  }) async {
    final api = await getApi();
    final nameFilter = names.map((n) => "name = '$n'").join(' or ');
    final q = "('$folderId' in parents) and ($nameFilter) and trashed = false";
    final res = await api.files.list(
      q: q,
      spaces: 'drive',
      $fields: 'files(id,name,mimeType)',
    );
    if (res.files == null || res.files!.isEmpty) return null;
    return res.files!.first;
  }
}
