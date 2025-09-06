import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';

/// XChaCha20-Poly1305 box for sealing/opening payloads.
/// We encode JSON as UTF-8 before encryption.
/// Output format for callers: nonce(24) || cipher
class CryptoBox {
  final Cipher _cipher = Xchacha20.poly1305Aead();

  /// Seal plaintext JSON with a 32-byte symmetric key.
  Future<Uint8List> sealJson({
    required Map<String, dynamic> json,
    required List<int> keyBytes, // 32 bytes
  }) async {
    final secretKey = SecretKey(keyBytes);
    final nonce = _randomBytes(24);
    final plain = utf8.encode(jsonEncode(json));

    final secretBox = await _cipher.encrypt(
      plain,
      secretKey: secretKey,
      nonce: nonce,
    );
    // Return nonce || ciphertext (ciphertext includes MAC)
    final out = Uint8List(
      nonce.length + secretBox.cipherText.length + secretBox.mac.bytes.length,
    );
    out.setAll(0, nonce);
    out.setAll(24, secretBox.cipherText + secretBox.mac.bytes);
    return out;
  }

  /// Open payload produced by [sealJson].
  Future<Map<String, dynamic>> openToJson({
    required Uint8List sealed,
    required List<int> keyBytes,
  }) async {
    if (sealed.length < 24 + 17) {
      throw Exception('sealed too short');
    }
    final secretKey = SecretKey(keyBytes);
    final nonce = sealed.sublist(0, 24);
    final data = sealed.sublist(24);
    // Split cipherText and mac (16 bytes mac for Poly1305)
    if (data.length < 17) throw Exception('cipher length invalid');
    final cipherText = data.sublist(0, data.length - 16);
    final mac = Mac(data.sublist(data.length - 16));

    final plain = await _cipher.decrypt(
      SecretBox(cipherText, nonce: nonce, mac: mac),
      secretKey: secretKey,
    );
    return jsonDecode(utf8.decode(plain)) as Map<String, dynamic>;
  }

  List<int> _randomBytes(int n) {
    final rnd = SecureRandom();
    return rnd.nextBytes(n);
  }
}
