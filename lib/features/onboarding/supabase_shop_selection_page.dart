import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../services/shop_service.dart';
import '../../providers/auth_provider.dart';
import '../../common/session.dart';
import '../../app/main.dart';

/// New Supabase-based shop selection/creation page
class SupabaseShopSelectionPage extends ConsumerStatefulWidget {
  const SupabaseShopSelectionPage({super.key});

  @override
  ConsumerState<SupabaseShopSelectionPage> createState() =>
      _SupabaseShopSelectionPageState();
}

class _SupabaseShopSelectionPageState
    extends ConsumerState<SupabaseShopSelectionPage> {
  bool _isLoading = true;
  List<StaffMembership> _userShops = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadUserShops();
  }

  Future<void> _loadUserShops() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final shopService = ref.read(shopServiceProvider);
      final shops = await shopService.getUserShops();

      setState(() {
        _userShops = shops;
        _isLoading = false;
      });

      print('DEBUG: Found ${shops.length} shops for user');
    } catch (e) {
      print('ERROR loading shops: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _selectShop(StaffMembership membership) async {
    try {
      print('DEBUG: Selecting shop: ${membership.shop?.name}');

      final sessionManager = SessionManager();

      // Save shop info to session
      await sessionManager.setString('shop_id', membership.shopId);
      await sessionManager.setString(
        'shop_name',
        membership.shop?.name ?? 'Shop',
      );
      await sessionManager.setString('role', membership.role);
      await sessionManager.markShopProvisioned();

      // Open database for the selected shop
      final dbHolder = ref.read(dbHolderProvider);
      await dbHolder.openForShop(membership.shopId);

      print('DEBUG: Shop selected: ${membership.shopId}');
      print('DEBUG: Role: ${membership.role}');

      if (mounted) {
        // Navigate based on role
        if (membership.isOwner || membership.isManager) {
          context.go('/admin');
        } else {
          context.go('/staff');
        }
      }
    } catch (e) {
      print('ERROR selecting shop: $e');
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

  Future<void> _createNewShop() async {
    // Show dialog to create shop
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => const _CreateShopDialog(),
    );

    if (result == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final shopService = ref.read(shopServiceProvider);
      final shop = await shopService.createShop(
        name: result['name']!,
        description: result['description'],
        phone: result['phone'],
        address: result['address'],
      );

      print('DEBUG: Created shop: ${shop.name} (${shop.id})');

      // Save to session as owner
      final sessionManager = SessionManager();
      await sessionManager.setString('shop_id', shop.id);
      await sessionManager.setString('shop_name', shop.name);
      await sessionManager.setString('role', 'owner');
      await sessionManager.markShopProvisioned();

      // Open database
      final dbHolder = ref.read(dbHolderProvider);
      await dbHolder.openForShop(shop.id);

      if (mounted) {
        // Navigate to admin dashboard
        context.go('/admin');
      }
    } catch (e) {
      print('ERROR creating shop: $e');
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating shop: $e'),
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
        title: const Text('Select Shop'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final authService = ref.read(authServiceProvider);
              await authService.signOut();
              if (mounted) {
                context.go('/signin');
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_errorMessage != null)
                      Card(
                        color: Colors.red[50],
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Icon(Icons.error, color: Colors.red[700]),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: TextStyle(color: Colors.red[900]),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    if (_userShops.isEmpty) ...[
                      // No shops - invite to create
                      const Expanded(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.store, size: 80, color: Colors.grey),
                              SizedBox(height: 24),
                              Text(
                                'No Shops Yet',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Create your first shop to get started',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: _createNewShop,
                        icon: const Icon(Icons.add),
                        label: const Text('Create Your Shop'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ] else ...[
                      // Has shops - let them select
                      Text(
                        'Your Shops',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: ListView.builder(
                          itemCount: _userShops.length,
                          itemBuilder: (context, index) {
                            final membership = _userShops[index];
                            final shop = membership.shop;

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.blue,
                                  child: Text(
                                    shop?.name.substring(0, 1).toUpperCase() ??
                                        'S',
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                                title: Text(shop?.name ?? 'Unnamed Shop'),
                                subtitle: Text(
                                  'Role: ${membership.role.toUpperCase()}',
                                ),
                                trailing: const Icon(
                                  Icons.arrow_forward_ios,
                                  size: 16,
                                ),
                                onTap: () => _selectShop(membership),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: _createNewShop,
                        icon: const Icon(Icons.add),
                        label: const Text('Create New Shop'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}

/// Dialog to create a new shop
class _CreateShopDialog extends StatefulWidget {
  const _CreateShopDialog();

  @override
  State<_CreateShopDialog> createState() => _CreateShopDialogState();
}

class _CreateShopDialogState extends State<_CreateShopDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create New Shop'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Shop Name *',
                  hintText: 'My Store',
                  prefixIcon: Icon(Icons.store),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter shop name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'What do you sell?',
                  prefixIcon: Icon(Icons.description),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone',
                  hintText: '+234 800 000 0000',
                  prefixIcon: Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: 'Address',
                  hintText: 'Shop location',
                  prefixIcon: Icon(Icons.location_on),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.pop(context, {
                'name': _nameController.text.trim(),
                'description': _descriptionController.text.trim(),
                'phone': _phoneController.text.trim(),
                'address': _addressController.text.trim(),
              });
            }
          },
          child: const Text('Create'),
        ),
      ],
    );
  }
}
