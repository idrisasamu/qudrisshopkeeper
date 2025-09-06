import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'invite.dart';
import '../../common/key_vault.dart';

class JoinShopPage extends StatefulWidget {
  const JoinShopPage({super.key});

  @override
  State<JoinShopPage> createState() => _JoinShopPageState();
}

class _JoinShopPageState extends State<JoinShopPage> {
  final passCtrl = TextEditingController();
  InvitePayload? _payload;
  bool _done = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Join Shop')),
      body: _payload == null ? _scanStep() : _passphraseStep(),
    );
  }

  Widget _scanStep() {
    return Column(
      children: [
        const SizedBox(height: 8),
        const Text('Scan the invite QR from Admin'),
        const SizedBox(height: 8),
        Expanded(
          child: MobileScanner(
            onDetect: (capture) {
              if (_done) return;
              final barcodes = capture.barcodes;
              for (final bc in barcodes) {
                final raw = bc.rawValue ?? '';
                final p = InvitePayload.tryDecode(raw);
                if (p != null) {
                  setState(() => _payload = p);
                  break;
                }
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _passphraseStep() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const Text('Enter the passphrase shown on Admin device'),
          const SizedBox(height: 8),
          TextField(
            controller: passCtrl,
            decoration: const InputDecoration(labelText: 'Passphrase'),
            obscureText: true,
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _completeJoin,
            child: const Text('Complete setup'),
          ),
        ],
      ),
    );
  }

  Future<void> _completeJoin() async {
    if (_payload == null) return;
    final key = await InviteFactory.openPairKey(
      payload: _payload!,
      oneTimePassphrase: passCtrl.text.trim(),
    );
    final kv = KeyVault();
    // Save key under ADMIN device id as peer
    await kv.savePeerKey(_payload!.adminDeviceId, key);
    if (mounted) {
      setState(() => _done = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Shop joined. You can start syncing.')),
      );
      Navigator.pop(context);
    }
  }
}
