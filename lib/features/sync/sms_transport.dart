import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:telephony/telephony.dart';

/// Lightweight identity for a peer device (Admin or Sales).
class SmsPeer {
  final String deviceId;
  final String displayName;
  final String phoneNumber;

  const SmsPeer({
    required this.deviceId,
    required this.displayName,
    required this.phoneNumber,
  });
}

class SmsConfig {
  final String selfDeviceId;
  final String shopShortId;
  const SmsConfig({required this.selfDeviceId, required this.shopShortId});
}

/// Same envelope concept as email, but reconstructed from multipart SMS.
class SmsDeltaEnvelope {
  final String shopShortId;
  final String fromDevice;
  final String toDevice;
  final int ts; // UTC ms
  final int seq; // 1-based
  final int total; // number of chunks
  final Uint8List nonce; // base64-decoded from header
  final Uint8List cipher; // base64-decoded body
  final String smsId; // sms message id if available

  SmsDeltaEnvelope({
    required this.shopShortId,
    required this.fromDevice,
    required this.toDevice,
    required this.ts,
    required this.seq,
    required this.total,
    required this.nonce,
    required this.cipher,
    required this.smsId,
  });
}

abstract class SmsTransport {
  /// Sends an encrypted delta as one or more SMS messages.
  /// Each chunk is formatted as:
  /// QSK|1|<shop>|<from>|<to>|<seq>/<tot>|<ts>|<nonceB64>|<cipherB64>
  Future<void> sendDelta({
    required SmsConfig config,
    required SmsPeer toPeer,
    required int ts,
    required List<Uint8List> encryptedChunks, // each = nonce(24)||cipher
  });

  /// Watches incoming SMS and yields envelopes as they arrive.
  Stream<SmsDeltaEnvelope> watchIncoming({required SmsConfig config});
}

class SmsTransportImpl implements SmsTransport {
  final Telephony _telephony = Telephony.instance;

  @override
  Future<void> sendDelta({
    required SmsConfig config,
    required SmsPeer toPeer,
    required int ts,
    required List<Uint8List> encryptedChunks,
  }) async {
    final total = encryptedChunks.length;
    for (var i = 0; i < total; i++) {
      final chunk = encryptedChunks[i];
      if (chunk.length < 25) {
        throw Exception('Encrypted chunk too small for SMS');
      }
      final nonce = chunk.sublist(0, 24);
      final cipher = chunk.sublist(24);
      final payload = _format(
        shop: config.shopShortId,
        from: config.selfDeviceId,
        to: toPeer.deviceId,
        seq: i + 1,
        total: total,
        ts: ts,
        nonceB64: base64Encode(nonce),
        cipherB64: base64Encode(cipher),
      );
      // Send as multipart if needed; plugin handles splitting.
      await _telephony.sendSms(
        to: toPeer.phoneNumber,
        message: payload,
        isMultipart: payload.length > 160,
      );
    }
  }

  @override
  Stream<SmsDeltaEnvelope> watchIncoming({required SmsConfig config}) async* {
    // Buffer for reassembly: key = composite (shop|from|to|ts)
    final Map<String, _Collector> collectors = {};

    final controller = StreamController<SmsDeltaEnvelope>(
      onCancel: () {
        collectors.clear();
      },
    );

    _telephony.listenIncomingSms(
      onNewMessage: (SmsMessage msg) {
        final body = msg.body ?? '';
        if (!body.startsWith('QSK|')) return;
        final parsed = _parse(body);
        if (parsed == null) return;
        if (parsed.shopShortId != config.shopShortId) return;

        final key =
            '${parsed.shopShortId}|${parsed.fromDevice}|${parsed.toDevice}|${parsed.ts}';
        final c = collectors.putIfAbsent(
          key,
          () => _Collector(total: parsed.total),
        );
        c.addPart(parsed.seq, parsed);

        // Yield each part immediately for upper-layer decryption if desired.
        controller.add(
          SmsDeltaEnvelope(
            shopShortId: parsed.shopShortId,
            fromDevice: parsed.fromDevice,
            toDevice: parsed.toDevice,
            ts: parsed.ts,
            seq: parsed.seq,
            total: parsed.total,
            nonce: parsed.nonce,
            cipher: parsed.cipher,
            smsId: msg.id?.toString() ?? '',
          ),
        );

        if (c.isComplete) {
          collectors.remove(key);
        }
      },
      listenInBackground: true,
    );

    yield* controller.stream;
  }

  String _format({
    required String shop,
    required String from,
    required String to,
    required int seq,
    required int total,
    required int ts,
    required String nonceB64,
    required String cipherB64,
  }) {
    // Keep header compact; body is base64 cipher
    return 'QSK|1|$shop|$from|$to|$seq/$total|$ts|$nonceB64|$cipherB64';
  }

  _Parsed? _parse(String body) {
    // QSK|1|<shop>|<from>|<to>|<seq>/<tot>|<ts>|<nonceB64>|<cipherB64>
    final parts = body.split('|');
    if (parts.length < 9) return null;
    if (parts[0] != 'QSK') return null;
    final version = parts[1];
    if (version != '1') return null;

    final shop = parts[2];
    final from = parts[3];
    final to = parts[4];

    final seqTot = parts[5].split('/');
    if (seqTot.length != 2) return null;
    final seq = int.tryParse(seqTot[0]) ?? 1;
    final total = int.tryParse(seqTot[1]) ?? 1;

    final ts =
        int.tryParse(parts[6]) ?? DateTime.now().toUtc().millisecondsSinceEpoch;

    try {
      final nonce = base64Decode(parts[7]);
      final cipher = base64Decode(parts[8]);
      return _Parsed(
        shopShortId: shop,
        fromDevice: from,
        toDevice: to,
        ts: ts,
        seq: seq,
        total: total,
        nonce: Uint8List.fromList(nonce),
        cipher: Uint8List.fromList(cipher),
      );
    } catch (_) {
      return null;
    }
  }
}

class _Collector {
  final int total;
  final Map<int, _Parsed> parts = {};
  _Collector({required this.total});
  void addPart(int seq, _Parsed p) => parts[seq] = p;
  bool get isComplete => parts.length >= total;
}

class _Parsed {
  final String shopShortId;
  final String fromDevice;
  final String toDevice;
  final int ts;
  final int seq;
  final int total;
  final Uint8List nonce;
  final Uint8List cipher;
  _Parsed({
    required this.shopShortId,
    required this.fromDevice,
    required this.toDevice,
    required this.ts,
    required this.seq,
    required this.total,
    required this.nonce,
    required this.cipher,
  });
}
