import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../common/uuid.dart';
import 'invite.dart';
import 'invite_qr_page.dart';

class UsersPage extends StatelessWidget {
  const UsersPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Stub UI. Cursor: wire to local DB.
    return Scaffold(
      appBar: AppBar(title: const Text('Users')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          showDialog(context: context, builder: (_) => const _InviteDialog());
        },
        label: const Text('Add Sales User'),
        icon: const Icon(Icons.person_add),
      ),
      body: const Center(child: Text('Sales users will appear here')),
    );
  }
}

class _InviteDialog extends StatefulWidget {
  const _InviteDialog();

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
              shopId: 'SHOP-LOCAL',            // TODO: bind real shop id
              adminDeviceId: 'ADMIN-DEVICE',   // TODO: stable admin device id
              username: usernameCtrl.text.trim(),
              phone: phoneCtrl.text.trim(),
              email: emailCtrl.text.trim().isEmpty ? null : emailCtrl.text.trim(),
              oneTimePassphrase: pass,
            );
            if (context.mounted) {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => InviteQrPage(payload: payload, oneTimePassphrase: pass),
              ));
            }
          },
          child: const Text('Create Invite'),
        ),
      ],
    );
  }

}
