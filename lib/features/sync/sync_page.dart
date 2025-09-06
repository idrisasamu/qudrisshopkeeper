import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories.dart';
import '../../data/peers.dart';
import 'email_transport.dart';
import 'sms_transport.dart';
import 'crypto_box.dart';
import '../../common/key_vault.dart';
import 'sync_orchestrator.dart';
import 'email_config_store.dart';
import 'sync_service.dart';
import 'email_config_page.dart';

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
              leading: const Icon(Icons.settings),
              title: const Text('Configure Email'),
              subtitle: const Text('SMTP/IMAP credentials'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const EmailConfigPage())),
            ),
            ListTile(
              leading: const Icon(Icons.email),
              title: const Text('Sync now via Email'),
              subtitle: const Text('Requires SMTP/IMAP to be configured.'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final store = EmailConfigStore();
                final cfg = await store.load();
                if (cfg == null) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Configure Email first.')));
                    return;
                  }
                }

                // TODO: load peers from Users table; for now one example
                final peers = <Peer>[
                  const Peer(deviceId: 'SALES-DEVICE-1', displayName: 'Sales 1', emailAddress: 'sales1@example.com'),
                ];

                final service = ref.read(syncServiceProvider);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Email sync…')));
                await service.syncNowEmail(cfg: cfg!, peers: peers);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Email sync complete.')));
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
                  shopShortId: 'SHOP01', // TODO
                  email: EmailTransportImpl(),
                  sms: SmsTransportImpl(),
                  keyVault: KeyVault(),
                  crypto: CryptoBox(),
                );
                final smsCfg = SmsConfig(
                  selfDeviceId: 'SALES-DEVICE-1',
                  shopShortId: 'SHOP01',
                );
                final peer = SmsPeer(
                  deviceId: 'ADMIN-DEVICE',
                  displayName: 'Admin',
                  phoneNumber: '+10000000000',
                );

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
