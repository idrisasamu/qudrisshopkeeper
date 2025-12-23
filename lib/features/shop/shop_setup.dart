import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/main.dart';
import '../../common/session.dart';
import '../../data/local/daos/user_dao.dart';
import '../../common/key_vault.dart';
import '../auth/password_hasher.dart';
import '../../data/services/config_sync.dart';
import '../sync/drive_client.dart';

/// Shop setup page for first-time admin users
class ShopSetupPage extends ConsumerStatefulWidget {
  const ShopSetupPage({super.key});

  @override
  ConsumerState<ShopSetupPage> createState() => _ShopSetupPageState();
}

class _ShopSetupPageState extends ConsumerState<ShopSetupPage> {
  final _formKey = GlobalKey<FormState>();
  final _shopNameController = TextEditingController();
  final _adminPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  late final UserDao _userDao;
  final SessionManager _sessionManager = SessionManager();
  final KeyVault _keyVault = KeyVault();
  late final DriveClient _driveClient;
  late final ConfigSync _configSync;

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();
    final db = ref.read(dbProvider);
    _userDao = UserDao(db);
    _driveClient = DriveClient.defaultConstructor();
    _configSync = ConfigSync(db, _driveClient);
  }

  @override
  void dispose() {
    _shopNameController.dispose();
    _adminPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _setupShop() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Generate a new shop ID
      final shopId = _generateShopId();
      final shopShortId = _generateShortId();

      // Set shop ID in session first
      await _sessionManager.setString('shop_id', shopId);
      await _sessionManager.setString('shop_short_id', shopShortId);

      // Generate shop encryption key
      await _keyVault.ensureShopKey(shopId);

      // Set up Drive folders (simplified - in real implementation you'd want to create the full structure)
      try {
        // For now, we'll just set some placeholder folder IDs
        // In a real implementation, you'd create the full Drive folder structure here
        await _sessionManager.enableDriveSync(
          shopId: shopId,
          shopShortId: shopShortId,
          driveShopFolderId: 'placeholder_shop_folder',
          driveBroadcastFolderId: 'placeholder_broadcast_folder',
          driveSnapshotsFolderId: 'placeholder_snapshots_folder',
          driveInboxRootId: 'placeholder_inbox_root',
        );
      } catch (e) {
        print('Warning: Drive setup failed: $e');
        // Continue anyway for offline functionality
      }

      // Hash the admin password
      final (hashB64, saltB64, kdf) = await PasswordHasher.hashPassword(
        _adminPasswordController.text,
      );

      // Create admin user
      await _userDao.createUser(
        shopId: shopId,
        username: 'admin',
        role: 'admin',
        passwordHash: hashB64,
        salt: saltB64,
        kdf: kdf,
      );

      // Set shop name in session
      await _sessionManager.setString(
        'shop_name',
        _shopNameController.text.trim(),
      );

      // Push initial staff configuration to Drive
      await _configSync.pushLocalUsersToDrive(shopId);

      // Set admin role in session
      await _sessionManager.setString('role', 'admin');
      await _sessionManager.setString('username', 'admin');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Shop setup completed successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        context.go('/admin');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Setup failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _generateShopId() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random();
    return String.fromCharCodes(
      Iterable.generate(
        24,
        (_) => chars.codeUnitAt(random.nextInt(chars.length)),
      ),
    );
  }

  String _generateShortId() {
    const chars =
        'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // Excluding confusing chars
    final random = Random();
    return String.fromCharCodes(
      Iterable.generate(
        8,
        (_) => chars.codeUnitAt(random.nextInt(chars.length)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shop Setup'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                const Icon(Icons.store, size: 80, color: Colors.blue),
                const SizedBox(height: 24),
                const Text(
                  'Setup Your Shop',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Configure your shop and set up admin access',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),

                // Shop name field
                TextFormField(
                  controller: _shopNameController,
                  decoration: const InputDecoration(
                    labelText: 'Shop Name',
                    prefixIcon: Icon(Icons.store),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your shop name';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 24),

                // Admin password field
                TextFormField(
                  controller: _adminPasswordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Admin Password',
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter an admin password';
                    }
                    if (value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // Confirm password field
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  decoration: InputDecoration(
                    labelText: 'Confirm Admin Password',
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPassword
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureConfirmPassword = !_obscureConfirmPassword;
                        });
                      },
                    ),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please confirm the password';
                    }
                    if (value != _adminPasswordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 32),

                // Setup button
                ElevatedButton(
                  onPressed: _isLoading ? null : _setupShop,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          'Setup Shop',
                          style: TextStyle(fontSize: 16),
                        ),
                ),

                const SizedBox(height: 24),

                // Info text
                const Text(
                  'This will create your shop and set up admin access. You can add staff members later.',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
