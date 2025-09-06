import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'invite.dart';

class InviteQrPage extends StatelessWidget {
  final InvitePayload payload;
  final String oneTimePassphrase; // show to Sales to type after scanning

  const InviteQrPage({
    super.key,
    required this.payload,
    required this.oneTimePassphrase,
  });

  @override
  Widget build(BuildContext context) {
    final qrData = payload.encodeQrString();
    return Scaffold(
      appBar: AppBar(title: const Text('Sales Invite')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            QrImageView(data: qrData, version: QrVersions.auto, size: 280),
            const SizedBox(height: 16),
            SelectableText('Passphrase: $oneTimePassphrase'),
            const SizedBox(height: 8),
            const Text(
              'Ask the Sales user to scan the QR and enter the passphrase to complete setup.',
              textAlign: TextAlign.center,
            ),
            const Spacer(),
            FilledButton.icon(
              icon: const Icon(Icons.ios_share),
              label: const Text('Share invite as file'),
              onPressed: () {
                // TODO(Cursor): write `.qsk-invite` file to storage/share sheet
              },
            ),
          ],
        ),
      ),
    );
  }
}
