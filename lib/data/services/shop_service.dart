import 'package:drift/drift.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../local/app_database.dart';
import '../../common/session.dart';
import '../../features/sync/drive_client.dart';
import '../repositories/drive_repository.dart';
import '../repositories/sync_ops_repo.dart';

/// Service for managing shop operations including deletion
class ShopService {
  final AppDatabase db;
  final SessionManager session;
  final DriveClient? driveClient;

  ShopService({required this.db, required this.session, this.driveClient});

  /// Authoritative and atomic shop deletion
  /// 1. Deletes all local data for the shop in a transaction
  /// 2. Attempts Drive cleanup (best-effort)
  /// 3. Clears session if current shop is deleted
  /// 4. Broadcasts deletion event
  Future<void> deleteShop(String shopId) async {
    print('DEBUG: Starting deletion of shop $shopId');

    // 1) Local delete in a transaction
    await db.transaction(() async {
      await _deleteShopCascade(shopId);

      // If the current session is on this shop, clear it
      final currentShopId = await session.getString('shop_id');
      if (currentShopId == shopId) {
        await _clearCurrentShopSession();
      }
    });

    // 2) Best-effort Drive cleanup (do not throw if it fails)
    await _cleanupDriveData(shopId);

    // 3) Remove from user's shop list
    await _removeFromUserShops(shopId);

    // 4) Notify listeners
    ShopEvents.instance.add(ShopDeleted(shopId));

    print('DEBUG: Successfully deleted shop $shopId');
  }

  /// Cascade delete all data related to a shop
  Future<void> _deleteShopCascade(String shopId) async {
    print('DEBUG: Deleting all data for shop $shopId');

    // Delete in order to respect foreign key constraints
    // 1. Delete sale items (references sales)
    final salesToDelete = await (db.select(
      db.sales,
    )..where((s) => s.shopId.equals(shopId))).get();
    final saleIds = salesToDelete.map((s) => s.id).toList();

    if (saleIds.isNotEmpty) {
      await (db.delete(
        db.saleItems,
      )..where((t) => t.saleId.isIn(saleIds))).go();
    }

    // 2. Delete sales
    await (db.delete(db.sales)..where((t) => t.shopId.equals(shopId))).go();

    // 3. Delete stock movements
    await (db.delete(
      db.stockMovements,
    )..where((t) => t.shopId.equals(shopId))).go();

    // 4. Delete items
    await (db.delete(db.items)..where((t) => t.shopId.equals(shopId))).go();

    // 5. Delete users
    await (db.delete(db.users)..where((t) => t.shopId.equals(shopId))).go();

    // 6. Delete sync operations related to this shop
    await (db.delete(
      db.syncOps,
    )..where((t) => t.payload.contains(shopId))).go();

    // 7. Delete applied operations related to this shop
    await (db.delete(
      db.appliedOps,
    )..where((t) => t.uuid.contains(shopId))).go();

    // 8. Finally delete the shop itself
    await (db.delete(db.shops)..where((t) => t.id.equals(shopId))).go();

    print('DEBUG: Completed cascade delete for shop $shopId');
  }

  /// Clear current shop session data
  Future<void> _clearCurrentShopSession() async {
    print('DEBUG: Clearing current shop session');

    // Use the existing clearRoleData method which clears shop-related data
    await session.clearRoleData();

    // Also clear Drive-related data if it exists
    try {
      await session.disableDriveSync();
    } catch (e) {
      print('DEBUG: Could not clear Drive sync data: $e');
    }
  }

  /// Best-effort Drive cleanup using DriveRepository
  Future<void> _cleanupDriveData(String shopId) async {
    try {
      final driveEnabled = await session.isDriveEnabled();
      if (!driveEnabled) {
        print('DEBUG: Drive not enabled, skipping Drive cleanup');
        return;
      }

      print('DEBUG: Starting Drive cleanup for shop $shopId');

      // Create DriveRepository for proper Drive operations
      final driveRepo = DriveRepository.create(GoogleSignIn());

      // Use the repository to delete the shop
      await driveRepo.deleteShop(shopId);

      // Clear any cached data
      await driveRepo.clearShopCache(shopId);

      print('DEBUG: Successfully completed Drive cleanup for shop $shopId');
    } catch (e) {
      print('WARNING: Drive cleanup failed for shop $shopId: $e');
      // Don't throw - Drive cleanup is best-effort
    }
  }

  /// Remove shop from user's shop list
  Future<void> _removeFromUserShops(String shopId) async {
    final email = await session.getString('google_email');
    if (email == null) return;

    final shopsJson = await session.getString('user_shops_$email') ?? '';
    final shops = shopsJson.split('|').where((s) => s.isNotEmpty).toList();

    // Remove the shop from the list
    shops.removeWhere((shopData) => shopData.startsWith('$shopId:'));

    await session.setString('user_shops_$email', shops.join('|'));
    print('DEBUG: Removed shop $shopId from user shops list');
  }

  /// Get all shops for the current user
  Future<List<Shop>> getUserShops() async {
    final email = await session.getString('google_email');
    if (email == null) return [];

    // For now, return shops from local database
    // In the future, this could also include Drive-discovered shops
    return await (db.select(
      db.shops,
    )..where((t) => t.email.equals(email))).get();
  }

  /// Create a new shop
  Future<Shop> createShop({
    required String name,
    required String email,
    String? key,
    String? appPassword,
  }) async {
    final shopId = _generateShopId(name);

    final shop = ShopsCompanion.insert(
      id: shopId,
      name: name,
      email: email,
      ownerName: 'Owner', // Default value
      country: 'Unknown', // Default value
      city: 'Unknown', // Default value
      key: key ?? _generateKey(),
      appPassword: appPassword ?? _generateAppPassword(),
      createdAt: DateTime.now(),
    );

    await db.into(db.shops).insert(shop);

    final createdShop = await (db.select(
      db.shops,
    )..where((t) => t.id.equals(shopId))).getSingle();

    // Emit sync operation for shop creation
    final syncRepo = SyncOpsRepo(db);
    await syncRepo.emitShopUpsert(createdShop);
    print(
      'DEBUG: Emitted shop creation sync operation for: ${createdShop.name}',
    );

    return createdShop;
  }

  String _generateShopId(String name) {
    final slug = name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    final suffix = DateTime.now().millisecondsSinceEpoch
        .toRadixString(36)
        .substring(0, 4);
    return slug.isEmpty ? 'shop-$suffix' : '$slug-$suffix';
  }

  String _generateKey() {
    return 'key-${DateTime.now().millisecondsSinceEpoch}';
  }

  String _generateAppPassword() {
    return 'pwd-${DateTime.now().millisecondsSinceEpoch}';
  }
}

/// Shop events for UI notifications
class ShopEvents {
  static final ShopEvents _instance = ShopEvents._internal();
  factory ShopEvents() => _instance;
  ShopEvents._internal();

  static ShopEvents get instance => _instance;

  final List<ShopEvent> _events = [];
  final List<void Function(ShopEvent)> _listeners = [];

  void add(ShopEvent event) {
    _events.add(event);
    for (final listener in _listeners) {
      listener(event);
    }
  }

  void listen(void Function(ShopEvent) listener) {
    _listeners.add(listener);
  }

  void removeListener(void Function(ShopEvent) listener) {
    _listeners.remove(listener);
  }

  List<ShopEvent> get events => List.unmodifiable(_events);
}

/// Base class for shop events
abstract class ShopEvent {
  final String shopId;
  final DateTime timestamp;

  ShopEvent(this.shopId) : timestamp = DateTime.now();
}

/// Event fired when a shop is deleted
class ShopDeleted extends ShopEvent {
  ShopDeleted(String shopId) : super(shopId);
}

/// Event fired when a shop is created
class ShopCreated extends ShopEvent {
  final String shopName;

  ShopCreated(String shopId, this.shopName) : super(shopId);
}

/// Event fired when a shop is selected
class ShopSelected extends ShopEvent {
  final String shopName;

  ShopSelected(String shopId, this.shopName) : super(shopId);
}
