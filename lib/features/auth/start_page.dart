import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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
              'ShopKeeper - Your complete inventory and sales management solution.',
            ),
            const SizedBox(height: 24),
            Card(
              child: ListTile(
                title: const Text('Enter ShopKeeper'),
                subtitle: const Text(
                  'Manage inventory, process sales, and track your business',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.go('/admin'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
