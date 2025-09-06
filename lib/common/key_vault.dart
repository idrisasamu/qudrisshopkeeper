import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Stores per-peer symmetric keys securely on device.
class KeyVault {
  static const _ns = 'qsk.keys.';
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
}
