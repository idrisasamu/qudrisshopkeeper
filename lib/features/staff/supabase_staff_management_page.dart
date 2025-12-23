import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:characters/characters.dart';
import 'package:share_plus/share_plus.dart';
import '../../common/session.dart';

/// Modern Supabase-based staff management page
class SupabaseStaffManagementPage extends ConsumerStatefulWidget {
  const SupabaseStaffManagementPage({super.key});

  @override
  ConsumerState<SupabaseStaffManagementPage> createState() =>
      _SupabaseStaffManagementPageState();
}

class _SupabaseStaffManagementPageState
    extends ConsumerState<SupabaseStaffManagementPage> {
  final SessionManager _sessionManager = SessionManager();
  List<StaffMember> _staffMembers = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadStaff();
  }

  Future<void> _loadStaff() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final shopId = await _sessionManager.getString('shop_id');
      if (shopId == null) {
        throw Exception('No shop selected');
      }

      final sb = Supabase.instance.client;

      // Fetch staff with their profile information
      final response = await sb
          .from('staff')
          .select('''
            id,
            role,
            is_active,
            joined_at,
            created_at,
            user_id,
            profiles:user_id (
              email,
              full_name,
              phone
            )
          ''')
          .eq('shop_id', shopId)
          .order('created_at', ascending: false);

      final staffMembers = (response as List)
          .map((item) => StaffMember.fromJson(item))
          .toList();

      setState(() {
        _staffMembers = staffMembers;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _inviteStaff() async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => const _InviteStaffDialog(),
    );

    if (result == null) return;

    setState(() => _isLoading = true);

    try {
      final shopId = await _sessionManager.getString('shop_id');
      if (shopId == null) throw Exception('No shop selected');

      final email = result['email']!;
      final role = result['role']!;

      await _addStaffByEmail(
        shopId: shopId,
        email: email,
        role: role,
        context: context,
      );

      await _loadStaff();
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error inviting staff: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  /// Add staff by email using the secure RPC function
  Future<void> _addStaffByEmail({
    required String shopId,
    required String email,
    required String role, // 'manager' or 'cashier'
    required BuildContext context,
  }) async {
    final sb = Supabase.instance.client;

    final res = await sb.rpc(
      'add_staff_by_email',
      params: {
        'p_shop_id': shopId,
        'p_email': email.trim(),
        'p_role': role, // must be 'manager' or 'cashier'
      },
    );

    // res is a Map from our JSONB
    final ok = (res['ok'] == true);
    if (ok) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully added $email as $role'),
            backgroundColor: Colors.green,
          ),
        );
      }
      return;
    }

    final err = (res['error'] as String?) ?? 'unknown_error';
    switch (err) {
      case 'user_not_found':
        if (mounted) {
          _showUserNotFoundDialog(context, email);
        }
        break;
      case 'forbidden':
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You don\'t have permission to add staff.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        break;
      case 'role_not_allowed':
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Only manager or cashier can be added here.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        break;
      default:
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to add staff ($err).'),
              backgroundColor: Colors.red,
            ),
          );
        }
    }
  }

  /// Show dialog when user is not found, offering to share sign-up link
  Future<void> _showUserNotFoundDialog(
    BuildContext context,
    String email,
  ) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('User Not Found'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('The email "$email" is not registered yet.'),
            const SizedBox(height: 16),
            const Text(
              'Share this sign-up link with them:',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: SelectableText(
                'https://your-app.com/signup',
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Once they sign up, you can invite them again.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          FilledButton.icon(
            onPressed: () {
              const signupUrl = 'https://your-app.com/signup';
              Share.share(
                'Join our team! Please sign up at: $signupUrl',
                subject: 'Join Our Team - Qudris ShopKeeper',
              );
              Navigator.pop(context);
            },
            icon: const Icon(Icons.share, size: 16),
            label: const Text('Share Link'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateRole(StaffMember member, String newRole) async {
    try {
      final sb = Supabase.instance.client;

      await sb
          .from('staff')
          .update({'role': newRole, 'updated_by': sb.auth.currentUser!.id})
          .eq('id', member.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Updated ${member.email}\'s role to $newRole'),
            backgroundColor: Colors.green,
          ),
        );
      }

      await _loadStaff();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating role: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _toggleActiveStatus(StaffMember member) async {
    try {
      final sb = Supabase.instance.client;

      await sb
          .from('staff')
          .update({
            'is_active': !member.isActive,
            'updated_by': sb.auth.currentUser!.id,
          })
          .eq('id', member.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              member.isActive
                  ? '${member.email} deactivated'
                  : '${member.email} activated',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }

      await _loadStaff();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating status: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _removeStaff(StaffMember member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Staff Member'),
        content: Text(
          'Are you sure you want to remove ${member.email} from your shop?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final sb = Supabase.instance.client;

      // Soft delete by setting deleted_at
      await sb
          .from('staff')
          .update({
            'deleted_at': DateTime.now().toIso8601String(),
            'updated_by': sb.auth.currentUser!.id,
          })
          .eq('id', member.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Removed ${member.email}'),
            backgroundColor: Colors.orange,
          ),
        );
      }

      await _loadStaff();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error removing staff: $e'),
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
        title: const Text('Staff Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStaff,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error, size: 64, color: Colors.red[300]),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading staff',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _loadStaff,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Try Again'),
                  ),
                ],
              ),
            )
          : _staffMembers.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No Staff Members Yet',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Invite staff members to help manage your shop',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _inviteStaff,
                    icon: const Icon(Icons.person_add),
                    label: const Text('Invite Staff'),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${_staffMembers.length} Staff Member${_staffMembers.length == 1 ? '' : 's'}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: _inviteStaff,
                        icon: const Icon(Icons.person_add),
                        label: const Text('Invite'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: _staffMembers.length,
                    itemBuilder: (context, index) {
                      final member = _staffMembers[index];
                      return _StaffMemberCard(
                        member: member,
                        onUpdateRole: (role) => _updateRole(member, role),
                        onToggleActive: () => _toggleActiveStatus(member),
                        onRemove: () => _removeStaff(member),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

/// Staff member model
class StaffMember {
  final String id;
  final String userId;
  final String role;
  final bool isActive;
  final DateTime? joinedAt;
  final String? email;
  final String? fullName;
  final String? phone;

  StaffMember({
    required this.id,
    required this.userId,
    required this.role,
    required this.isActive,
    this.joinedAt,
    this.email,
    this.fullName,
    this.phone,
  });

  factory StaffMember.fromJson(Map<String, dynamic> json) {
    final profile = json['profiles'] as Map<String, dynamic>?;

    return StaffMember(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      role: json['role'] as String,
      isActive: json['is_active'] as bool,
      joinedAt: json['joined_at'] != null
          ? DateTime.parse(json['joined_at'] as String)
          : null,
      email: profile?['email'] as String?,
      fullName: profile?['full_name'] as String?,
      phone: profile?['phone'] as String?,
    );
  }
}

/// Staff member card widget
class _StaffMemberCard extends StatelessWidget {
  final StaffMember member;
  final Function(String) onUpdateRole;
  final VoidCallback onToggleActive;
  final VoidCallback onRemove;

  const _StaffMemberCard({
    required this.member,
    required this.onUpdateRole,
    required this.onToggleActive,
    required this.onRemove,
  });

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'owner':
        return Colors.purple;
      case 'manager':
        return Colors.blue;
      case 'cashier':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: _getRoleColor(member.role),
          child: Text(
            _getInitial(member.fullName, member.email),
            style: const TextStyle(color: Colors.white),
          ),
        ),
        title: Text(_getDisplayName(member.fullName, member.email)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (member.email != null && member.fullName != null)
              Text(member.email!, style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: _getRoleColor(member.role).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _getRoleColor(member.role)),
                  ),
                  child: Text(
                    member.role.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: _getRoleColor(member.role),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (!member.isActive)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red),
                    ),
                    child: const Text(
                      'INACTIVE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (member.phone != null) ...[
                  Row(
                    children: [
                      const Icon(Icons.phone, size: 16, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text(member.phone!),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                if (member.joinedAt != null) ...[
                  Row(
                    children: [
                      const Icon(
                        Icons.calendar_today,
                        size: 16,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Joined ${_formatDate(member.joinedAt!)}',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
                const Divider(),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (member.role != 'owner') ...[
                      DropdownButton<String>(
                        value: member.role,
                        items: const [
                          DropdownMenuItem(
                            value: 'manager',
                            child: Text('Manager'),
                          ),
                          DropdownMenuItem(
                            value: 'cashier',
                            child: Text('Cashier'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) onUpdateRole(value);
                        },
                        underline: Container(),
                        icon: const Icon(Icons.arrow_drop_down),
                        style: const TextStyle(fontSize: 14),
                      ),
                      OutlinedButton.icon(
                        onPressed: onToggleActive,
                        icon: Icon(
                          member.isActive ? Icons.block : Icons.check_circle,
                          size: 16,
                        ),
                        label: Text(
                          member.isActive ? 'Deactivate' : 'Activate',
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: member.isActive
                              ? Colors.orange
                              : Colors.green,
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: onRemove,
                        icon: const Icon(Icons.delete, size: 16),
                        label: const Text('Remove'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                      ),
                    ] else ...[
                      const Text(
                        'Owner (cannot be modified)',
                        style: TextStyle(
                          color: Colors.grey,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  /// Safely get initial from name or email, handling empty strings
  String _getInitial(String? fullName, String? email) {
    final name = (fullName ?? '').trim();
    final emailStr = (email ?? '').trim();

    // Try full name first, then email
    final source = name.isNotEmpty ? name : emailStr;

    if (source.isEmpty) return '?';

    // Use characters.first to handle emojis and multi-codepoint characters safely
    return source.characters.first.toUpperCase();
  }

  /// Get display name with fallback
  String _getDisplayName(String? fullName, String? email) {
    final name = (fullName ?? '').trim();
    final emailStr = (email ?? '').trim();

    if (name.isNotEmpty) return name;
    if (emailStr.isNotEmpty) return emailStr;
    return 'Unknown User';
  }
}

/// Dialog to invite new staff
class _InviteStaffDialog extends StatefulWidget {
  const _InviteStaffDialog();

  @override
  State<_InviteStaffDialog> createState() => _InviteStaffDialogState();
}

class _InviteStaffDialogState extends State<_InviteStaffDialog> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  String _selectedRole = 'cashier';

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Invite Staff Member'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email Address',
                hintText: 'staff@example.com',
                prefixIcon: Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter email';
                }
                if (!value.contains('@')) {
                  return 'Please enter a valid email';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedRole,
              decoration: const InputDecoration(
                labelText: 'Role',
                prefixIcon: Icon(Icons.badge),
              ),
              items: const [
                DropdownMenuItem(value: 'manager', child: Text('Manager')),
                DropdownMenuItem(value: 'cashier', child: Text('Cashier')),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedRole = value!;
                });
              },
            ),
            const SizedBox(height: 16),
            const Text(
              'Note: The user must have already signed up with this email.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
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
                'email': _emailController.text.trim(),
                'role': _selectedRole,
              });
            }
          },
          child: const Text('Invite'),
        ),
      ],
    );
  }
}
