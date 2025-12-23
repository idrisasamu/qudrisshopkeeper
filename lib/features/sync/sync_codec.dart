import 'dart:convert';
import 'dart:math';
import 'package:cryptography/cryptography.dart';

/// Simple encryption/decryption for sync data
class SyncCodec {
  static final _aes = AesGcm.with256bits();
  static final _hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);

  /// Generate a random 32-byte key (base64url)
  static String generateKey() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  /// Derive key from password using HKDF
  static Future<SecretKey> deriveKey(String password, String salt) async {
    final passwordBytes = utf8.encode(password);
    final saltBytes = utf8.encode(salt);
    return _hkdf.deriveKey(
      secretKey: SecretKey(passwordBytes),
      nonce: saltBytes,
    );
  }

  /// Encrypt string with given key
  static Future<String> encryptString(String plaintext, {String? key}) async {
    final keyToUse = key ?? generateKey();
    final keyBytes = base64Url.decode(_padBase64Url(keyToUse));
    final secretKey = SecretKey(keyBytes);

    // Generate random nonce
    final random = Random.secure();
    final nonce = List<int>.generate(12, (_) => random.nextInt(256));

    final secretBox = await _aes.encrypt(
      utf8.encode(plaintext),
      secretKey: secretKey,
      nonce: nonce,
    );

    // Combine nonce + ciphertext + tag
    final combined = <int>[]
      ..addAll(nonce)
      ..addAll(secretBox.cipherText)
      ..addAll(secretBox.mac.bytes);

    return base64UrlEncode(combined).replaceAll('=', '');
  }

  /// Decrypt string with given key
  static Future<String> decryptString(String encrypted, {String? key}) async {
    if (key == null) {
      throw ArgumentError('Key is required for decryption');
    }

    final keyBytes = base64Url.decode(_padBase64Url(key));
    final secretKey = SecretKey(keyBytes);

    final combined = base64Url.decode(_padBase64Url(encrypted));

    // Extract nonce (first 12 bytes)
    final nonce = combined.sublist(0, 12);

    // Extract ciphertext and tag (remaining bytes)
    final ciphertext = combined.sublist(12, combined.length - 16);
    final tag = combined.sublist(combined.length - 16);

    final secretBox = SecretBox(ciphertext, nonce: nonce, mac: Mac(tag));

    final decrypted = await _aes.decrypt(secretBox, secretKey: secretKey);
    return utf8.decode(decrypted);
  }

  /// Pad base64url string to proper length
  static String _padBase64Url(String input) {
    final remainder = input.length % 4;
    if (remainder == 0) return input;
    return input + '=' * (4 - remainder);
  }
}
