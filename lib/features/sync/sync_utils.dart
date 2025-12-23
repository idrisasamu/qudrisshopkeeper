import 'dart:convert';
import '../../common/session.dart';
import 'crypto_box.dart';

class SyncCodec {
  /// Returns true if remote file is encrypted (.json.enc)
  static bool isEncryptedName(String name) => name.endsWith('.json.enc');

  /// Produce the final Drive filename (adds .json.enc if encrypted)
  static String makeFileName(String base) =>
      base.endsWith('.json') ? '${base}.enc' : base;

  /// Encrypt a JSON-serializable payload with K_shop → base64url string
  static Future<String> encryptJson(Map<String, dynamic> payload) async {
    final sessionManager = SessionManager();
    var k = await sessionManager.getString('shop_key_b64');
    if (k == null) {
      // Generate a shop key if missing (for backward compatibility)
      print('DEBUG: No shop key found, generating new one');
      k = CryptoBox.generateShopKey();
      await sessionManager.setString('shop_key_b64', k);
      await sessionManager.setInt('shop_key_version', 1);
    }
    final jsonText = jsonEncode(payload);
    return CryptoBox.encryptWithShopKey(jsonText: jsonText, shopKeyB64: k);
  }

  /// Decrypts if name suggests encrypted; otherwise returns original text.
  static Future<Map<String, dynamic>> decodeFromDrive({
    required String fileName,
    required String content,
  }) async {
    if (isEncryptedName(fileName)) {
      final sessionManager = SessionManager();
      final k = await sessionManager.getString('shop_key_b64');
      if (k == null) {
        throw Exception(
          'This file is encrypted, but no shop key is present. Ask owner to re-share.',
        );
      }
      final clear = await CryptoBox.decryptWithShopKey(
        encB64: content,
        shopKeyB64: k,
      );
      return jsonDecode(clear) as Map<String, dynamic>;
    } else {
      // plaintext legacy support
      return jsonDecode(content) as Map<String, dynamic>;
    }
  }
}
