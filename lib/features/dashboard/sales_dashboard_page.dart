import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SalesDashboardPage extends StatelessWidget {
  const SalesDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sales')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              child: ListTile(
                leading: const Icon(Icons.point_of_sale),
                title: const Text('New Sale'),
                subtitle: const Text('Scan or search items, set quantity'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/sale/new'),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.inventory),
                title: const Text('Items'),
                subtitle: const Text('View stock on hand'),
                onTap: () => context.push('/inventory'),
              ),
            ),
            const Spacer(),
            const Text('Today: — sales • — items'),
          ],
        ),
      ),
    );
  }
}
