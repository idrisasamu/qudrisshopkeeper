import 'dart:convert';
import 'package:googleapis/drive/v3.dart' as gdrive;
import '../../features/sync/sync_codec.dart'; // encrypt/decrypt
import '../../features/sync/drive_client.dart';

class DriveDataRepo {
  final DriveClient _driveClient;

  DriveDataRepo(this._driveClient);

  /// Write encrypted string to Drive
  Future<void> writeEncryptedString(
    String parentId,
    String name,
    String content,
  ) async {
    try {
      print(
        'DEBUG: DriveDataRepo.writeEncryptedString() - writing $name to parent $parentId',
      );
      final enc = await SyncCodec.encryptString(content);
      await _uploadString(
        parentId,
        name,
        enc,
        mimeType: 'application/octet-stream',
      );
      print(
        'DEBUG: DriveDataRepo.writeEncryptedString() - completed successfully',
      );
    } catch (e) {
      print('DEBUG: DriveDataRepo.writeEncryptedString() - error: $e');
      rethrow;
    }
  }

  /// Read and decrypt string from Drive
  Future<String?> readDecryptedString(String fileId) async {
    try {
      print(
        'DEBUG: DriveDataRepo.readDecryptedString() - reading file $fileId',
      );
      final api = await _driveClient.getApi();
      final media =
          await api.files.get(
                fileId,
                downloadOptions: gdrive.DownloadOptions.fullMedia,
              )
              as gdrive.Media;
      final raw = await utf8.decoder.bind(media.stream).join();
      final decrypted = await SyncCodec.decryptString(raw);
      print(
        'DEBUG: DriveDataRepo.readDecryptedString() - decrypted successfully',
      );
      return decrypted;
    } catch (e) {
      print('DEBUG: DriveDataRepo.readDecryptedString() - error: $e');
      return null;
    }
  }

  /// Find file ID by name in parent folder
  Future<String?> findFileId(String parentId, String name) async {
    try {
      print(
        'DEBUG: DriveDataRepo.findFileId() - searching for $name in parent $parentId',
      );
      final api = await _driveClient.getApi();
      final res = await api.files.list(
        q: "'$parentId' in parents and name='$name' and trashed=false",
        $fields: 'files(id,name)',
        spaces: 'drive',
      );
      if (res.files?.isEmpty ?? true) {
        print('DEBUG: DriveDataRepo.findFileId() - file not found');
        return null;
      }
      final fileId = res.files!.first.id!;
      print('DEBUG: DriveDataRepo.findFileId() - found file: $fileId');
      return fileId;
    } catch (e) {
      print('DEBUG: DriveDataRepo.findFileId() - error: $e');
      return null;
    }
  }

  /// List files by prefix in parent folder
  Future<List<gdrive.File>> listByPrefix(String parentId, String prefix) async {
    try {
      print(
        'DEBUG: DriveDataRepo.listByPrefix() - listing files with prefix $prefix in parent $parentId',
      );
      final api = await _driveClient.getApi();
      final res = await api.files.list(
        q: "'$parentId' in parents and name contains '$prefix' and trashed=false",
        $fields: 'files(id,name,modifiedTime)',
        orderBy: 'name',
        spaces: 'drive',
      );
      final files = res.files ?? [];
      print(
        'DEBUG: DriveDataRepo.listByPrefix() - found ${files.length} files',
      );
      return files;
    } catch (e) {
      print('DEBUG: DriveDataRepo.listByPrefix() - error: $e');
      return [];
    }
  }

  /// Overwrite existing file with new content
  Future<void> overwriteString(String fileId, String content) async {
    try {
      print(
        'DEBUG: DriveDataRepo.overwriteString() - overwriting file $fileId',
      );
      final api = await _driveClient.getApi();
      final bytes = utf8.encode(content);
      final media = gdrive.Media(Stream.fromIterable([bytes]), bytes.length);

      await api.files.update(gdrive.File(), fileId, uploadMedia: media);
      print('DEBUG: DriveDataRepo.overwriteString() - completed successfully');
    } catch (e) {
      print('DEBUG: DriveDataRepo.overwriteString() - error: $e');
      rethrow;
    }
  }

  /// Upload string content to Drive
  Future<void> _uploadString(
    String parentId,
    String name,
    String content, {
    String? mimeType,
  }) async {
    try {
      print(
        'DEBUG: DriveDataRepo._uploadString() - uploading $name to parent $parentId',
      );
      final api = await _driveClient.getApi();
      final bytes = utf8.encode(content);
      final media = gdrive.Media(Stream.fromIterable([bytes]), bytes.length);

      await api.files.create(
        gdrive.File(name: name, parents: [parentId], mimeType: mimeType),
        uploadMedia: media,
      );
      print('DEBUG: DriveDataRepo._uploadString() - completed successfully');
    } catch (e) {
      print('DEBUG: DriveDataRepo._uploadString() - error: $e');
      rethrow;
    }
  }
}
