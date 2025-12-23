import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/main.dart';
import '../../data/local/daos/user_dao.dart';
import '../../data/services/config_sync.dart';
import '../sync/drive_client.dart';
import '../../common/session.dart';
import 'password_hasher.dart';

/// Change PIN page for logged-in staff members
class ChangePinLoggedInPage extends ConsumerStatefulWidget {
  const ChangePinLoggedInPage({super.key});

  @override
  ConsumerState<ChangePinLoggedInPage> createState() =>
      _ChangePinLoggedInPageState();
}

class _ChangePinLoggedInPageState extends ConsumerState<ChangePinLoggedInPage> {
  final _formKey = GlobalKey<FormState>();
  final _currentPinController = TextEditingController();
  final _newPin1Controller = TextEditingController();
  final _newPin2Controller = TextEditingController();
  late final UserDao _userDao;
  final SessionManager _sessionManager = SessionManager();
  late final DriveClient _driveClient;
  late final ConfigSync _configSync;
  bool _saving = false;
  String? _currentUsername;

  @override
  void initState() {
    super.initState();
    final db = ref.read(dbProvider);
    _userDao = UserDao(db);
    _driveClient = DriveClient.defaultConstructor();
    _configSync = ConfigSync(db, _driveClient);
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    final username = await _sessionManager.getString('username');
    setState(() {
      _currentUsername = username;
    });
  }

  @override
  void dispose() {
    _currentPinController.dispose();
    _newPin1Controller.dispose();
    _newPin2Controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final currentPin = _currentPinController.text.trim();
    final newPin1 = _newPin1Controller.text.trim();
    final newPin2 = _newPin2Controller.text.trim();

    if (newPin1.length < 4 || newPin1 != newPin2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('New PINs must match and be at least 4 digits.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_currentUsername == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No current user found. Please log in again.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      // Get shop ID
      final shopId = await _sessionManager.getString('shop_id');
      if (shopId == null) {
        throw Exception('No shop selected');
      }

      // Find current user
      final user = await _userDao.findByUsernameAndShop(
        _currentUsername!,
        shopId,
      );
      if (user == null) {
        throw Exception('User not found');
      }

      // Verify current PIN
      final isCurrentPinValid = (user.salt.isNotEmpty && user.kdf.isNotEmpty)
          ? await PasswordHasher.verify(
              currentPin,
              user.passwordHash,
              user.salt,
              user.kdf,
            )
          : await PasswordHasher.verifyLegacyBase64(
              currentPin,
              user.passwordHash,
            );

      if (!isCurrentPinValid) {
        throw Exception('Current PIN is incorrect');
      }

      // Hash the new PIN
      final (hash, salt, kdf) = await PasswordHasher.hashPassword(
        newPin1,
        iterations: 150000,
      );

      // Update user with new PIN
      await _userDao.updateUserSecure(
        id: user.id,
        passwordHash: hash,
        salt: salt,
        kdf: kdf,
        passwordUpdatedAt: DateTime.now(),
        revBump: true,
      );

      // Sync the changes to Drive
      await _configSync.pushLocalUsersToDrive(shopId);
      print(
        'DEBUG: ChangePinLoggedInPage - PIN change synced to Drive for shop: $shopId',
      );

      if (mounted) {
        setState(() {
          _saving = false;
        });

        // Clear form
        _currentPinController.clear();
        _newPin1Controller.clear();
        _newPin2Controller.clear();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PIN updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating PIN: ${e.toString()}'),
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
        title: const Text('Change PIN'),
        automaticallyImplyLeading: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                const Icon(Icons.security, size: 80, color: Colors.blue),
                const SizedBox(height: 24),
                const Text(
                  'Change Your PIN',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Update your PIN for security',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),

                // Current PIN field
                TextFormField(
                  controller: _currentPinController,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Current PIN',
                    prefixIcon: Icon(Icons.lock),
                    border: OutlineInputBorder(),
                    hintText: 'Enter your current PIN',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your current PIN';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // New PIN field
                TextFormField(
                  controller: _newPin1Controller,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'New PIN',
                    prefixIcon: Icon(Icons.lock),
                    border: OutlineInputBorder(),
                    hintText: 'Enter new 4+ digit PIN',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a new PIN';
                    }
                    if (value.trim().length < 4) {
                      return 'PIN must be at least 4 digits';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // Confirm PIN field
                TextFormField(
                  controller: _newPin2Controller,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Confirm New PIN',
                    prefixIcon: Icon(Icons.lock),
                    border: OutlineInputBorder(),
                    hintText: 'Confirm your new PIN',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please confirm your new PIN';
                    }
                    if (value.trim() != _newPin1Controller.text.trim()) {
                      return 'PINs do not match';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 32),

                // Save button
                ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          'Update PIN',
                          style: TextStyle(fontSize: 16),
                        ),
                ),

                const SizedBox(height: 24),

                // Info text
                const Text(
                  'Your PIN must be at least 4 digits. Choose something you can remember but others cannot guess.',
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
