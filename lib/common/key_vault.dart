import 'dart:convert';
import 'dart:math';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Stores per-peer symmetric keys securely on device.
class KeyVault {
  static const _ns = 'qsk.keys.';
  static const _shopNs = 'qsk.shop.';
  final FlutterSecureStorage _store = const FlutterSecureStorage();

  Future<void> savePeerKey(String peerDeviceId, List<int> keyBytes) async {
    await _store.write(key: '$_ns$peerDeviceId', value: base64Encode(keyBytes));
  }

  Future<List<int>?> loadPeerKey(String peerDeviceId) async {
    final v = await _store.read(key: '$_ns$peerDeviceId');
    return v != null ? base64Decode(v) : null;
  }

  Future<void> deletePeerKey(String peerDeviceId) async {
    await _store.delete(key: '$_ns$peerDeviceId');
  }

  /// Save shop encryption key
  Future<void> saveShopKey(String shopId, List<int> keyBytes) async {
    await _store.write(key: '$_shopNs$shopId', value: base64Encode(keyBytes));
  }

  /// Load shop encryption key
  Future<List<int>?> getShopKey(String shopId) async {
    final v = await _store.read(key: '$_shopNs$shopId');
    return v != null ? base64Decode(v) : null;
  }

  /// Ensure shop key exists, generate if not
  Future<void> ensureShopKey(String shopId) async {
    final existing = await getShopKey(shopId);
    if (existing == null) {
      // Generate a new 256-bit key using secure random
      final random = Random.secure();
      final keyBytes = List<int>.generate(32, (i) => random.nextInt(256));
      await saveShopKey(shopId, keyBytes);
    }
  }

  /// Delete shop key
  Future<void> deleteShopKey(String shopId) async {
    await _store.delete(key: '$_shopNs$shopId');
  }
}
