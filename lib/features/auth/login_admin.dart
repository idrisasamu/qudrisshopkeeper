import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/main.dart';
import '../../common/session.dart';
import '../../data/local/daos/user_dao.dart';
import '../auth/password_hasher.dart';

/// Admin login page - prompts for admin password
class LoginAdminPage extends ConsumerStatefulWidget {
  const LoginAdminPage({super.key});

  @override
  ConsumerState<LoginAdminPage> createState() => _LoginAdminPageState();
}

class _LoginAdminPageState extends ConsumerState<LoginAdminPage> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  late final UserDao _userDao;
  final SessionManager _sessionManager = SessionManager();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    final db = ref.read(dbProvider);
    _userDao = UserDao(db);
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final shopId = await _sessionManager.getString('shop_id');
      if (shopId == null) {
        throw Exception('No shop ID found in session');
      }

      // Get admin user
      final adminUser = await _userDao.getAdminUser(shopId);
      if (adminUser == null) {
        throw Exception('No admin user found for this shop');
      }

      // Verify password with defensive verification
      final isValid = (adminUser.salt.isNotEmpty && adminUser.kdf.isNotEmpty)
          ? await PasswordHasher.verify(
              _passwordController.text,
              adminUser.passwordHash,
              adminUser.salt,
              adminUser.kdf,
            )
          : await PasswordHasher.verifyLegacyBase64(
              // accepts hash-only (base64url) legacy
              _passwordController.text,
              adminUser.passwordHash,
            );

      if (!isValid) {
        throw Exception('Invalid admin password');
      }

      // Set session
      await _sessionManager.setString('role', 'admin');
      await _sessionManager.setString('username', adminUser.username);

      if (mounted) {
        context.go('/admin');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Login failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Login'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight:
                    MediaQuery.of(context).size.height -
                    MediaQuery.of(context).padding.top -
                    MediaQuery.of(context).padding.bottom -
                    kToolbarHeight -
                    48, // 48 for padding
              ),
              child: IntrinsicHeight(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    const Icon(
                      Icons.admin_panel_settings,
                      size: 80,
                      color: Colors.blue,
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Admin Login',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Enter your admin password to continue',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 48),

                    // Password field
                    TextFormField(
                      controller: _passwordController,
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
                          return 'Please enter your admin password';
                        }
                        return null;
                      },
                      onFieldSubmitted: (_) => _handleLogin(),
                    ),

                    const SizedBox(height: 32),

                    // Login button
                    ElevatedButton(
                      onPressed: _isLoading ? null : _handleLogin,
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
                              'Login as Admin',
                              style: TextStyle(fontSize: 16),
                            ),
                    ),

                    const SizedBox(height: 24),

                    // Back button
                    TextButton(
                      onPressed: () => context.go('/continue-as'),
                      child: const Text('Back to Continue As'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
