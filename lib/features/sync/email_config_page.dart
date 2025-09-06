import 'package:flutter/material.dart';

class EmailConfigPage extends StatefulWidget {
  const EmailConfigPage({super.key});

  @override
  State<EmailConfigPage> createState() => _EmailConfigPageState();
}

class _EmailConfigPageState extends State<EmailConfigPage> {
  final smtpHost = TextEditingController();
  final smtpPort = TextEditingController(text: '587');
  bool smtpSsl = false;
  final smtpUser = TextEditingController();
  final smtpPass = TextEditingController();

  final imapHost = TextEditingController();
  final imapPort = TextEditingController(text: '993');
  bool imapSsl = true;
  final imapUser = TextEditingController();
  final imapPass = TextEditingController();

  final inboxFolder = TextEditingController(text: 'INBOX');
  final processedFolder = TextEditingController(text: 'Processed');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Email Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'SMTP (Send)',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          TextField(
            controller: smtpHost,
            decoration: const InputDecoration(labelText: 'Host'),
          ),
          TextField(
            controller: smtpPort,
            decoration: const InputDecoration(labelText: 'Port'),
            keyboardType: TextInputType.number,
          ),
          SwitchListTile(
            value: smtpSsl,
            onChanged: (v) => setState(() => smtpSsl = v),
            title: const Text('Use SSL'),
          ),
          TextField(
            controller: smtpUser,
            decoration: const InputDecoration(labelText: 'Username'),
          ),
          TextField(
            controller: smtpPass,
            decoration: const InputDecoration(labelText: 'Password'),
            obscureText: true,
          ),
          const SizedBox(height: 16),
          const Text(
            'IMAP (Receive)',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          TextField(
            controller: imapHost,
            decoration: const InputDecoration(labelText: 'Host'),
          ),
          TextField(
            controller: imapPort,
            decoration: const InputDecoration(labelText: 'Port'),
            keyboardType: TextInputType.number,
          ),
          SwitchListTile(
            value: imapSsl,
            onChanged: (v) => setState(() => imapSsl = v),
            title: const Text('Use SSL'),
          ),
          TextField(
            controller: imapUser,
            decoration: const InputDecoration(labelText: 'Username'),
          ),
          TextField(
            controller: imapPass,
            decoration: const InputDecoration(labelText: 'Password'),
            obscureText: true,
          ),
          const SizedBox(height: 16),
          const Text('Folders', style: TextStyle(fontWeight: FontWeight.bold)),
          TextField(
            controller: inboxFolder,
            decoration: const InputDecoration(labelText: 'Inbox folder'),
          ),
          TextField(
            controller: processedFolder,
            decoration: const InputDecoration(labelText: 'Processed folder'),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () async {
              // TODO(Cursor): persist securely (e.g., flutter_secure_storage) and test connection
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Saved email settings')),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
