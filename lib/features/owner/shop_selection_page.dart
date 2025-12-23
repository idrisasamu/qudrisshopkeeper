import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../common/session.dart';
import '../../app/router.dart';
import '../../app/main.dart';
import '../../data/services/shop_service.dart';
import '../inventory/inventory_page.dart';
import '../inventory/low_stock_page.dart';
import '../sales/sales_history_page.dart';
import '../sales/new_sale_page.dart';
import '../auth/google_auth.dart';
import '../sync/drive_client.dart';
import '../sync/drive_discovery.dart';
import '../sync/drive_bootstrap.dart';
import '../../data/services/data_sync.dart';
import '../../data/repositories/drive_data_repo.dart';
import 'package:googleapis/drive/v3.dart' as gdrive;

// Provider for ShopService
final shopServiceProvider = Provider<ShopService>((ref) {
  final db = ref.read(dbProvider);
  final session = SessionManager();

  // For now, create ShopService without DriveClient
  // DriveClient will be created when needed in the service
  return ShopService(
    db: db,
    session: session,
    driveClient: null, // Will be created when needed
  );
});

class ShopSelectionPage extends ConsumerStatefulWidget {
  const ShopSelectionPage({super.key});
  @override
  ConsumerState<ShopSelectionPage> createState() => _ShopSelectionPageState();
}

class _ShopSelectionPageState extends ConsumerState<ShopSelectionPage> {
  List<UserShop> _userShops = [];
  bool _loading = true;
  String? _error;
  String? _deletingId; // Track which shop is being deleted

  @override
  void initState() {
    super.initState();
    print('DEBUG: ShopSelectionPage.initState() - page initialized');
    _loadUserShops();
  }

  Future<void> _loadUserShops() async {
    print('DEBUG: ShopSelectionPage._loadUserShops() - starting to load shops');
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final shops = await _getUserShops();
      print(
        'DEBUG: ShopSelectionPage._loadUserShops() - loaded ${shops.length} shops',
      );
      setState(() => _userShops = shops);
    } catch (e) {
      print('DEBUG: ShopSelectionPage._loadUserShops() - error: $e');
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<List<UserShop>> _getUserShops() async {
    final sessionManager = SessionManager();
    final email = await sessionManager.getString('google_email');

    if (email == null) return [];

    List<UserShop> shops = [];

    // First, try to load shops from Google Drive
    try {
      final driveEnabled = await sessionManager.isDriveEnabled();
      print(
        'DEBUG: ShopSelectionPage._getUserShops() - driveEnabled: $driveEnabled',
      );

      if (driveEnabled) {
        print(
          'DEBUG: ShopSelectionPage._getUserShops() - attempting to load shops from Drive',
        );
        // Use the shared GoogleSignIn instance from GoogleAuthService
        final googleSignIn = GoogleAuthService.googleSignIn;
        final driveClient = DriveClient(googleSignIn);
        final discovery = DriveDiscovery(driveClient, googleSignIn);
        final discoveredShops = await discovery.listShopsForUser();

        for (final discoveredShop in discoveredShops) {
          // Determine the user's role for this shop by reading shop.json
          final userRole = await _getUserRoleForShop(
            driveClient,
            discoveredShop.shopId,
            discoveredShop.shopName,
          );

          shops.add(
            UserShop(
              id: discoveredShop.shopId,
              name: discoveredShop.shopName,
              role: userRole,
              isOwner: userRole == 'owner',
              isCurrentShop: false,
            ),
          );
        }
        print(
          'DEBUG: ShopSelectionPage._getUserShops() - found ${discoveredShops.length} shops from Google Drive',
        );
      } else {
        print(
          'DEBUG: ShopSelectionPage._getUserShops() - Drive sync not enabled, skipping Drive discovery',
        );
      }
    } catch (e) {
      print(
        'DEBUG: ShopSelectionPage._getUserShops() - Error loading shops from Google Drive: $e',
      );
    }

    // Also load shops from local storage
    final shopsJson = await sessionManager.getString('user_shops_$email');
    print(
      'DEBUG: ShopSelectionPage._getUserShops() - local shops JSON: ${shopsJson?.isNotEmpty == true ? "present" : "empty"}',
    );

    if (shopsJson != null && shopsJson.isNotEmpty) {
      try {
        // Parse the JSON string to get list of shops
        final shopsList = shopsJson
            .split('|')
            .where((shopData) => shopData.isNotEmpty)
            .map((shopData) {
              final parts = shopData.split(':');
              if (parts.length >= 3) {
                return UserShop(
                  id: parts[0],
                  name: parts[1],
                  role: parts[2],
                  isOwner: parts[2] == 'owner',
                  isCurrentShop: parts.length > 3 && parts[3] == 'current',
                );
              }
              return null;
            })
            .where((shop) => shop != null)
            .cast<UserShop>()
            .toList();

        print(
          'DEBUG: ShopSelectionPage._getUserShops() - parsed ${shopsList.length} shops from local storage',
        );

        // Merge with Drive shops, avoiding duplicates
        for (final localShop in shopsList) {
          if (!shops.any((s) => s.id == localShop.id)) {
            shops.add(localShop);
          }
        }
        print(
          'DEBUG: ShopSelectionPage._getUserShops() - total shops after merging: ${shops.length}',
        );
      } catch (e) {
        print(
          'DEBUG: ShopSelectionPage._getUserShops() - Error parsing user shops: $e',
        );
      }
    }

    // Fallback: check for single shop in legacy format
    if (shops.isEmpty) {
      print(
        'DEBUG: ShopSelectionPage._getUserShops() - no shops found, checking legacy format',
      );
      final existingShopId = await sessionManager.getString('shop_id');
      final existingShopName = await sessionManager.getString('shop_name');
      final existingRole = await sessionManager.getString('role');

      print(
        'DEBUG: ShopSelectionPage._getUserShops() - legacy shop_id: $existingShopId, name: $existingShopName, role: $existingRole',
      );

      if (existingShopId != null &&
          existingShopName != null &&
          existingRole != null) {
        shops.add(
          UserShop(
            id: existingShopId,
            name: existingShopName,
            role: existingRole,
            isOwner: existingRole == 'owner',
            isCurrentShop: true,
          ),
        );
        print(
          'DEBUG: ShopSelectionPage._getUserShops() - added legacy shop to list',
        );
      }
    }

    return shops;
  }

  Future<void> _selectShop(UserShop shop) async {
    try {
      final sessionManager = SessionManager();
      final email = await sessionManager.getString('google_email');

      if (email != null) {
        // Update the user's shops list to mark this shop as current
        final shopsJson =
            await sessionManager.getString('user_shops_$email') ?? '';
        final shops = shopsJson.split('|').where((s) => s.isNotEmpty).toList();

        // Remove 'current' flag from all shops and add to selected shop
        for (int i = 0; i < shops.length; i++) {
          final parts = shops[i].split(':');
          if (parts.length >= 3) {
            if (parts[0] == shop.id) {
              shops[i] = '${parts[0]}:${parts[1]}:${parts[2]}:current';
            } else {
              shops[i] = '${parts[0]}:${parts[1]}:${parts[2]}';
            }
          }
        }

        await sessionManager.setString('user_shops_$email', shops.join('|'));
      }

      // Set current shop as active
      await sessionManager.setString('role', shop.role);
      await sessionManager.setString('shop_id', shop.id);
      await sessionManager.setString('shop_name', shop.name);

      // Pull business data from Drive immediately after shop selection
      print(
        'DEBUG: ShopSelectionPage - pulling business data from Drive for shop: ${shop.id}',
      );
      try {
        final db = ref.read(dbProvider);
        final driveClient = DriveClient(GoogleAuthService.googleSignIn);
        final driveDataRepo = DriveDataRepo(driveClient);

        // Get or create data root folder
        final dataRootId = await _ensureDataRootFolder(driveClient, shop.id);

        final dataSync = DataSync(
          db: db,
          repo: driveDataRepo,
          shopId: shop.id,
          dataRootId: dataRootId,
        );

        // Pull inventory, stock movements, and sales
        await dataSync.pullInventory();
        await dataSync.pullSalesAndStock(daysBack: 90);
        print('DEBUG: ShopSelectionPage - business data pulled successfully');
      } catch (e) {
        print('DEBUG: ShopSelectionPage - error pulling business data: $e');
        // Continue even if data pull fails
      }

      // Invalidate all providers to ensure fresh data for the new shop
      ref.invalidate(itemsWithStockProvider);
      ref.invalidate(lowStockItemsProvider);
      ref.invalidate(salesHistoryProvider);
      ref.invalidate(salesItemsWithStockProvider);

      if (mounted) {
        final route = shop.isOwner ? routeOwnerHome : routeStaffHome;
        context.go(route);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error selecting shop: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Ensure data root folder exists for the shop
  Future<String> _ensureDataRootFolder(
    DriveClient driveClient,
    String shopId,
  ) async {
    try {
      final api = await driveClient.getApi();

      // Find QSK folder
      final qskQuery =
          "name='QSK' and mimeType='application/vnd.google-apps.folder' and trashed=false";
      final qskResult = await api.files.list(
        q: qskQuery,
        $fields: 'files(id,name)',
      );
      final qskFolderId = qskResult.files?.isNotEmpty == true
          ? qskResult.files!.first.id
          : null;

      if (qskFolderId == null) {
        throw Exception('QSK folder not found');
      }

      // Find shop folder
      final shopQuery =
          "name='$shopId' and '$qskFolderId' in parents and mimeType='application/vnd.google-apps.folder' and trashed=false";
      final shopResult = await api.files.list(
        q: shopQuery,
        $fields: 'files(id,name)',
      );
      final shopFolderId = shopResult.files?.isNotEmpty == true
          ? shopResult.files!.first.id
          : null;

      if (shopFolderId == null) {
        throw Exception('Shop folder not found');
      }

      // Find or create data folder
      final dataQuery =
          "name='data' and '$shopFolderId' in parents and mimeType='application/vnd.google-apps.folder' and trashed=false";
      final dataResult = await api.files.list(
        q: dataQuery,
        $fields: 'files(id,name)',
      );

      if (dataResult.files?.isNotEmpty == true) {
        return dataResult.files!.first.id!;
      } else {
        // Create data folder
        final dataFolder = await api.files.create(
          gdrive.File()
            ..name = 'data'
            ..mimeType = 'application/vnd.google-apps.folder'
            ..parents = [shopFolderId],
        );
        return dataFolder.id!;
      }
    } catch (e) {
      print('DEBUG: ShopSelectionPage._ensureDataRootFolder() - error: $e');
      rethrow;
    }
  }

  Future<void> _createNewShop() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => _CreateShopDialog(),
    );

    if (result != null && mounted) {
      // Shop created, reload the list
      await _loadUserShops();
      // Invalidate all providers to ensure fresh data for the new shop
      ref.invalidate(itemsWithStockProvider);
      ref.invalidate(lowStockItemsProvider);
      ref.invalidate(salesHistoryProvider);
      ref.invalidate(salesItemsWithStockProvider);
    }
  }

  Future<void> _continueAsStaff() async {
    try {
      // Navigate to shop join page where staff can see shops they're assigned to
      if (mounted) {
        context.go('/shop-join');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error switching to staff mode: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showDeleteConfirmation(UserShop shop) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Shop'),
        content: Text(
          'Are you sure you want to delete "${shop.name}"?\n\n'
          'This action cannot be undone and will remove all shop data.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deleteShop(shop);
    }
  }

  Future<void> _deleteShop(UserShop shop) async {
    setState(() => _deletingId = shop.id);

    try {
      // Use the new ShopService for authoritative deletion
      final shopService = ref.read(shopServiceProvider);
      await shopService.deleteShop(shop.id);

      // Optimistically remove from UI
      setState(() {
        _userShops.removeWhere((s) => s.id == shop.id);
        _deletingId = null;
      });

      // Check if we need to redirect (current shop was deleted)
      final sessionManager = SessionManager();
      final currentShopId = await sessionManager.getString('shop_id');
      if (currentShopId == null || currentShopId.isEmpty) {
        // Current shop was deleted, stay on this page
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Shop "${shop.name}" deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // Different shop was deleted, show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Shop "${shop.name}" deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _deletingId = null);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting shop: $e'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () => _deleteShop(shop),
            ),
          ),
        );
      }
    }
  }

  /// Refresh the shops list from Drive and local storage
  Future<void> _refreshShops() async {
    await _loadUserShops();
  }

  /// Determines the user's role for a specific shop by reading shop.json
  Future<String> _getUserRoleForShop(
    DriveClient driveClient,
    String shopId,
    String shopName,
  ) async {
    try {
      final sessionManager = SessionManager();
      final currentUserEmail = await sessionManager.getString('google_email');

      if (currentUserEmail == null) {
        print('DEBUG: No current user email found, defaulting to owner');
        return 'owner';
      }

      // Find the shop.json file for this shop
      final api = await driveClient.getApi();
      final res = await api.files.list(
        q: "name = 'shop.json' and trashed = false and ('me' in readers or 'me' in owners or 'me' in writers)",
        spaces: 'drive',
        corpora: 'allDrives',
        includeItemsFromAllDrives: true,
        supportsAllDrives: true,
        $fields: 'files(id,name,parents)',
        pageSize: 100,
      );

      for (final file in res.files ?? const []) {
        try {
          // Download and check if this shop.json contains our shopId
          final content = await driveClient.downloadString(file.id!);
          final shopData = jsonDecode(content) as Map<String, dynamic>;

          if (shopData['shopId'] == shopId) {
            // Check if current user is the owner
            if (shopData['ownerEmail'] == currentUserEmail) {
              return 'owner';
            }

            // Check if current user is in staff members
            final staffMembers = List<Map<String, dynamic>>.from(
              shopData['staffMembers'] ?? [],
            );

            for (final staff in staffMembers) {
              if (staff['email'] == currentUserEmail) {
                return staff['role'] ?? 'staff';
              }
            }

            // If user has access to the file but is not in the metadata,
            // they might be a legacy staff member
            return 'staff';
          }
        } catch (e) {
          print('DEBUG: Error processing shop.json ${file.id}: $e');
        }
      }

      // If we can't find the shop.json or determine the role, default to owner
      print(
        'DEBUG: Could not determine role for shop $shopId, defaulting to owner',
      );
      return 'owner';
    } catch (e) {
      print('DEBUG: Error determining user role for shop $shopId: $e');
      return 'owner';
    }
  }

  @override
  Widget build(BuildContext context) {
    print(
      'DEBUG: ShopSelectionPage.build() - rendering with ${_userShops.length} shops, loading: $_loading',
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Shop'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshShops,
            tooltip: 'Refresh shops',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: $_error'),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: _loadUserShops,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : _userShops.isEmpty
          ? _buildEmptyState()
          : _buildShopList(),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.extended(
            heroTag: "staff_button",
            onPressed: _continueAsStaff,
            icon: const Icon(Icons.badge),
            label: const Text('Continue as Staff'),
            backgroundColor: Colors.green,
          ),
          const SizedBox(height: 8),
          FloatingActionButton.extended(
            heroTag: "create_shop_button",
            onPressed: _createNewShop,
            icon: const Icon(Icons.add),
            label: const Text('Create New Shop'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.store, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'No shops yet',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Create your first shop to get started',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _createNewShop,
            icon: const Icon(Icons.add),
            label: const Text('Create Your First Shop'),
          ),
        ],
      ),
    );
  }

  Widget _buildShopList() {
    final currentShop = _userShops.firstWhere(
      (shop) => shop.isCurrentShop,
      orElse: () => _userShops.isNotEmpty
          ? _userShops.first
          : UserShop(id: '', name: '', role: '', isOwner: false),
    );

    return Column(
      children: [
        // Quick continue section for current shop
        if (_userShops.any((shop) => shop.isCurrentShop))
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.rocket_launch, color: Colors.blue),
                    const SizedBox(width: 8),
                    const Text(
                      'Quick Continue',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Continue working on "${currentShop.name}"',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => _selectShop(currentShop),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Continue to Shop'),
                  ),
                ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Icon(Icons.store, color: Colors.blue),
              const SizedBox(width: 8),
              Text(
                'Your Shops (${_userShops.length})',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _userShops.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final shop = _userShops[index];
              return Card(
                color: shop.isCurrentShop ? Colors.blue[50] : null,
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: shop.isOwner ? Colors.blue : Colors.green,
                    child: Icon(
                      shop.isOwner ? Icons.store_mall_directory : Icons.badge,
                      color: Colors.white,
                    ),
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(shop.name, overflow: TextOverflow.ellipsis),
                      ),
                      if (shop.isCurrentShop) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'CURRENT',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  subtitle: Text(
                    shop.isOwner ? 'Owner • ${shop.id}' : 'Staff • ${shop.id}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_deletingId == shop.id) ...[
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 8),
                      ] else ...[
                        if (shop.isOwner) ...[
                          PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'delete') {
                                _showDeleteConfirmation(shop);
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete, color: Colors.red),
                                    SizedBox(width: 8),
                                    Text(
                                      'Delete Shop',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 8),
                        ],
                        if (shop.isCurrentShop) ...[
                          FilledButton(
                            onPressed: () => _selectShop(shop),
                            child: const Text('Continue'),
                          ),
                          const SizedBox(width: 8),
                        ],
                        const Icon(Icons.chevron_right),
                      ],
                    ],
                  ),
                  onTap: () => _selectShop(shop),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class UserShop {
  final String id;
  final String name;
  final String role;
  final bool isOwner;
  final bool isCurrentShop;

  UserShop({
    required this.id,
    required this.name,
    required this.role,
    required this.isOwner,
    this.isCurrentShop = false,
  });
}

class _CreateShopDialog extends StatefulWidget {
  @override
  State<_CreateShopDialog> createState() => _CreateShopDialogState();
}

class _CreateShopDialogState extends State<_CreateShopDialog> {
  final _nameController = TextEditingController();
  bool _busy = false;

  String _slugify(String name) {
    final s = name.trim().toLowerCase();
    final slug = s
        .replaceAll(RegExp(r"[^a-z0-9]+"), "-")
        .replaceAll(RegExp('^-+|-+\$'), '');
    final suffix = DateTime.now().millisecondsSinceEpoch
        .toRadixString(36)
        .substring(0, 4);
    return slug.isEmpty ? 'shop-$suffix' : '$slug-$suffix';
  }

  Future<void> _createShop() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter a shop name')));
      return;
    }

    setState(() => _busy = true);
    try {
      final shopId = _slugify(name);
      final sessionManager = SessionManager();
      final email = await sessionManager.getString('google_email');

      if (email == null) {
        throw Exception('User email not found');
      }

      // Enable Drive sync and set up Google Drive structure
      final driveEnabled = await sessionManager.isDriveEnabled();
      if (!driveEnabled) {
        // Auto-enable Drive sync for new shops
        await sessionManager.setString('drive_enabled', 'true');
        print('DEBUG: Auto-enabled Drive sync for new shop');
      }

      if (driveEnabled || !driveEnabled) {
        // Always try to set up Drive structure
        try {
          // Use the shared GoogleSignIn instance from GoogleAuthService
          final googleSignIn = GoogleAuthService.googleSignIn;
          final driveClient = DriveClient(googleSignIn);
          final bootstrap = DriveBootstrap(driveClient, googleSignIn);

          // Create the complete Drive layout for the shop
          final layout = await bootstrap.ensureShopLayout(
            shopId: shopId,
            shopName: name,
            ownerEmail: email,
          );

          // Store Drive folder IDs in session for sync operations
          await sessionManager.setString(
            'drive_shop_folder_id',
            layout.shopRootId,
          );
          await sessionManager.setString(
            'drive_broadcast_folder_id',
            layout.broadcastId,
          );
          await sessionManager.setString(
            'drive_snapshots_folder_id',
            layout.snapshotsId,
          );
          await sessionManager.setString(
            'drive_inbox_root_id',
            layout.inboxRootId,
          );

          print('DEBUG: Created Google Drive structure for shop $shopId');
        } catch (e) {
          print('Warning: Failed to create Google Drive structure: $e');
          // Continue with local creation even if Drive fails
        }
      }

      // Get existing shops for this user
      final existingShopsJson =
          await sessionManager.getString('user_shops_$email') ?? '';
      final existingShops = existingShopsJson
          .split('|')
          .where((s) => s.isNotEmpty)
          .toList();

      // Add new shop
      existingShops.add('$shopId:$name:owner:current');

      // Save updated shops list
      await sessionManager.setString(
        'user_shops_$email',
        existingShops.join('|'),
      );

      // Set current shop as active
      await sessionManager.setString('role', 'owner');
      await sessionManager.setString('shop_id', shopId);
      await sessionManager.setString('shop_name', name);

      if (mounted) {
        Navigator.of(context).pop(shopId);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating shop: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create New Shop'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Shop name',
              hintText: 'e.g., Qudris Market',
            ),
            autofocus: true,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _createShop,
          child: _busy
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Create'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }
}
