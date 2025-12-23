import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../common/session.dart';
import '../inventory/low_stock_page.dart';
import '../../services/supabase_sync_service.dart';

class StaffHomePage extends ConsumerStatefulWidget {
  const StaffHomePage({super.key});
  @override
  ConsumerState<StaffHomePage> createState() => _StaffHomePageState();
}

class _StaffHomePageState extends ConsumerState<StaffHomePage> {
  String _shopName = '';

  @override
  void initState() {
    super.initState();
    SessionManager()
        .getString('shop_name')
        .then((v) => setState(() => _shopName = v ?? 'Shop'));

    // Start automatic Supabase sync for real-time updates
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final syncService = ref.read(supabaseSyncServiceProvider);
      syncService.start();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Qudris ShopKeeper',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text('$_shopName • Staff', style: const TextStyle(fontSize: 14)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Settings',
            onPressed: () async {
              context.push('/staff/settings');
            },
            icon: const Icon(Icons.settings),
          ),
        ],
      ),
      body: GridView.count(
        crossAxisCount: 2,
        padding: const EdgeInsets.all(16),
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        children: [
          _Tile(
            icon: Icons.point_of_sale,
            label: 'New Sale',
            onTap: () {
              context.push('/sale/new');
            },
          ),
          _Tile(
            icon: Icons.inventory_2,
            label: 'Inventory',
            onTap: () {
              context.push('/inventory?readOnly=true');
            },
          ),
          _LowStockTile(
            onTap: () {
              context.push('/inventory/low-stock?readOnly=true');
            },
          ),
          _Tile(
            icon: Icons.receipt_long,
            label: 'Sales',
            onTap: () {
              context.push('/sales/history?readOnly=true');
            },
          ),
          _Tile(
            icon: Icons.bar_chart,
            label: 'Reports',
            onTap: () => context.push('/reports?readOnly=true'),
          ),
          _Tile(
            icon: Icons.psychology,
            label: 'QUDRIS',
            onTap: () {
              context.push('/qudris');
            },
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _Tile({required this.icon, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Card(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 44),
              const SizedBox(height: 12),
              Text(label, style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
        ),
      ),
    );
  }
}

class _LowStockTile extends ConsumerWidget {
  final VoidCallback onTap;
  const _LowStockTile({required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lowStockAsync = ref.watch(lowStockItemsProvider);

    return lowStockAsync.when(
      data: (items) {
        final hasLowStock = items.isNotEmpty;
        return InkWell(
          onTap: onTap,
          child: Card(
            color: hasLowStock ? Colors.yellow.shade50 : null,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.warning_amber,
                    size: 44,
                    color: hasLowStock ? Colors.yellow.shade700 : null,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Low Stock',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: hasLowStock ? Colors.yellow.shade700 : null,
                      fontWeight: hasLowStock ? FontWeight.bold : null,
                    ),
                  ),
                  if (hasLowStock)
                    Text(
                      '${items.length} items',
                      style: TextStyle(
                        color: Colors.yellow.shade600,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
      loading: () =>
          _Tile(icon: Icons.warning_amber, label: 'Low Stock', onTap: onTap),
      error: (_, __) =>
          _Tile(icon: Icons.warning_amber, label: 'Low Stock', onTap: onTap),
    );
  }
}
