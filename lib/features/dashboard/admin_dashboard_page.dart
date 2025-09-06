import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AdminDashboardPage extends StatelessWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: () => context.push('/sync'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: GridView.count(
          crossAxisCount: MediaQuery.of(context).size.width > 600 ? 3 : 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          children: [
            _DashCard(
              title: 'Inventory',
              icon: Icons.inventory_2,
              onTap: () => context.push('/inventory'),
            ),
            _DashCard(
              title: 'New Sale',
              icon: Icons.point_of_sale,
              onTap: () => context.push('/sale/new'),
            ),
            _DashCard(
              title: 'Users',
              icon: Icons.group,
              onTap: () => context.push('/users'),
            ),
            _DashCard(
              title: 'Sync',
              icon: Icons.sync,
              onTap: () => context.push('/sync'),
            ),
            const _DashStat(title: "Today's Sales", value: '—'),
            const _DashStat(title: 'Low Stock', value: '—'),
          ],
        ),
      ),
    );
  }
}

class _DashCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;
  const _DashCard({
    required this.title,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 36),
              const SizedBox(height: 8),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashStat extends StatelessWidget {
  final String title;
  final String value;
  const _DashStat({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Center(
        child: ListTile(
          title: Text(title),
          subtitle: Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}
