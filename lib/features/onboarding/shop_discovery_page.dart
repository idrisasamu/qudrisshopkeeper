import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/main.dart';
import '../../app/theme.dart';
import '../../common/session.dart';
import '../../data/services/drive_discovery.dart';
import '../../data/services/config_sync.dart';
import '../../data/services/data_sync.dart'; // Added
import '../../data/repositories/drive_data_repo.dart'; // Added
import '../../features/sync/drive_client.dart';
import '../../features/auth/google_auth.dart';
import 'package:googleapis/drive/v3.dart' as gdrive; // Added
import 'admin_setup_page.dart';

class ShopDiscoveryPage extends ConsumerStatefulWidget {
  const ShopDiscoveryPage({super.key});

  @override
  ConsumerState<ShopDiscoveryPage> createState() => _ShopDiscoveryPageState();
}

class _ShopDiscoveryPageState extends ConsumerState<ShopDiscoveryPage> {
  bool _isSearching = true;
  bool _hasError = false;
  String _errorMessage = '';
  List<ShopInfo> _foundShops = [];

  @override
  void initState() {
    super.initState();
    _searchForShops();
  }

  Future<void> _searchForShops() async {
    setState(() {
      _isSearching = true;
      _hasError = false;
      _errorMessage = '';
      _foundShops = [];
    });

    try {
      print('DEBUG: ShopDiscoveryPage - starting shop search...');

      final driveClient = DriveClient(GoogleAuthService.googleSignIn);
      final driveDiscovery = DriveDiscovery(driveClient);

      // Search for all shops on Drive
      final shop = await driveDiscovery.findMyShop();

      if (shop != null) {
        print('DEBUG: ShopDiscoveryPage - found shop: ${shop.name}');
        setState(() {
          _foundShops = [shop];
          _isSearching = false;
        });
      } else {
        print('DEBUG: ShopDiscoveryPage - no shops found');
        setState(() {
          _isSearching = false;
        });
      }
    } catch (e) {
      print('DEBUG: ShopDiscoveryPage - error: $e');
      setState(() {
        _isSearching = false;
        _hasError = true;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _selectShop(ShopInfo shop) async {
    try {
      print('DEBUG: ShopDiscoveryPage - selecting shop: ${shop.name}');
      print('DEBUG: ShopDiscoveryPage - shop ID: ${shop.id}');

      final sessionManager = SessionManager();

      // Write shop data to local session
      print('DEBUG: ShopDiscoveryPage - writing shop data to session');
      await sessionManager.setString('shop_id', shop.id);
      await sessionManager.setString('shop_name', shop.name);
      await sessionManager.markShopProvisioned();
      print('DEBUG: ShopDiscoveryPage - shop data written to session');

      // Open database for the selected shop
      print('DEBUG: ShopDiscoveryPage - opening database for shop: ${shop.id}');
      final dbHolder = ref.read(dbHolderProvider);
      await dbHolder.openForShop(shop.id);
      print('DEBUG: ShopDiscoveryPage - database opened successfully');

      // Pull user configuration from Drive
      print('DEBUG: ShopDiscoveryPage - pulling user config from Drive');
      final db = ref.read(dbProvider);
      final driveClient = DriveClient(GoogleAuthService.googleSignIn);
      final configSync = ConfigSync(db, driveClient);
      await configSync.pullUsersFromDrive(shop.id);
      print('DEBUG: ShopDiscoveryPage - user config pulled successfully');

      // Pull business data from Drive
      print('DEBUG: ShopDiscoveryPage - pulling business data from Drive');
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
      print('DEBUG: ShopDiscoveryPage - business data pulled successfully');

      if (mounted) {
        print('DEBUG: ShopDiscoveryPage - navigating to /continue-as');
        context.go('/continue-as');
      } else {
        print('DEBUG: ShopDiscoveryPage - widget not mounted, cannot navigate');
      }
    } catch (e) {
      print('DEBUG: ShopDiscoveryPage - error selecting shop: $e');
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
      print(
        'DEBUG: ShopDiscoveryPage._ensureDataRootFolder() - ensuring data folder for shop: $shopId',
      );

      final api = await driveClient.getApi();

      // Look for QSK root folder
      final qskQuery =
          "name='QSK' and mimeType='application/vnd.google-apps.folder' and trashed=false and 'me' in owners";
      final qskRes = await api.files.list(
        q: qskQuery,
        $fields: 'files(id,name)',
        spaces: 'drive',
      );

      String qskRootId;
      if (qskRes.files?.isEmpty ?? true) {
        // Create QSK root folder
        print(
          'DEBUG: ShopDiscoveryPage._ensureDataRootFolder() - creating QSK root folder',
        );
        final qskFolder = await api.files.create(
          gdrive.File()
            ..name = 'QSK'
            ..mimeType = 'application/vnd.google-apps.folder',
        );
        qskRootId = qskFolder.id!;
      } else {
        qskRootId = qskRes.files!.first.id!;
      }

      // Look for shop folder
      final shopQuery =
          "name='$shopId' and mimeType='application/vnd.google-apps.folder' and trashed=false and 'me' in owners";
      final shopRes = await api.files.list(
        q: shopQuery,
        $fields: 'files(id,name)',
        spaces: 'drive',
      );

      String shopFolderId;
      if (shopRes.files?.isEmpty ?? true) {
        // Create shop folder
        print(
          'DEBUG: ShopDiscoveryPage._ensureDataRootFolder() - creating shop folder',
        );
        final shopFolder = await api.files.create(
          gdrive.File()
            ..name = shopId
            ..mimeType = 'application/vnd.google-apps.folder'
            ..parents = [qskRootId],
        );
        shopFolderId = shopFolder.id!;
      } else {
        shopFolderId = shopRes.files!.first.id!;
      }

      // Look for data folder
      final dataQuery =
          "name='data' and mimeType='application/vnd.google-apps.folder' and trashed=false and 'me' in owners";
      final dataRes = await api.files.list(
        q: dataQuery,
        $fields: 'files(id,name)',
        spaces: 'drive',
      );

      String dataRootId;
      if (dataRes.files?.isEmpty ?? true) {
        // Create data folder
        print(
          'DEBUG: ShopDiscoveryPage._ensureDataRootFolder() - creating data folder',
        );
        final dataFolder = await api.files.create(
          gdrive.File()
            ..name = 'data'
            ..mimeType = 'application/vnd.google-apps.folder'
            ..parents = [shopFolderId],
        );
        dataRootId = dataFolder.id!;
      } else {
        dataRootId = dataRes.files!.first.id!;
      }

      print(
        'DEBUG: ShopDiscoveryPage._ensureDataRootFolder() - data root folder: $dataRootId',
      );
      return dataRootId;
    } catch (e) {
      print('DEBUG: ShopDiscoveryPage._ensureDataRootFolder() - error: $e');
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Find Your Shop'),
        backgroundColor: Colors.grey[900],
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Card(
              color: Colors.grey[800],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Shop Discovery',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Searching for your existing shops on Google Drive...',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Content
            if (_isSearching) ...[
              const Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text(
                        'Searching for shops...',
                        style: TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
            ] else if (_hasError) ...[
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.red[400],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Error searching for shops',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _errorMessage,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _searchForShops,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Try Again'),
                      ),
                    ],
                  ),
                ),
              ),
            ] else if (_foundShops.isEmpty) ...[
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.store_outlined,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No shops found',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'No existing shops were found on your Google Drive.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton.icon(
                            onPressed: _searchForShops,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Search Again'),
                          ),
                          const SizedBox(width: 16),
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => const AdminSetupPage(),
                                ),
                              );
                            },
                            icon: const Icon(Icons.add),
                            label: const Text('Create New Shop'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.gold,
                              foregroundColor: Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              // Found shops
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Found ${_foundShops.length} shop${_foundShops.length == 1 ? '' : 's'}:',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _foundShops.length,
                        itemBuilder: (context, index) {
                          final shop = _foundShops[index];
                          return Card(
                            color: Colors.grey[800],
                            child: ListTile(
                              leading: const Icon(
                                Icons.store,
                                color: AppTheme.gold,
                              ),
                              title: Text(
                                shop.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'ID: ${shop.id}',
                                    style: const TextStyle(color: Colors.grey),
                                  ),
                                  if (shop.ownerEmail.isNotEmpty)
                                    Text(
                                      'Owner: ${shop.ownerEmail}',
                                      style: const TextStyle(
                                        color: Colors.grey,
                                      ),
                                    ),
                                  if (shop.createdAt != null)
                                    Text(
                                      'Created: ${shop.createdAt}',
                                      style: const TextStyle(
                                        color: Colors.grey,
                                      ),
                                    ),
                                ],
                              ),
                              trailing: const Icon(
                                Icons.arrow_forward_ios,
                                color: Colors.grey,
                              ),
                              onTap: () => _selectShop(shop),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
