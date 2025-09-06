import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../users/join_shop_page.dart';

class StartPage extends StatelessWidget {
  const StartPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Qudris ShopKeeper')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            const Text(
              'Welcome',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Choose how this device will be used. You can change later in Settings.',
            ),
            const SizedBox(height: 24),
            Card(
              child: ListTile(
                title: const Text('I am the Admin (Shop Owner)'),
                subtitle: const Text(
                  'Create shop, manage items, invite sales users',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.go('/admin'),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                title: const Text('I am a Sales user'),
                subtitle: const Text('Record sales, see stock on hand'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const JoinShopPage())),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
