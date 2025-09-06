import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../../common/key_vault.dart';
import '../../data/peers.dart';
import 'sync_engine.dart';
import 'crypto_box.dart';
import 'email_transport.dart';
import 'sms_transport.dart';

/// Splits a sealed payload into ~100KB chunks (safe for many email/mobile limits).
List<Uint8List> chunkSealed(Uint8List sealed, {int chunkSize = 100 * 1024}) {
  final chunks = <Uint8List>[];
  int i = 0;
  while (i < sealed.length) {
    final end = (i + chunkSize < sealed.length) ? i + chunkSize : sealed.length;
    chunks.add(Uint8List.fromList(sealed.sublist(i, end)));
    i = end;
  }
  return chunks;
}

class SyncOrchestrator {
  final SyncEngine engine;
  final String selfDeviceId;
  final String shopShortId;
  final EmailTransport email;
  final SmsTransport sms;
  final KeyVault keyVault;
  final CryptoBox crypto;

  SyncOrchestrator({
    required this.engine,
    required this.selfDeviceId,
    required this.shopShortId,
    required this.email,
    required this.sms,
    required this.keyVault,
    required this.crypto,
  });

  /// Send pending ops to a peer via Email.
  Future<void> sendEmailDelta({
    required EmailConfig cfg,
    required Peer peer,
  }) async {
    final key = await keyVault.loadPeerKey(peer.deviceId);
    if (key == null) return;

    final delta = await engine.buildDeltaForPeer(peer.deviceId, maxOps: 200);
    if (delta.ops.isEmpty) return;

    final plain = {
      'protocol': 1,
      'shop_id': shopShortId, // using short id for email subject filtering
      'from_device': selfDeviceId,
      'to_device': peer.deviceId,
      'ts': delta.ts,
      'ops': delta.ops
          .map(
            (o) => {
              'uuid': o.uuid,
              'entity': o.entity,
              'op': o.op,
              'payload': o.payload,
              'ts': o.ts,
              'device_id': o.deviceId,
            },
          )
          .toList(),
    };

    final sealed = await crypto.sealJson(json: plain, keyBytes: key);
    final chunks = chunkSealed(sealed);

    await email.sendDelta(
      config: cfg,
      toPeer: peer,
      shopShortId: shopShortId,
      delta: delta,
      encryptedChunks: chunks,
    );
  }

  /// Poll IMAP and apply incoming deltas.
  Future<void> pollEmail({required EmailConfig cfg}) async {
    final envs = await (email as EmailTransportImpl).fetchNow(
      config: cfg,
      shopShortId: shopShortId,
    );

    for (final env in envs) {
      // We don't yet know peer id until decrypt; try keys sequentially (small peer set).
      // In production, include toDevice in subject or store mapping header.
      final candidateKeys = <List<int>>[];
      // Optionally maintain a registry of peers; here we assume two-way single peer key for demo.
      // You can extend with a small list of known peer device IDs and load keys for each.
      // For demo, skip if none.

      // Attempt open with known keys in vault (not efficient, but fine for MVP small N).
      // Replace with indexing by fromDevice once you trust the subject.
    }
  }

  Future<void> pollEmailApply({
    required EmailConfig cfg,
    required List<Peer> knownPeers,
  }) async {
    final envs = await (email as EmailTransportImpl).fetchNow(
      config: cfg,
      shopShortId: shopShortId,
    );

    for (final env in envs) {
      // Try decrypt with key of each known peer until success.
      bool applied = false;
      for (final peer in knownPeers) {
        final key = await keyVault.loadPeerKey(peer.deviceId);
        if (key == null) continue;

        try {
          // Rebuild sealed = nonce(24) || cipher
          final sealed = Uint8List(env.nonce.length + env.cipher.length)
            ..setAll(0, env.nonce)
            ..setAll(env.nonce.length, env.cipher);
          final plain = await crypto.openToJson(sealed: sealed, keyBytes: key);
          // Validate from/to device
          final fromDev = plain['from_device'] as String? ?? '';
          final toDev = plain['to_device'] as String? ?? '';
          if (toDev.isNotEmpty && toDev != selfDeviceId) continue;

          // Parse ops
          final opsJson = (plain['ops'] as List).cast<Map<String, dynamic>>();
          final ops = opsJson.map((o) => SyncOp(
            uuid: o['uuid'] as String,
            entity: o['entity'] as String,
            op: o['op'] as String,
            payload: Map<String, dynamic>.from(o['payload'] as Map),
            ts: (o['ts'] as num).toInt(),
            deviceId: o['device_id'] as String,
          )).toList();

          await engine.applyRemoteOps(ops);
          applied = true;
          break;
        } catch (_) {
          // try next key
        }
      }
      if (!applied && kDebugMode) {
        // Could not decrypt with known keys; ignore.
      }
    }
  }

  /// SMS send fallback.
  Future<void> sendSmsDelta({
    required SmsConfig cfg,
    required SmsPeer peer,
  }) async {
    final key = await keyVault.loadPeerKey(peer.deviceId);
    if (key == null) return;
    final delta = await engine.buildDeltaForPeer(peer.deviceId, maxOps: 50);
    if (delta.ops.isEmpty) return;

    final plain = {
      'protocol': 1,
      'shop_id': shopShortId,
      'from_device': selfDeviceId,
      'to_device': peer.deviceId,
      'ts': delta.ts,
      'ops': delta.ops
          .map(
            (o) => {
              'uuid': o.uuid,
              'entity': o.entity,
              'op': o.op,
              'payload': o.payload,
              'ts': o.ts,
              'device_id': o.deviceId,
            },
          )
          .toList(),
    };

    final sealed = await crypto.sealJson(json: plain, keyBytes: key);
    final chunks = chunkSealed(sealed, chunkSize: 120); // keep tiny for SMS
    await sms.sendDelta(
      config: cfg,
      toPeer: peer,
      ts: delta.ts,
      encryptedChunks: chunks,
    );
  }
}
