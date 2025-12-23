import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../sync/sync_service.dart';
import '../../common/session.dart';
import '../../providers/inventory_provider.dart';

// Provider to check if there are any low stock items using Supabase
final hasLowStockProvider = FutureProvider<bool>((ref) async {
  final lowStockAsync = ref.watch(lowStockProductsProvider);

  return lowStockAsync.when(
    data: (lowStockProducts) {
      // Check if there are any low stock products
      return lowStockProducts.isNotEmpty;
    },
    loading: () => false,
    error: (_, __) => false,
  );
});

class AdminDashboardPage extends ConsumerStatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  ConsumerState<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends ConsumerState<AdminDashboardPage> {
  @override
  void initState() {
    super.initState();
    // Start automatic sync for real-time updates
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final syncService = ref.read(syncServiceProvider);
      syncService.start();
    });
  }

  Future<Map<String, String?>> _getShopInfo() async {
    final sessionManager = SessionManager();
    final shopName = await sessionManager.getString('shop_name');
    final role = await sessionManager.getString('role');
    return {'shopName': shopName, 'role': role};
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, String?>>(
      future: _getShopInfo(),
      builder: (context, snapshot) {
        final shopName = snapshot.data?['shopName'] ?? 'Admin Dashboard';
        final role = snapshot.data?['role'] ?? 'admin';

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
                Text('$shopName ($role)', style: const TextStyle(fontSize: 14)),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.settings),
                onPressed: () async {
                  // TODO: Add requireOwner check
                  if (true) {
                    context.push('/settings');
                  }
                },
                tooltip: 'Settings',
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
                  title: 'Sales',
                  icon: Icons.receipt_long,
                  onTap: () => context.push('/sales/history'),
                ),
                _DashCard(
                  title: 'Reports',
                  icon: Icons.bar_chart,
                  onTap: () => context.push('/reports'),
                ),
                _DashCard(
                  title: 'QUDRIS AI',
                  icon: Icons.psychology,
                  onTap: () {
                    context.push('/qudris');
                  },
                ),
                Consumer(
                  builder: (context, ref, child) {
                    final hasLowStockAsync = ref.watch(hasLowStockProvider);

                    return hasLowStockAsync.when(
                      data: (hasLowStock) => _DashCard(
                        title: 'Low Stock',
                        icon: Icons.warning,
                        onTap: () => context.push('/inventory/low-stock'),
                        isLowStock: hasLowStock,
                      ),
                      loading: () => _DashCard(
                        title: 'Low Stock',
                        icon: Icons.warning,
                        onTap: () => context.push('/inventory/low-stock'),
                        isLowStock: false,
                      ),
                      error: (_, __) => _DashCard(
                        title: 'Low Stock',
                        icon: Icons.warning,
                        onTap: () => context.push('/inventory/low-stock'),
                        isLowStock: false,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DashCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;
  final bool isLowStock;

  const _DashCard({
    required this.title,
    required this.icon,
    required this.onTap,
    this.isLowStock = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: isLowStock
          ? Colors.yellow[50]
          : null, // Light yellow background for low stock
      elevation: isLowStock ? 3 : 1, // Higher elevation for low stock
      shape: isLowStock
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.yellow[300]!, width: 1),
            )
          : null, // Yellow border for low stock
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 36,
                color: isLowStock
                    ? Colors.yellow[700]
                    : null, // Yellow icon for low stock
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isLowStock
                      ? Colors.yellow[700]
                      : null, // Yellow text for low stock
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
