import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import '../../common/uuid.dart';

/// Payload that Admin generates to invite a Sales user.
/// Contains shop identity and a sealed symmetric key for pairwise encryption.
class InvitePayload {
  final String version; // '1'
  final String shopId;
  final String shopShortId; // short code (display)
  final String adminDeviceId;
  final String userId; // Sales user id (pre-created)
  final String username; // chosen by Admin
  final String phone; // Sales phone
  final String? email; // optional
  final String sealedKeyBase64; // sealed pairwise key for Admin<->Sales

  InvitePayload({
    required this.version,
    required this.shopId,
    required this.shopShortId,
    required this.adminDeviceId,
    required this.userId,
    required this.username,
    required this.phone,
    required this.email,
    required this.sealedKeyBase64,
  });

  Map<String, dynamic> toJson() => {
    'v': version,
    'shopId': shopId,
    'shopShortId': shopShortId,
    'adminDeviceId': adminDeviceId,
    'userId': userId,
    'username': username,
    'phone': phone,
    'email': email,
    'sealedKey': sealedKeyBase64,
  };

  static InvitePayload fromJson(Map<String, dynamic> j) => InvitePayload(
    version: j['v'] as String,
    shopId: j['shopId'] as String,
    shopShortId: j['shopShortId'] as String,
    adminDeviceId: j['adminDeviceId'] as String,
    userId: j['userId'] as String,
    username: j['username'] as String,
    phone: j['phone'] as String,
    email: j['email'] as String?,
    sealedKeyBase64: j['sealedKey'] as String,
  );

  String encodeQrString() =>
      'QSKINV.${base64UrlEncode(utf8.encode(jsonEncode(toJson())))}';
  static InvitePayload? tryDecode(String s) {
    if (!s.startsWith('QSKINV.')) return null;
    final b64 = s.substring(7);
    final bytes = base64Url.decode(b64);
    final j = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    return InvitePayload.fromJson(j);
  }
}

/// Generates a new pairwise key and a sealed envelope for the Sales device.
/// For first cut we seal with a one-time pre-shared code displayed as QR text (simple).
class InviteFactory {
  /// Generates a pseudo shopShortId from shopId.
  static String shortId(String shopId) => shopId.substring(0, 6);

  /// Create an InvitePayload. For now, we seal key with a one-time passphrase (OTP string).
  static Future<InvitePayload> create({
    required String shopId,
    required String adminDeviceId,
    required String username,
    required String phone,
    String? email,
    required String
    oneTimePassphrase, // shown alongside the QR (sales must enter it)
  }) async {
    final userId = newId();
    final shopShort = shortId(shopId);
    // Pairwise symmetric key (32 bytes)
    final keyBytes = SecretKey.randomBytes(32);
    final keyRaw = await keyBytes.extractBytes();

    // Derive an AEAD key from the passphrase (NOT for production—replace with ECDH later)
    final kdf = Sha256();
    final kdfBytes = await kdf.hash(utf8.encode(oneTimePassphrase));
    final sealed = await _aeadSeal(keyRaw, kdfBytes.bytes);

    return InvitePayload(
      version: '1',
      shopId: shopId,
      shopShortId: shopShort,
      adminDeviceId: adminDeviceId,
      userId: userId,
      username: username,
      phone: phone,
      email: email,
      sealedKeyBase64: base64Encode(sealed),
    );
  }

  /// Sales opens the sealed key using the same passphrase.
  static Future<List<int>> openPairKey({
    required InvitePayload payload,
    required String oneTimePassphrase,
  }) async {
    final kdf = Sha256();
    final kdfBytes = await kdf.hash(utf8.encode(oneTimePassphrase));
    final sealed = base64Decode(payload.sealedKeyBase64);
    final key = await _aeadOpen(sealed, kdfBytes.bytes);
    return key;
  }

  static final Cipher _cipher = AesGcm.with256bits();
  static Future<List<int>> _aeadSeal(List<int> plain, List<int> key) async {
    final secretKey = SecretKey(key.sublist(0, 32));
    final nonce = SecretKey.randomBytes(12);
    final n = await nonce.extractBytes();
    final sb = await _cipher.encrypt(plain, secretKey: secretKey, nonce: n);
    return [...n, ...sb.cipherText, ...sb.mac.bytes];
  }

  static Future<List<int>> _aeadOpen(List<int> sealed, List<int> key) async {
    if (sealed.length < 12 + 16) {
      throw Exception('sealed too short');
    }
    final secretKey = SecretKey(key.sublist(0, 32));
    final nonce = sealed.sublist(0, 12);
    final rest = sealed.sublist(12);
    final cipherText = rest.sublist(0, rest.length - 16);
    final mac = Mac(rest.sublist(rest.length - 16));
    final plain = await _cipher.decrypt(
      SecretBox(cipherText, nonce: nonce, mac: mac),
      secretKey: secretKey,
    );
    return plain;
  }
}
