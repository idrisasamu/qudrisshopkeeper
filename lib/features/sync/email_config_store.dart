import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'email_transport.dart';

class EmailConfigStore {
  static const _key = 'qsk.email.config';
  final FlutterSecureStorage _sec = const FlutterSecureStorage();

  Future<void> save(EmailConfig cfg) async {
    await _sec.write(key: _key, value: jsonEncode({
      'smtpHost': cfg.smtpHost,
      'smtpPort': cfg.smtpPort,
      'smtpUseSsl': cfg.smtpUseSsl,
      'smtpUsername': cfg.smtpUsername,
      'smtpPassword': cfg.smtpPassword,
      'imapHost': cfg.imapHost,
      'imapPort': cfg.imapPort,
      'imapUseSsl': cfg.imapUseSsl,
      'imapUsername': cfg.imapUsername,
      'imapPassword': cfg.imapPassword,
      'inboxFolder': cfg.inboxFolder,
      'processedFolder': cfg.processedFolder,
    }));
  }

  Future<EmailConfig?> load() async {
    final v = await _sec.read(key: _key);
    if (v == null) return null;
    final j = jsonDecode(v) as Map<String, dynamic>;
    return EmailConfig(
      smtpHost: j['smtpHost'],
      smtpPort: j['smtpPort'],
      smtpUseSsl: j['smtpUseSsl'],
      smtpUsername: j['smtpUsername'],
      smtpPassword: j['smtpPassword'],
      imapHost: j['imapHost'],
      imapPort: j['imapPort'],
      imapUseSsl: j['imapUseSsl'],
      imapUsername: j['imapUsername'],
      imapPassword: j['imapPassword'],
      inboxFolder: j['inboxFolder'],
      processedFolder: j['processedFolder'],
    );
  }
}
