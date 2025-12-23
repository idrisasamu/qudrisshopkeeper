import 'dart:convert';
import 'dart:math';
import 'package:cryptography/cryptography.dart';

/// Minimal E2E helper:
/// - AES-GCM(256) for payloads
/// - HKDF-SHA256 to derive keys from short secrets (for invites)
/// - Base64url encoding for portability
class CryptoBox {
  static final _aes = AesGcm.with256bits();
  static final _hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);

  /// Generates 32 random bytes -> base64url (no padding)
  static String randomB64(int lengthBytes) {
    final rnd = Random.secure();
    final bytes = List<int>.generate(lengthBytes, (_) => rnd.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  /// Generate a shop key K_shop (32 bytes, base64url)
  static String generateShopKey() => randomB64(32);

  /// Generate an invite secret (16 bytes, base64url)
  static String generateInviteSecret() => randomB64(16);

  /// Derive a 32-byte key from a short secret using HKDF-SHA256.
  /// saltB64 may be shopId or any stable string (base64url or ascii).
  static Future<SecretKey> deriveKeyFromSecret({
    required String secretB64,
    required String salt,
    int length = 32,
  }) async {
    final secret = base64Url.decode(_pad(secretB64));
    final saltBytes = utf8.encode(salt);
    return _hkdf.deriveKey(
      secretKey: SecretKey(secret),
      nonce: saltBytes,
    );
  }

  /// Encrypt JSON text with K_shop (base64url) -> bytes (base64url)
  static Future<String> encryptWithShopKey({
    required String jsonText,
    required String shopKeyB64,
  }) async {
    final keyBytes = base64Url.decode(_pad(shopKeyB64));
    final secretKey = SecretKey(keyBytes);

    // 12-byte random nonce for AES-GCM
    final nonce = _nextBytes(Random.secure(), 12);
    final secretBox = await _aes.encrypt(
      utf8.encode(jsonText),
      secretKey: secretKey,
      nonce: nonce,
    );
    // Store nonce + cipherText + tag as one blob (cryptography already appends tag)
    final out = <int>[]
      ..addAll(nonce)
      ..addAll(secretBox.cipherText)
      ..addAll(secretBox.mac.bytes);
    return base64UrlEncode(out).replaceAll('=', '');
  }

  /// Decrypt base64url(blob) -> JSON text
  static Future<String> decryptWithShopKey({
    required String encB64,
    required String shopKeyB64,
  }) async {
    final data = base64Url.decode(_pad(encB64));
    if (data.length < 12 + 16) throw Exception('cipher too short');
    final nonce = data.sublist(0, 12);
    final mac = Mac(data.sublist(data.length - 16));
    final cipherText = data.sublist(12, data.length - 16);
    final keyBytes = base64Url.decode(_pad(shopKeyB64));
    final secretKey = SecretKey(keyBytes);

    final clear = await _aes.decrypt(
      SecretBox(cipherText, nonce: nonce, mac: mac),
      secretKey: secretKey,
    );
    return utf8.decode(clear);
  }

  /// Wrap K_shop using an invite secret (for QR/manual onboarding)
  static Future<String> wrapShopKeyForInvite({
    required String shopKeyB64,
    required String inviteSecretB64,
    required String shopIdSalt,
  }) async {
    final kInvite = await deriveKeyFromSecret(
      secretB64: inviteSecretB64,
      salt: shopIdSalt,
    );
    // Encrypt the raw K_shop (base64url string) as JSON for simplicity
    final payload = jsonEncode({'k': shopKeyB64});
    final boxed = await _aes.encrypt(
      utf8.encode(payload),
      secretKey: kInvite,
      nonce: _nextBytes(Random.secure(), 12),
    );
    final out = <int>[]
      ..addAll(boxed.nonce)
      ..addAll(boxed.cipherText)
      ..addAll(boxed.mac.bytes);
    return base64UrlEncode(out).replaceAll('=', '');
  }

  /// Unwrap K_shop from invite secret
  static Future<String> unwrapShopKeyFromInvite({
    required String wrappedB64,
    required String inviteSecretB64,
    required String shopIdSalt,
  }) async {
    final data = base64Url.decode(_pad(wrappedB64));
    if (data.length < 12 + 16) throw Exception('invite cipher too short');
    final nonce = data.sublist(0, 12);
    final mac = Mac(data.sublist(data.length - 16));
    final cipherText = data.sublist(12, data.length - 16);

    final kInvite = await deriveKeyFromSecret(
      secretB64: inviteSecretB64,
      salt: shopIdSalt,
    );
    final clear = await AesGcm.with256bits().decrypt(
      SecretBox(cipherText, nonce: nonce, mac: mac),
      secretKey: kInvite,
    );
    final obj = jsonDecode(utf8.decode(clear)) as Map<String, dynamic>;
    final kShop = obj['k'] as String?;
    if (kShop == null) throw Exception('wrapped payload missing k');
    return kShop;
  }

  // ----- helpers -----
  static List<int> _nextBytes(Random r, int n) =>
      List<int>.generate(n, (_) => r.nextInt(256));
      
  static String _pad(String s) {
    // restore missing '=' padding for base64url
    final mod = s.length % 4;
    return mod == 0 ? s : s + '=' * (4 - mod);
  }
}