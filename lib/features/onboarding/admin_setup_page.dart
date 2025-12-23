import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/main.dart';
import '../../common/session.dart';
import '../../common/uuid.dart';
import '../../data/local/app_database.dart';
import '../../data/services/config_sync.dart';
import '../../features/sync/drive_bootstrap.dart';
import '../../features/sync/drive_client.dart';
import '../../features/sync/crypto_box.dart';
import '../../features/auth/google_auth.dart';

class AdminSetupPage extends ConsumerStatefulWidget {
  const AdminSetupPage({super.key});

  @override
  ConsumerState<AdminSetupPage> createState() => _AdminSetupPageState();
}

class _AdminSetupPageState extends ConsumerState<AdminSetupPage> {
  final _shopNameCtrl = TextEditingController();
  final _ownerNameCtrl = TextEditingController();
  bool _isCreating = false;

  @override
  void dispose() {
    _shopNameCtrl.dispose();
    _ownerNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _createShopAndAdmin() async {
    if (_shopNameCtrl.text.isEmpty ||
        _ownerNameCtrl.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please fill all fields')));
      return;
    }

    setState(() => _isCreating = true);

    try {
      print('DEBUG: AdminSetupPage - creating shop and admin...');

      // 1) Create shop ID and local profile
      final shopId = newId();
      final shopKey = CryptoBox.generateShopKey();

      final sessionManager = SessionManager();
      await sessionManager.setString('shop_id', shopId);
      await sessionManager.setString('shop_name', _shopNameCtrl.text.trim());
      await sessionManager.setString('shop_key_b64', shopKey);
      await sessionManager.setInt('shop_key_version', 1);

      // Get owner email from Google session
      final ownerEmail =
          await sessionManager.getString('google_email') ??
          'unknown@example.com';

      // 2) Create shop in database
      final db = ref.read(dbProvider);
      final now = DateTime.now();
      await db
          .into(db.shops)
          .insertOnConflictUpdate(
            ShopsCompanion.insert(
              id: shopId,
              name: _shopNameCtrl.text.trim(),
              email: ownerEmail,
              ownerName: _ownerNameCtrl.text.trim(),
              country: 'Unknown',
              city: 'Unknown',
              key: shopKey,
              appPassword: '',
              createdAt: now,
            ),
          );

      print('DEBUG: AdminSetupPage - shop created in database');

      // 3) Set up Drive sync
      final googleSignIn = GoogleAuthService.googleSignIn;
      final driveClient = DriveClient(googleSignIn);
      final driveBootstrap = DriveBootstrap(driveClient, googleSignIn);

      final layout = await driveBootstrap.ensureShopLayout(
        shopId: shopId,
        shopName: _shopNameCtrl.text.trim(),
        ownerEmail: ownerEmail,
      );

      await sessionManager.enableDriveSync(
        shopId: shopId,
        shopShortId: shopId.substring(0, 8),
        driveShopFolderId: layout.shopRootId,
        driveBroadcastFolderId: layout.broadcastId,
        driveSnapshotsFolderId: layout.snapshotsId,
        driveInboxRootId: layout.inboxRootId,
      );

      print('DEBUG: AdminSetupPage - Drive sync enabled');

      // 4) Create admin user and push to Drive
      final configSync = ConfigSync(db, driveClient);
      await configSync.createDefaultAdminAndPush(shopId, ownerEmail);

      print('DEBUG: AdminSetupPage - admin user created and pushed to Drive');

      // 5) Mark shop as provisioned
      await sessionManager.markShopProvisioned();

      // 6) Open database for the new shop
      final dbHolder = ref.read(dbHolderProvider);
      await dbHolder.openForShop(shopId);

      print(
        'DEBUG: AdminSetupPage - setup completed, navigating to continue-as',
      );

      if (mounted) {
        context.go('/continue-as');
      }
    } catch (e) {
      print('DEBUG: AdminSetupPage - error: $e');
      if (mounted) {
        setState(() => _isCreating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Setup failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Your Shop'),
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
                      'Create New Shop',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Set up your shop and create an admin account.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Form
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _shopNameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Shop Name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _ownerNameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Owner Name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _isCreating ? null : _createShopAndAdmin,
                      child: _isCreating
                          ? const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                                SizedBox(width: 12),
                                Text('Creating Shop...'),
                              ],
                            )
                          : const Text('Create Shop'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
