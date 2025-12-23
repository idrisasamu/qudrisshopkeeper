import 'dart:convert';
import 'dart:math';
import 'package:cryptography/cryptography.dart';

class PasswordHasher {
  static const _algoName = 'pbkdf2-sha256';
  static const _iterations = 150000;
  static const _saltLen = 16;
  static const _dkLen = 32;

  static Future<(String hashB64, String saltB64, String kdf)> hashPassword(
    String password, {
    int iterations = _iterations,
  }) async {
    final rnd = Random.secure();
    final salt = List<int>.generate(_saltLen, (_) => rnd.nextInt(256));
    final algo = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: iterations,
      bits: _dkLen * 8,
    );
    final secret = SecretKey(utf8.encode(password));
    final key = await algo.deriveKey(secretKey: secret, nonce: salt);
    final bytes = await key.extractBytes();
    return (
      base64UrlEncode(bytes),
      base64UrlEncode(salt),
      '$_algoName/$iterations',
    );
  }

  static Future<(String hashB64, String saltB64, String kdf)>
  hashDefaultPin0000() {
    return hashPassword('0000');
  }

  static Future<bool> verify(
    String password,
    String hashB64,
    String saltB64,
    String kdf,
  ) async {
    final parts = kdf.split('/');
    final iterations =
        int.tryParse(parts.elementAtOrNull(1) ?? '') ?? _iterations;
    final salt = base64Url.decode(saltB64);
    final algo = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: iterations,
      bits: _dkLen * 8,
    );
    final secret = SecretKey(utf8.encode(password));
    final key = await algo.deriveKey(secretKey: secret, nonce: salt);
    final bytes = await key.extractBytes();
    return base64UrlEncode(bytes) == hashB64;
  }

  /// Flexible verification that handles different hash formats
  static Future<bool> verifyFlexible(
    String password,
    String hash, {
    String? salt,
    String? kdf,
  }) async {
    // If we have separate fields, use the standard verification
    if (salt != null && salt.isNotEmpty && kdf != null && kdf.isNotEmpty) {
      return verify(password, hash, salt, kdf);
    }

    // If hash contains $, treat as encoded string (e.g., "argon2id$<salt>$<hash>")
    if (hash.contains(r'$')) {
      // For now, fall back to legacy verification
      // In a real implementation, you'd parse the encoded format here
      return verifyLegacy(password, hash);
    }

    // Last resort: try to verify as a single hash field
    return verifyLegacy(password, hash);
  }

  /// Legacy verification for single-field hashes
  static Future<bool> verifyLegacy(String password, String hash) async {
    // This is a placeholder - in a real implementation, you'd handle
    // different hash formats like bcrypt, argon2, etc.
    // For now, just return false to indicate verification failed
    print(
      'DEBUG: PasswordHasher.verifyLegacy() - unsupported hash format: $hash',
    );
    return false;
  }

  /// Verifies against legacy base64url hash (no salt) - matches your original format
  static Future<bool> verifyLegacyBase64(
    String password,
    String hashB64Url,
  ) async {
    try {
      // Recreate the same PBKDF2 process as hashPassword but with a fixed salt
      // This matches the original implementation that didn't store salt separately
      final algo = Pbkdf2(
        macAlgorithm: Hmac.sha256(),
        iterations: _iterations,
        bits: _dkLen * 8,
      );

      // Use a fixed salt for legacy compatibility (this is a security compromise)
      // In production, you should migrate all users to the new format
      final fixedSalt = List<int>.generate(
        _saltLen,
        (i) => i,
      ); // Simple fixed salt
      final secret = SecretKey(utf8.encode(password));
      final key = await algo.deriveKey(secretKey: secret, nonce: fixedSalt);
      final bytes = await key.extractBytes();
      final expected = base64UrlEncode(bytes);

      return constantTimeCompare(expected, hashB64Url);
    } catch (e) {
      print('DEBUG: PasswordHasher.verifyLegacyBase64() - error: $e');
      return false;
    }
  }

  static bool constantTimeCompare(String a, String b) {
    if (a.length != b.length) return false;
    var r = 0;
    for (var i = 0; i < a.length; i++) {
      r |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return r == 0;
  }
}
