import 'dart:convert';
import '../local/app_database.dart';
import '../../common/uuid.dart';

class SyncOpsRepo {
  final AppDatabase db;
  SyncOpsRepo(this.db);

  Future<void> emitItemUpsert(Item item) async => _emit(
    entity: 'item',
    op: 'upsert',
    payload: {
      'id': item.id,
      'shopId': item.shopId, // CRITICAL: Include shop_id for sync
      'name': item.name,
      'price': item.salePrice,
      'minQty': item.minQty,
      'isActive': item.isActive,
      'ts': DateTime.now().millisecondsSinceEpoch,
    },
  );

  Future<void> emitItemDelete(String itemId, String shopId) async => _emit(
    entity: 'item',
    op: 'delete',
    payload: {
      'id': itemId,
      'shopId': shopId, // CRITICAL: Include shop_id for sync
      'ts': DateTime.now().millisecondsSinceEpoch,
    },
  );

  Future<void> emitStockAdjust(
    String itemId,
    String shopId, // Add shop_id parameter
    double delta,
    String reason,
  ) async => _emit(
    entity: 'stock',
    op: 'adjust',
    payload: {
      'itemId': itemId,
      'shopId': shopId, // CRITICAL: Include shop_id for sync
      'delta': delta,
      'reason': reason,
      'ts': DateTime.now().millisecondsSinceEpoch,
    },
  );

  Future<void> emitSaleCreate(Sale sale, List<SaleItem> lines) async => _emit(
    entity: 'sale',
    op: 'create',
    payload: {
      'sale': {
        'id': sale.id,
        'shopId': sale.shopId,
        'totalAmount': sale.totalAmount,
        'byUserId': sale.byUserId,
        'createdAt': sale.createdAt.millisecondsSinceEpoch,
      },
      'lines': lines
          .map(
            (e) => {
              'id': e.id,
              'saleId': e.saleId,
              'itemId': e.itemId,
              'itemName': e.itemName,
              'quantity': e.quantity,
              'unitPrice': e.unitPrice,
              'totalPrice': e.totalPrice,
            },
          )
          .toList(),
      'ts': DateTime.now().millisecondsSinceEpoch,
    },
  );

  Future<void> emitUserUpsert(User user) async => _emit(
    entity: 'user',
    op: 'upsert',
    payload: {
      'id': user.id,
      'shopId': user.shopId,
      'name': user.name,
      'email': user.email,
      'role': user.role,
      'isActive': user.isActive,
      'createdAt': user.createdAt.millisecondsSinceEpoch,
      'ts': DateTime.now().millisecondsSinceEpoch,
    },
  );

  Future<void> emitShopUpsert(Shop shop) async => _emit(
    entity: 'shop',
    op: 'upsert',
    payload: {
      'id': shop.id,
      'name': shop.name,
      'email': shop.email,
      'key': shop.key,
      'appPassword': shop.appPassword,
      'createdAt': shop.createdAt.millisecondsSinceEpoch,
      'ts': DateTime.now().millisecondsSinceEpoch,
    },
  );

  /// Sync all existing data for a shop (useful for initial sync)
  Future<void> syncAllExistingData(String shopId) async {
    print('DEBUG: Starting full data sync for shop: $shopId');

    // Sync all items
    final items = await (db.select(
      db.items,
    )..where((t) => t.shopId.equals(shopId))).get();
    for (final item in items) {
      await emitItemUpsert(item);
    }
    print('DEBUG: Synced ${items.length} items');

    // Sync all users
    final users = await (db.select(
      db.users,
    )..where((t) => t.shopId.equals(shopId))).get();
    for (final user in users) {
      await emitUserUpsert(user);
    }
    print('DEBUG: Synced ${users.length} users');

    // Sync all shops
    final shops = await (db.select(
      db.shops,
    )..where((t) => t.id.equals(shopId))).get();
    for (final shop in shops) {
      await emitShopUpsert(shop);
    }
    print('DEBUG: Synced ${shops.length} shops');

    // Sync all sales
    final sales = await (db.select(
      db.sales,
    )..where((t) => t.shopId.equals(shopId))).get();
    for (final sale in sales) {
      final saleItems = await (db.select(
        db.saleItems,
      )..where((t) => t.saleId.equals(sale.id))).get();
      await emitSaleCreate(sale, saleItems);
    }
    print('DEBUG: Synced ${sales.length} sales');

    print('DEBUG: Completed full data sync for shop: $shopId');
  }

  Future<void> _emit({
    required String entity,
    required String op,
    required Map<String, dynamic> payload,
  }) async {
    final id = newId();
    await db
        .into(db.syncOps)
        .insert(
          SyncOpsCompanion.insert(
            uuid: id,
            entity: entity,
            op: op,
            payload: jsonEncode(payload),
            ts: DateTime.now().millisecondsSinceEpoch,
          ),
        );
    print('DEBUG: Stored sync operation - entity: $entity, op: $op, id: $id');
  }
}
