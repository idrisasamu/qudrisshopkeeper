import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories.dart';
import '../../data/peers.dart';
import 'email_transport.dart';
import 'sms_transport.dart';
import 'crypto_box.dart';
import '../../common/key_vault.dart';
import 'sync_orchestrator.dart';

class SyncPage extends ConsumerWidget {
  const SyncPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sync = ref.read(syncEngineProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Sync')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            const ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('Status'),
              subtitle: Text('Manual sync demo with Email/SMS'),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.email),
              title: const Text('Sync now via Email'),
              subtitle: const Text('Requires SMTP/IMAP to be configured.'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final orchestrator = SyncOrchestrator(
                  engine: sync,
                  selfDeviceId: 'ADMIN-DEVICE', // TODO: bind device id
                  shopShortId: 'SHOP01',        // TODO: bind
                  email: EmailTransportImpl(),
                  sms: SmsTransportImpl(),
                  keyVault: KeyVault(),
                  crypto: CryptoBox(),
                );

                // TODO: load email config from storage/UI
                final cfg = EmailConfig(
                  smtpHost: 'smtp.example.com',
                  smtpPort: 587,
                  smtpUseSsl: false,
                  smtpUsername: 'user@example.com',
                  smtpPassword: 'app-password',
                  imapHost: 'imap.example.com',
                  imapPort: 993,
                  imapUseSsl: true,
                  imapUsername: 'user@example.com',
                  imapPassword: 'app-password',
                );

                // Example peer (Sales)
                final peer = Peer(
                  deviceId: 'SALES-DEVICE-1',
                  displayName: 'Sales 1',
                  emailAddress: 'sales1@example.com',
                );

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Sending email delta…')),
                );
                await orchestrator.sendEmailDelta(cfg: cfg, peer: peer);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Email delta sent.')),
                  );
                }
              },
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.sms),
              title: const Text('Send SMS fallback now'),
              subtitle: const Text('Uses encrypted small chunks.'),
              onTap: () async {
                final orchestrator = SyncOrchestrator(
                  engine: ref.read(syncEngineProvider),
                  selfDeviceId: 'SALES-DEVICE-1', // TODO
                  shopShortId: 'SHOP01',          // TODO
                  email: EmailTransportImpl(),
                  sms: SmsTransportImpl(),
                  keyVault: KeyVault(),
                  crypto: CryptoBox(),
                );
                final smsCfg = SmsConfig(selfDeviceId: 'SALES-DEVICE-1', shopShortId: 'SHOP01');
                final peer = SmsPeer(deviceId: 'ADMIN-DEVICE', displayName: 'Admin', phoneNumber: '+10000000000');

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Sending SMS delta…')),
                );
                await orchestrator.sendSmsDelta(cfg: smsCfg, peer: peer);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('SMS delta sent.')),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
