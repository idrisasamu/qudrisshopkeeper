import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../common/session.dart';
import '../../app/router.dart';
import '../sync/drive_client.dart';
import '../sync/drive_discovery.dart';
import '../sync/crypto_box.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'shop_join_fallback_page.dart';

class ShopJoinPage extends ConsumerStatefulWidget {
  const ShopJoinPage({super.key});
  @override
  ConsumerState<ShopJoinPage> createState() => _ShopJoinPageState();
}

class _ShopJoinPageState extends ConsumerState<ShopJoinPage> {
  bool _loading = true;
  List<DiscoveredShop> _shops = [];
  String? _error;
  int _attempt = 0;
  String _loadingMessage = 'Looking for shops...';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await _loadShopsWithRetry();
  }

  Future<void> _loadShopsWithRetry() async {
    setState(() {
      _loading = true;
      _error = null;
      _loadingMessage = _attempt == 0
          ? 'Looking for shops...'
          : 'Still looking for shops... (attempt $_attempt/8)';
    });
    try {
      final g = GoogleSignIn(
        scopes: const [
          'email',
          'profile',
          'https://www.googleapis.com/auth/drive.file',
        ],
      );
      final acct = await g.signInSilently() ?? await g.signIn();
      if (acct == null) throw Exception('Google sign-in required');

      final sessionManager = SessionManager();
      await sessionManager.setString('google_email', acct.email);

      // Use Drive discovery to find shops shared with this user
      final drive = DriveClient(g);
      final discovery = DriveDiscovery(drive, g);
      final discoveredShops = await discovery.listShopsForUser();

      print(
        'DEBUG: Found ${discoveredShops.length} shops via Drive discovery (attempt $_attempt)',
      );
      for (final shop in discoveredShops) {
        print('DEBUG: Discovered shop: ${shop.shopName} (${shop.shopId})');
      }

      setState(() => _shops = discoveredShops);

      // If no shops found and we haven't tried too many times, retry with exponential backoff
      if (_shops.isEmpty && _attempt < 8) {
        _attempt++;
        // Exponential backoff: 5, 10, 20, 40, 60, 60, 60, 60 seconds
        final delaySeconds = _attempt <= 4 ? 5 * (1 << (_attempt - 1)) : 60;
        print(
          'DEBUG: No shops found, retrying in $delaySeconds seconds (attempt $_attempt/8)',
        );

        // Update loading message with countdown
        for (int i = delaySeconds; i > 0; i--) {
          if (mounted) {
            setState(() {
              _loadingMessage =
                  'No shops found yet. Retrying in $i seconds... (attempt $_attempt/8)';
            });
          }
          await Future.delayed(const Duration(seconds: 1));
        }

        await _loadShopsWithRetry();
      }
    } catch (e) {
      print('DEBUG: Drive discovery error: $e');
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _select(DiscoveredShop s) async {
    // 1) Parent is the shop root folder
    final shopRootId = s.shopRootId;
    if (shopRootId.isEmpty) throw Exception('Shop root not found');

    final g = GoogleSignIn(
      scopes: const [
        'email',
        'profile',
        'https://www.googleapis.com/auth/drive.file',
      ],
    );
    final drive = DriveClient(g);

    // 2) Find existing child folders (should be shared by owner)
    final broadcastId = await drive.findChildFolderId(shopRootId, 'broadcast');
    final snapshotsId = await drive.findChildFolderId(shopRootId, 'snapshots');
    final inboxRootId = await drive.findChildFolderId(
      shopRootId,
      'inbox_sales',
    );

    if (broadcastId == null || snapshotsId == null || inboxRootId == null) {
      throw Exception(
        'Shop folders not found. Ask owner to add you as staff member first.',
      );
    }

    final myEmail = (await g.signInSilently())?.email;
    if (myEmail == null) throw Exception('Google session missing');

    final myInboxId =
        await drive.findChildFolderId(inboxRootId, myEmail) ??
        (await drive.createFolder(myEmail, parentId: inboxRootId)).id!;

    // 3) Cache in Session for sync engine
    final sessionManager = SessionManager();
    await sessionManager.setString('drive_shop_folder_id', shopRootId);
    await sessionManager.setString('drive_broadcast_folder_id', broadcastId);
    await sessionManager.setString('drive_snapshots_folder_id', snapshotsId);
    await sessionManager.setString('drive_inbox_root_id', inboxRootId);
    await sessionManager.setString('drive_inbox_my_id', myInboxId);
    await sessionManager.setString('drive_enabled', 'true');

    // 4) Get shop key from shop.json or generate default
    final shopKey = await _getShopKeyFromShopJson(drive, shopRootId);
    if (shopKey != null) {
      await sessionManager.setString('shop_key_b64', shopKey);
      await sessionManager.setInt('shop_key_version', 1);
    }

    // Cache role + shop
    await sessionManager.setString('role', 'staff');
    await sessionManager.setString('shop_id', s.shopId);
    await sessionManager.setString('shop_name', s.shopName);

    // 5) Go to Staff Home
    if (context.mounted) context.go(routeStaffHome);
  }

  /// Get shop key from shop.json file
  Future<String?> _getShopKeyFromShopJson(
    DriveClient drive,
    String shopRootId,
  ) async {
    try {
      final api = await drive.getApi();
      final files = await api.files.list(
        q: "name = 'shop.json' and parents in '$shopRootId' and trashed = false",
        $fields: 'files(id,name)',
      );

      if (files.files?.isNotEmpty == true) {
        final shopJsonFile = files.files!.first;
        final content = await drive.downloadString(shopJsonFile.id!);
        final shopData = jsonDecode(content) as Map<String, dynamic>;

        // For now, generate a default key - in production, this should be shared securely
        return CryptoBox.generateShopKey();
      }
    } catch (e) {
      print('DEBUG: Could not read shop.json: $e');
    }
    return null;
  }

  Future<String> _ensureFolderNamed(
    DriveClient drive,
    String folderName, {
    required String parentId,
  }) async {
    final existingId = await drive.findChildFolderId(parentId, folderName);
    if (existingId != null) return existingId;

    final folder = await drive.createFolder(folderName, parentId: parentId);
    return folder.id!;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select your shop'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _loadShopsWithRetry,
            tooltip: 'Refresh shops',
          ),
        ],
      ),
      body: _loading
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    _loadingMessage,
                    style: const TextStyle(fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  if (_attempt > 0) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'Google Drive permissions can take up to 2 minutes to propagate.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            )
          : _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Error: $_error'),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: _loadShopsWithRetry,
                    child: const Text('Retry'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ShopJoinFallbackPage(
                            dc: DriveClient(
                              GoogleSignIn(
                                scopes: const [
                                  'email',
                                  'profile',
                                  'https://www.googleapis.com/auth/drive.file',
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                    child: const Text('Having trouble? Scan QR / Paste ID'),
                  ),
                ],
              ),
            )
          : _shops.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.store, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    'No shops assigned',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'You haven\'t been added to any shops yet.',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Please contact the shop owner or technical support team to be added to a shop.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.withOpacity(0.3)),
                    ),
                    child: const Text(
                      'Note: If you were just added to a shop, it may take up to 2 minutes for Google Drive permissions to propagate. The app will automatically retry.',
                      style: TextStyle(color: Colors.blue, fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ShopJoinFallbackPage(
                            dc: DriveClient(
                              GoogleSignIn(
                                scopes: const [
                                  'email',
                                  'profile',
                                  'https://www.googleapis.com/auth/drive.file',
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                    child: const Text('Or Scan QR / Paste ID'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _loadShopsWithRetry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh'),
                  ),
                ],
              ),
            )
          : ListView.separated(
              itemCount: _shops.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final s = _shops[i];
                return ListTile(
                  leading: const Icon(Icons.store),
                  title: Text(s.shopName),
                  subtitle: Text(s.shopId),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _select(s),
                );
              },
            ),
    );
  }
}
