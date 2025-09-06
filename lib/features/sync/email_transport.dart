import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:enough_mail/enough_mail.dart';
import 'package:intl/intl.dart';

import 'sync_engine.dart';

/// Lightweight identity for a peer device (Admin or Sales).
class Peer {
  final String deviceId;
  final String displayName;
  final String emailAddress;

  const Peer({
    required this.deviceId,
    required this.displayName,
    required this.emailAddress,
  });
}

/// Configuration for SMTP (send) and IMAP (receive).
class EmailConfig {
  // SMTP
  final String smtpHost;
  final int smtpPort; // usually 465 (SSL) or 587 (STARTTLS)
  final bool smtpUseSsl;
  final String smtpUsername;
  final String smtpPassword; // store via platform keystore

  // IMAP
  final String imapHost;
  final int imapPort; // usually 993
  final bool imapUseSsl;
  final String imapUsername;
  final String imapPassword;

  // Mailbox folder to poll for sync messages
  final String inboxFolder; // e.g., 'INBOX'
  // Optional: folder to move processed messages to
  final String processedFolder; // e.g., 'Processed' (auto-create if missing)

  const EmailConfig({
    required this.smtpHost,
    required this.smtpPort,
    required this.smtpUseSsl,
    required this.smtpUsername,
    required this.smtpPassword,
    required this.imapHost,
    required this.imapPort,
    required this.imapUseSsl,
    required this.imapUsername,
    required this.imapPassword,
    this.inboxFolder = 'INBOX',
    this.processedFolder = 'Processed',
  });
}

/// Encrypted envelope as it travels over email.
/// The app handles parsing MIME parts to extract this.
class DeltaEnvelope {
  final String shopShortId;
  final String direction; // 'UP' (Sales->Admin) or 'DOWN' (Admin->Sales)
  final String fromDevice;
  final String toDevice;
  final int ts; // UTC ms
  final int seq; // 1-based
  final int total; // number of chunks
  final Uint8List nonce;
  final Uint8List cipher; // encrypted payload (see spec)
  final String messageId; // provider message-id for dedupe/reference

  DeltaEnvelope({
    required this.shopShortId,
    required this.direction,
    required this.fromDevice,
    required this.toDevice,
    required this.ts,
    required this.seq,
    required this.total,
    required this.nonce,
    required this.cipher,
    required this.messageId,
  });
}

/// Contract for email transport; implementation lives in this file.
abstract class EmailTransport {
  Future<void> sendDelta({
    required EmailConfig config,
    required Peer toPeer,
    required String shopShortId,
    required Delta delta,
    required List<Uint8List> encryptedChunks, // [nonce||cipher] pairs per chunk
  });

  /// Watches the IMAP inbox for new QSK messages, parses them into envelopes.
  /// Caller is responsible for decryption + applying via SyncEngine.
  Stream<DeltaEnvelope> watchInbox({
    required EmailConfig config,
    required String shopShortId,
    Duration pollEvery = const Duration(minutes: 2),
    bool moveProcessedToFolder = true,
  });

  /// One-shot fetch (useful on app start or manual refresh).
  Future<List<DeltaEnvelope>> fetchNow({
    required EmailConfig config,
    required String shopShortId,
    bool moveProcessedToFolder = true,
  });
}

/// Default implementation using enough_mail.
class EmailTransportImpl implements EmailTransport {
  static const _mimeType = 'application/vnd.qudris.qsk';

  /// Subject format:
  /// QSK/<shopShortId>/<dir>/<deviceId>/<yyyymmddThhmmssZ>/<seq>/<total>
  String _buildSubject({
    required String shopShortId,
    required String dir,
    required String deviceId,
    required int ts,
    required int seq,
    required int total,
  }) {
    final iso = DateFormat(
      "yyyyMMdd'T'HHmmss'Z'",
    ).format(DateTime.fromMillisecondsSinceEpoch(ts, isUtc: true));
    return 'QSK/$shopShortId/$dir/$deviceId/$iso/$seq/$total';
  }

  @override
  Future<void> sendDelta({
    required EmailConfig config,
    required Peer toPeer,
    required String shopShortId,
    required Delta delta,
    required List<Uint8List> encryptedChunks,
  }) async {
    final client = SmtpClient('qsk-smtp');
    try {
      await client.connectToServer(
        config.smtpHost,
        config.smtpPort,
        isSecure: config.smtpUseSsl,
      );
      final authRes = await client.login(
        config.smtpUsername,
        config.smtpPassword,
      );
      if (!authRes.isAuthenticated) {
        throw Exception('SMTP authentication failed');
      }

      final total = encryptedChunks.length;
      for (var i = 0; i < total; i++) {
        final chunk = encryptedChunks[i];
        // Expect first 24 bytes nonce (XChaCha20) + rest cipher
        if (chunk.length < 25) throw Exception('Encrypted chunk too small');
        final nonce = chunk.sublist(0, 24);
        final cipher = chunk.sublist(24);

        final subject = _buildSubject(
          shopShortId: shopShortId,
          dir: delta.fromDevice == toPeer.deviceId ? 'DOWN' : 'UP',
          deviceId: delta.fromDevice,
          ts: delta.ts,
          seq: i + 1,
          total: total,
        );

        final builder = MessageBuilder()
          ..from = [MailAddress('Qudris ShopKeeper', config.smtpUsername)]
          ..to = [MailAddress(toPeer.displayName, toPeer.emailAddress)]
          ..subject = subject
          ..text =
              'QSK delta ${i + 1}/$total' // lightweight body
          ..addBinaryAttachment(
            'delta-${delta.ts}-${i + 1}of$total.qsk',
            cipher, // store only cipher as attachment
            mimeType: _mimeType,
          )
          ..addHeader('X-QSK-Nonce-Base64', _b64(nonce));

        final message = builder.buildMimeMessage();
        await client.sendMessage(message, config.smtpUsername, [
          toPeer.emailAddress,
        ]);
      }
    } finally {
      client.close();
    }
  }

  @override
  Stream<DeltaEnvelope> watchInbox({
    required EmailConfig config,
    required String shopShortId,
    Duration pollEvery = const Duration(minutes: 2),
    bool moveProcessedToFolder = true,
  }) async* {
    // Basic polling implementation; providers may not support IDLE reliably on mobile.
    while (true) {
      final batch = await fetchNow(
        config: config,
        shopShortId: shopShortId,
        moveProcessedToFolder: moveProcessedToFolder,
      );
      for (final env in batch) {
        yield env;
      }
      await Future.delayed(pollEvery);
    }
  }

  @override
  Future<List<DeltaEnvelope>> fetchNow({
    required EmailConfig config,
    required String shopShortId,
    bool moveProcessedToFolder = true,
  }) async {
    final imapClient = ImapClient(isLogEnabled: false);
    final envelopes = <DeltaEnvelope>[];
    try {
      await imapClient.connectToServer(
        config.imapHost,
        config.imapPort,
        isSecure: config.imapUseSsl,
      );
      await imapClient.login(config.imapUsername, config.imapPassword);
      await imapClient.selectMailbox(config.inboxFolder);

      final fetchRes = await imapClient.search('SUBJECT "QSK/$shopShortId/"');
      if (fetchRes.matchingSequence != null &&
          fetchRes.matchingSequence!.isNotEmpty) {
        final messages = await imapClient.fetchMessagesBySequence(
          fetchRes.matchingSequence!,
          'BODY.PEEK[] UID RFC822.SIZE ENVELOPE',
        );

        for (final msg in messages) {
          final mime = msg.decodeMimeMessage();
          if (mime == null) continue;

          final subject = mime.decodeSubject() ?? '';
          final parsed = _parseSubject(subject);
          if (parsed == null) continue;

          // Get Nonce from header
          final nonceB64 = mime.headers['X-QSK-Nonce-Base64'];
          if (nonceB64 == null) continue;
          final nonce = _b64d(nonceB64);

          // Find the qsk attachment (cipher)
          Uint8List? cipher;
          for (final part in mime.allParts) {
            final ct = part.mediaType;
            if (ct?.toLowerCase() == _mimeType) {
              final data = part.decodeContentBinary();
              if (data != null) {
                cipher = data;
                break;
              }
            }
          }
          if (cipher == null) continue;

          envelopes.add(
            DeltaEnvelope(
              shopShortId: parsed.shopShortId,
              direction: parsed.dir,
              fromDevice: parsed.deviceId,
              toDevice:
                  '', // unknown from subject alone; filled after decrypt if needed
              ts: parsed.ts,
              seq: parsed.seq,
              total: parsed.total,
              nonce: nonce,
              cipher: cipher,
              messageId: msg.envelope?.messageId ?? '${msg.uid}',
            ),
          );

          // Move to processed folder (optional)
          if (moveProcessedToFolder) {
            await _ensureMailbox(imapClient, config.processedFolder);
            await imapClient.moveMessage(msg.uid!, config.processedFolder);
          }
        }
      }
    } finally {
      await imapClient.logout();
      await imapClient.disconnect();
    }
    return envelopes;
  }

  // ---- helpers ----

  static String _b64(Uint8List x) => base64Encode(x);
  static Uint8List _b64d(String s) => Uint8List.fromList(base64Decode(s));

  _SubjectParts? _parseSubject(String subject) {
    // QSK/<shopShortId>/<dir>/<deviceId>/<yyyymmddThhmmssZ>/<seq>/<total>
    final parts = subject.split('/');
    if (parts.length != 7) return null;
    if (parts[0] != 'QSK') return null;
    final shop = parts[1];
    final dir = parts[2];
    final deviceId = parts[3];
    final iso = parts[4];
    final seq = int.tryParse(parts[5]) ?? 1;
    final total = int.tryParse(parts[6]) ?? 1;

    DateTime? dt;
    try {
      dt = DateFormat("yyyyMMdd'T'HHmmss'Z'").parseUtc(iso);
    } catch (_) {}
    final ts =
        dt?.millisecondsSinceEpoch ??
        DateTime.now().toUtc().millisecondsSinceEpoch;

    return _SubjectParts(
      shopShortId: shop,
      dir: dir,
      deviceId: deviceId,
      ts: ts,
      seq: seq,
      total: total,
    );
  }

  Future<void> _ensureMailbox(ImapClient client, String name) async {
    final boxes = await client.listMailboxes();
    final exists = boxes.any((b) => b.path.toLowerCase() == name.toLowerCase());
    if (!exists) {
      await client.createMailbox(name);
    }
  }
}

class _SubjectParts {
  final String shopShortId;
  final String dir;
  final String deviceId;
  final int ts;
  final int seq;
  final int total;

  _SubjectParts({
    required this.shopShortId,
    required this.dir,
    required this.deviceId,
    required this.ts,
    required this.seq,
    required this.total,
  });
}
