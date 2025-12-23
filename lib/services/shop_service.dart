import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_client.dart';

/// Shop data model
class Shop {
  final String id;
  final String name;
  final String? description;
  final String? address;
  final String? city;
  final String? state;
  final String country;
  final String? postalCode;
  final String? phone;
  final String? email;
  final String? taxId;
  final String currency;
  final String timezone;
  final String? logoUrl;
  final Map<String, dynamic>? settings;
  final DateTime createdAt;
  final DateTime updatedAt;

  Shop({
    required this.id,
    required this.name,
    this.description,
    this.address,
    this.city,
    this.state,
    required this.country,
    this.postalCode,
    this.phone,
    this.email,
    this.taxId,
    required this.currency,
    required this.timezone,
    this.logoUrl,
    this.settings,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Get currency symbol for this shop
  String get currencySymbol {
    switch (currency.toUpperCase()) {
      case 'NGN':
        return '₦';
      case 'GHS':
        return '₵';
      case 'KES':
        return 'KSh';
      case 'ZAR':
        return 'R';
      case 'EGP':
        return 'E£';
      case 'XOF':
        return 'CFA';
      case 'XAF':
        return 'FCFA';
      default:
        return '₦'; // Default to Naira
    }
  }

  factory Shop.fromJson(Map<String, dynamic> json) {
    return Shop(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      address: json['address'] as String?,
      city: json['city'] as String?,
      state: json['state'] as String?,
      country: json['country'] as String? ?? 'NG',
      postalCode: json['postal_code'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      taxId: json['tax_id'] as String?,
      currency: json['currency'] as String? ?? 'NGN',
      timezone: json['timezone'] as String? ?? 'Africa/Lagos',
      logoUrl: json['logo_url'] as String?,
      settings: json['settings'] as Map<String, dynamic>?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'address': address,
      'city': city,
      'state': state,
      'country': country,
      'postal_code': postalCode,
      'phone': phone,
      'email': email,
      'tax_id': taxId,
      'currency': currency,
      'timezone': timezone,
      'logo_url': logoUrl,
      'settings': settings,
    };
  }
}

/// Staff membership model
class StaffMembership {
  final String id;
  final String shopId;
  final String userId;
  final String role; // owner, manager, cashier
  final bool isActive;
  final Map<String, dynamic>? permissions;
  final DateTime? joinedAt;
  final Shop? shop;

  StaffMembership({
    required this.id,
    required this.shopId,
    required this.userId,
    required this.role,
    required this.isActive,
    this.permissions,
    this.joinedAt,
    this.shop,
  });

  factory StaffMembership.fromJson(Map<String, dynamic> json) {
    return StaffMembership(
      id: json['id'] as String,
      shopId: json['shop_id'] as String,
      userId: json['user_id'] as String,
      role: json['role'] as String,
      isActive: json['is_active'] as bool? ?? true,
      permissions: json['permissions'] as Map<String, dynamic>?,
      joinedAt: json['joined_at'] != null
          ? DateTime.parse(json['joined_at'] as String)
          : null,
      shop: json['shops'] != null
          ? Shop.fromJson(json['shops'] as Map<String, dynamic>)
          : null,
    );
  }

  bool get isOwner => role == 'owner';
  bool get isManager => role == 'manager' || isOwner;
  bool get isCashier => role == 'cashier';
}

/// Service for managing shops
class ShopService {
  final SupabaseClient _client = SupabaseService.client;

  /// Get shops where current user is a staff member
  Future<List<StaffMembership>> getUserShops() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) {
      throw Exception('No authenticated user');
    }

    try {
      final response = await _client
          .from('staff')
          .select('*, shops(*)')
          .eq('user_id', userId)
          .isFilter('deleted_at', null)
          .eq('is_active', true);

      return (response as List)
          .map((json) => StaffMembership.fromJson(json))
          .toList();
    } catch (e) {
      print('Error fetching user shops: $e');
      rethrow;
    }
  }

  /// Get shop by ID
  Future<Shop?> getShop(String shopId) async {
    try {
      final response = await _client
          .from('shops')
          .select()
          .eq('id', shopId)
          .isFilter('deleted_at', null)
          .single();

      return Shop.fromJson(response);
    } catch (e) {
      print('Error fetching shop: $e');
      return null;
    }
  }

  /// Create a new shop
  Future<Shop> createShop({
    required String name,
    String? description,
    String? address,
    String? city,
    String? state,
    String? country,
    String? phone,
    String? email,
    String? currency,
    String? timezone,
  }) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) {
      throw Exception('No authenticated user');
    }

    try {
      // Create shop
      final shopResponse = await _client
          .from('shops')
          .insert({
            'name': name,
            'description': description,
            'address': address,
            'city': city,
            'state': state,
            'country': country ?? 'NG',
            'phone': phone,
            'email': email,
            'currency': currency ?? 'NGN',
            'timezone': timezone ?? 'Africa/Lagos',
            'created_by': userId,
          })
          .select()
          .single();

      final shop = Shop.fromJson(shopResponse);

      // Add creator as owner
      await _client.from('staff').insert({
        'shop_id': shop.id,
        'user_id': userId,
        'role': 'owner',
        'is_active': true,
        'joined_at': DateTime.now().toIso8601String(),
        'created_by': userId,
      });

      return shop;
    } catch (e) {
      print('Error creating shop: $e');
      rethrow;
    }
  }

  /// Update shop
  Future<Shop> updateShop({
    required String shopId,
    String? name,
    String? description,
    String? address,
    String? city,
    String? state,
    String? phone,
    String? email,
    String? logoUrl,
    Map<String, dynamic>? settings,
  }) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) {
      throw Exception('No authenticated user');
    }

    try {
      final updates = <String, dynamic>{'updated_by': userId};

      if (name != null) updates['name'] = name;
      if (description != null) updates['description'] = description;
      if (address != null) updates['address'] = address;
      if (city != null) updates['city'] = city;
      if (state != null) updates['state'] = state;
      if (phone != null) updates['phone'] = phone;
      if (email != null) updates['email'] = email;
      if (logoUrl != null) updates['logo_url'] = logoUrl;
      if (settings != null) updates['settings'] = settings;

      final response = await _client
          .from('shops')
          .update(updates)
          .eq('id', shopId)
          .select()
          .single();

      return Shop.fromJson(response);
    } catch (e) {
      print('Error updating shop: $e');
      rethrow;
    }
  }

  /// Get user's role in a shop
  Future<String?> getUserRole(String shopId) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return null;

    try {
      final response = await _client
          .from('staff')
          .select('role')
          .eq('shop_id', shopId)
          .eq('user_id', userId)
          .isFilter('deleted_at', null)
          .eq('is_active', true)
          .maybeSingle();

      return response?['role'] as String?;
    } catch (e) {
      print('Error fetching user role: $e');
      return null;
    }
  }

  /// Generate invite code for shop
  Future<String> generateInviteCode({
    required String shopId,
    required String role,
    Duration expiresIn = const Duration(days: 7),
  }) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) {
      throw Exception('No authenticated user');
    }

    try {
      // Generate a random 8-character code
      final code = _generateCode();
      final expiresAt = DateTime.now().add(expiresIn);

      // Store invite
      await _client.from('staff').insert({
        'shop_id': shopId,
        'user_id': userId, // Temporary - will be updated when accepted
        'role': role,
        'invite_code': code,
        'invite_expires_at': expiresAt.toIso8601String(),
        'invited_by': userId,
        'is_active': false,
        'created_by': userId,
      });

      return code;
    } catch (e) {
      print('Error generating invite code: $e');
      rethrow;
    }
  }

  /// Accept invite code
  Future<Shop> acceptInvite(String inviteCode) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) {
      throw Exception('No authenticated user');
    }

    try {
      // Find invite
      final invite = await _client
          .from('staff')
          .select('*, shops(*)')
          .eq('invite_code', inviteCode)
          .isFilter('deleted_at', null)
          .gt('invite_expires_at', DateTime.now().toIso8601String())
          .maybeSingle();

      if (invite == null) {
        throw Exception('Invalid or expired invite code');
      }

      final shopId = invite['shop_id'] as String;

      // Check if user is already a member
      final existing = await _client
          .from('staff')
          .select('id')
          .eq('shop_id', shopId)
          .eq('user_id', userId)
          .isFilter('deleted_at', null)
          .maybeSingle();

      if (existing != null) {
        throw Exception('You are already a member of this shop');
      }

      // Create staff membership
      await _client.from('staff').insert({
        'shop_id': shopId,
        'user_id': userId,
        'role': invite['role'],
        'is_active': true,
        'joined_at': DateTime.now().toIso8601String(),
        'invited_by': invite['invited_by'],
        'created_by': userId,
      });

      // Delete/mark invite as used
      await _client.from('staff').delete().eq('id', invite['id']);

      return Shop.fromJson(invite['shops']);
    } catch (e) {
      print('Error accepting invite: $e');
      rethrow;
    }
  }

  /// Get currency code for a shop
  Future<String> getCurrencyCode(String shopId) async {
    try {
      final shop = await getShop(shopId);
      return shop?.currency ?? 'NGN';
    } catch (e) {
      print('Error getting currency code: $e');
      return 'NGN'; // Default
    }
  }

  /// Update currency code for a shop
  Future<void> updateCurrencyCode(String shopId, String currencyCode) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) {
      throw Exception('No authenticated user');
    }

    try {
      await _client
          .from('shops')
          .update({'currency': currencyCode, 'updated_by': userId})
          .eq('id', shopId);

      print('Updated currency code to $currencyCode for shop $shopId');
    } catch (e) {
      print('Error updating currency code: $e');
      rethrow;
    }
  }

  /// Generate random invite code
  String _generateCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = DateTime.now().millisecondsSinceEpoch;
    var code = '';

    for (var i = 0; i < 8; i++) {
      code += chars[(random + i) % chars.length];
    }

    return code;
  }

  /// Stream of user's shops
  Stream<List<StaffMembership>> watchUserShops() {
    final userId = SupabaseService.currentUserId;
    if (userId == null) {
      return Stream.value([]);
    }

    return _client
        .from('staff')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at')
        .map(
          (data) => data.map((json) => StaffMembership.fromJson(json)).toList(),
        );
  }
}
