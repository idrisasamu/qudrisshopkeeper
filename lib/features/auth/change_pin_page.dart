import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/main.dart';
import '../../data/local/daos/users_dao.dart';
import '../auth/password_hasher.dart';
import '../../data/services/config_sync.dart';
import '../sync/drive_client.dart';
import '../../common/session.dart';

/// Change PIN page for staff members who must change their default PIN
class ChangePinPage extends ConsumerStatefulWidget {
  final String userId;
  const ChangePinPage({super.key, required this.userId});

  @override
  ConsumerState<ChangePinPage> createState() => _ChangePinPageState();
}

class _ChangePinPageState extends ConsumerState<ChangePinPage> {
  final _formKey = GlobalKey<FormState>();
  final _pin1Controller = TextEditingController();
  final _pin2Controller = TextEditingController();
  late final UsersDao _userDao;
  final SessionManager _sessionManager = SessionManager();
  late final DriveClient _driveClient;
  late final ConfigSync _configSync;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final db = ref.read(dbProvider);
    _userDao = UsersDao(db);
    _driveClient = DriveClient.defaultConstructor();
    _configSync = ConfigSync(db, _driveClient);
  }

  @override
  void dispose() {
    _pin1Controller.dispose();
    _pin2Controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final p1 = _pin1Controller.text.trim();
    final p2 = _pin2Controller.text.trim();

    if (p1.length < 4 || p1 != p2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PINs must match and be at least 4 digits.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      // Hash the new PIN
      final (hash, salt, kdf) = await PasswordHasher.hashPassword(
        p1,
        iterations: 150000,
      );

      // Update user with new PIN and clear must-change flag
      await _userDao.updateUserSecure(
        id: widget.userId,
        passwordHash: hash,
        salt: salt,
        kdf: kdf,
        mustChangePassword: false,
        passwordUpdatedAt: DateTime.now(),
        bumpRev: true,
      );

      // Sync the changes to Drive
      final shopId = await _sessionManager.getString('shop_id');
      if (shopId != null) {
        await _configSync.pushLocalUsersToDrive(shopId);
        print(
          'DEBUG: ChangePinPage - PIN change synced to Drive for shop: $shopId',
        );
      } else {
        print('DEBUG: ChangePinPage - no shop_id found, skipping Drive sync');
      }

      if (mounted) {
        setState(() {
          _saving = false;
        });

        // Return to login screen
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PIN updated. Please log in.'),
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
        title: const Text('Set New PIN'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                const Icon(Icons.security, size: 80, color: Colors.orange),
                const SizedBox(height: 24),
                const Text(
                  'Security Step',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Set your new PIN to continue',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),

                // New PIN field
                TextFormField(
                  controller: _pin1Controller,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'New PIN',
                    prefixIcon: Icon(Icons.lock),
                    border: OutlineInputBorder(),
                    hintText: 'Enter 4+ digit PIN',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a PIN';
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
                  controller: _pin2Controller,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Confirm PIN',
                    prefixIcon: Icon(Icons.lock),
                    border: OutlineInputBorder(),
                    hintText: 'Confirm your PIN',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please confirm your PIN';
                    }
                    if (value.trim() != _pin1Controller.text.trim()) {
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
                      : const Text('Save PIN', style: TextStyle(fontSize: 16)),
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
