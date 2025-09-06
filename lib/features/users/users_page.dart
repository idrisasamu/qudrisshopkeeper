import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../common/uuid.dart';
import '../../data/peer_store.dart';
import '../../data/peers.dart';
import '../../app/main.dart';
import 'invite.dart';
import 'invite_qr_page.dart';

class UsersPage extends ConsumerWidget {
  const UsersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Stub UI. Cursor: wire to local DB.
    return Scaffold(
      appBar: AppBar(title: const Text('Users')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          showDialog(context: context, builder: (_) => _InviteDialog(ref: ref));
        },
        label: const Text('Add Sales User'),
        icon: const Icon(Icons.person_add),
      ),
      body: const Center(child: Text('Sales users will appear here')),
    );
  }
}

class _InviteDialog extends StatefulWidget {
  final WidgetRef ref;
  const _InviteDialog({required this.ref});

  @override
  State<_InviteDialog> createState() => _InviteDialogState();
}

class _InviteDialogState extends State<_InviteDialog> {
  final usernameCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final emailCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Invite Sales User'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: usernameCtrl,
            decoration: const InputDecoration(
              labelText: 'Username (chosen by Admin)',
            ),
          ),
          TextField(
            controller: phoneCtrl,
            decoration: const InputDecoration(labelText: 'Phone number'),
          ),
          TextField(
            controller: emailCtrl,
            decoration: const InputDecoration(labelText: 'Email (optional)'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () async {
            final pass = newId().substring(0, 8); // one-time passphrase (short)
            final payload = await InviteFactory.create(
              shopId: 'SHOP-LOCAL', // TODO: bind real shop id
              adminDeviceId: 'ADMIN-DEVICE', // TODO: stable admin device id
              username: usernameCtrl.text.trim(),
              phone: phoneCtrl.text.trim(),
              email: emailCtrl.text.trim().isEmpty
                  ? null
                  : emailCtrl.text.trim(),
              oneTimePassphrase: pass,
            );
            if (context.mounted) {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      InviteQrPage(payload: payload, oneTimePassphrase: pass),
                ),
              );
              
              // Also persist peer
              final db = widget.ref.read(dbProvider);
              final ps = PeerStore(db);
              await ps.savePeer(PeerInfo(
                deviceId: payload.userId, // sales user id
                username: usernameCtrl.text.trim(),
                phone: phoneCtrl.text.trim(),
                email: emailCtrl.text.trim().isEmpty ? null : emailCtrl.text.trim(),
                isAdmin: false,
              ));
            }
          },
          child: const Text('Create Invite'),
        ),
      ],
    );
  }
}
