import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drift/drift.dart';
import '../data/local/database.dart';
import 'supabase_client.dart';
import 'storage_service.dart';

/// Migration service for moving from Google Drive to Supabase
class MigrationService {
  final AppDatabase _db;
  final StorageService _storageService;

  static const _migrationCompleteKey = 'supabase_migration_complete';
  static const _migrationVersionKey = 'migration_version';
  static const _currentMigrationVersion = 1;

  MigrationService(this._db, this._storageService);

  /// Check if migration is needed
  Future<bool> needsMigration() async {
    final prefs = await SharedPreferences.getInstance();
    final isComplete = prefs.getBool(_migrationCompleteKey) ?? false;
    final version = prefs.getInt(_migrationVersionKey) ?? 0;

    return !isComplete || version < _currentMigrationVersion;
  }

  /// Check if migration was completed
  Future<bool> isMigrationComplete() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_migrationCompleteKey) ?? false;
  }

  /// Perform migration
  Future<MigrationResult> migrate({
    required String shopId,
    required String userId,
    Function(String)? onProgress,
    Function(double)? onProgressPercent,
  }) async {
    final startTime = DateTime.now();
    final result = MigrationResult();

    try {
      onProgress?.call('Starting migration...');
      onProgressPercent?.call(0.0);

      // Step 1: Migrate categories (10%)
      onProgress?.call('Migrating categories...');
      final categoriesCount = await _migrateCategories(shopId, userId);
      result.categoriesMigrated = categoriesCount;
      onProgressPercent?.call(0.1);

      // Step 2: Migrate products (25%)
      onProgress?.call('Migrating products...');
      final productsCount = await _migrateProducts(shopId, userId);
      result.productsMigrated = productsCount;
      onProgressPercent?.call(0.25);

      // Step 3: Migrate product images (40%)
      onProgress?.call('Migrating product images...');
      final imagesCount = await _migrateProductImages(shopId);
      result.imagesMigrated = imagesCount;
      onProgressPercent?.call(0.4);

      // Step 4: Migrate inventory (50%)
      onProgress?.call('Migrating inventory...');
      final inventoryCount = await _migrateInventory(shopId, userId);
      result.inventoryMigrated = inventoryCount;
      onProgressPercent?.call(0.5);

      // Step 5: Migrate customers (60%)
      onProgress?.call('Migrating customers...');
      final customersCount = await _migrateCustomers(shopId, userId);
      result.customersMigrated = customersCount;
      onProgressPercent?.call(0.6);

      // Step 6: Migrate orders (75%)
      onProgress?.call('Migrating orders...');
      final ordersCount = await _migrateOrders(shopId, userId);
      result.ordersMigrated = ordersCount;
      onProgressPercent?.call(0.75);

      // Step 7: Migrate order items (85%)
      onProgress?.call('Migrating order items...');
      final orderItemsCount = await _migrateOrderItems(shopId, userId);
      result.orderItemsMigrated = orderItemsCount;
      onProgressPercent?.call(0.85);

      // Step 8: Migrate payments (90%)
      onProgress?.call('Migrating payments...');
      final paymentsCount = await _migratePayments(shopId, userId);
      result.paymentsMigrated = paymentsCount;
      onProgressPercent?.call(0.9);

      // Step 9: Migrate receipt images (95%)
      onProgress?.call('Migrating receipt images...');
      final receiptsCount = await _migrateReceiptImages(shopId);
      result.receiptsMigrated = receiptsCount;
      onProgressPercent?.call(0.95);

      // Step 10: Mark migration complete
      onProgress?.call('Finalizing migration...');
      await _markMigrationComplete();
      onProgressPercent?.call(1.0);

      result.success = true;
      result.duration = DateTime.now().difference(startTime);
      result.message = 'Migration completed successfully!';

      debugPrint(
        'Migration completed: ${result.totalMigrated} items in ${result.duration.inSeconds}s',
      );
      return result;
    } catch (e, stackTrace) {
      debugPrint('Migration failed: $e');
      debugPrint('StackTrace: $stackTrace');

      result.success = false;
      result.error = e.toString();
      result.duration = DateTime.now().difference(startTime);
      result.message = 'Migration failed: ${e.toString()}';

      return result;
    }
  }

  /// Migrate categories
  Future<int> _migrateCategories(String shopId, String userId) async {
    // Get local categories
    final localCategories = await _db.select(_db.categories).get();

    if (localCategories.isEmpty) return 0;

    // Push to Supabase
    final categoryData = localCategories
        .map(
          (cat) => {
            'id': cat.id,
            'shop_id': shopId,
            'name': cat.name,
            'description': cat.description,
            'parent_id': cat.parentId,
            'color': cat.color,
            'icon': cat.icon,
            'sort_order': cat.sortOrder,
            'is_active': cat.isActive,
            'created_by': userId,
            'updated_by': userId,
            'created_at': cat.createdAt.toIso8601String(),
            'updated_at': cat.updatedAt.toIso8601String(),
          },
        )
        .toList();

    await SupabaseService.client.from('categories').upsert(categoryData);

    return categoryData.length;
  }

  /// Migrate products
  Future<int> _migrateProducts(String shopId, String userId) async {
    final localProducts = await _db.select(_db.products).get();

    if (localProducts.isEmpty) return 0;

    final productData = localProducts
        .map(
          (prod) => {
            'id': prod.id,
            'shop_id': shopId,
            'category_id': prod.categoryId,
            'sku': prod.sku,
            'barcode': prod.barcode,
            'name': prod.name,
            'description': prod.description,
            'price_cents': prod.priceCents,
            'cost_cents': prod.costCents,
            'tax_rate': prod.taxRate,
            'track_inventory': prod.trackInventory,
            'reorder_level': prod.reorderLevel,
            'reorder_quantity': prod.reorderQuantity,
            'image_path': prod.imagePath,
            'image_url': prod.imageUrl,
            'is_active': prod.isActive,
            'is_featured': prod.isFeatured,
            'created_by': userId,
            'updated_by': userId,
            'created_at': prod.createdAt.toIso8601String(),
            'updated_at': prod.updatedAt.toIso8601String(),
          },
        )
        .toList();

    await SupabaseService.client.from('products').upsert(productData);

    return productData.length;
  }

  /// Migrate product images to Supabase Storage
  Future<int> _migrateProductImages(String shopId) async {
    int count = 0;

    final products = await _db.select(_db.products).get();

    for (final product in products) {
      if (product.imagePath == null) continue;

      try {
        final localImageFile = File(product.imagePath!);
        if (!await localImageFile.exists()) continue;

        // Upload to Supabase Storage
        final storagePath = await _storageService.uploadProductImage(
          shopId: shopId,
          productId: product.id,
          imageFile: localImageFile,
        );

        // Get public URL
        final publicUrl = _storageService.getProductImageUrl(storagePath);

        // Update product in Supabase with new image URL
        await SupabaseService.client
            .from('products')
            .update({'image_path': storagePath, 'image_url': publicUrl})
            .eq('id', product.id);

        // Update local DB
        await (_db.update(
          _db.products,
        )..where((t) => t.id.equals(product.id))).write(
          ProductsCompanion(
            imagePath: Value(storagePath),
            imageUrl: Value(publicUrl),
          ),
        );

        count++;
      } catch (e) {
        debugPrint('Error migrating image for product ${product.id}: $e');
        // Continue with next product
      }
    }

    return count;
  }

  /// Migrate inventory
  Future<int> _migrateInventory(String shopId, String userId) async {
    final localInventory = await _db.select(_db.inventory).get();

    if (localInventory.isEmpty) return 0;

    final inventoryData = localInventory
        .map(
          (inv) => {
            'id': inv.id,
            'shop_id': shopId,
            'product_id': inv.productId,
            'on_hand_qty': inv.onHandQty,
            'reserved_qty': inv.reservedQty,
            'last_counted_at': inv.lastCountedAt?.toIso8601String(),
            'created_by': userId,
            'updated_by': userId,
            'created_at': inv.createdAt.toIso8601String(),
            'updated_at': inv.updatedAt.toIso8601String(),
          },
        )
        .toList();

    await SupabaseService.client.from('inventory').upsert(inventoryData);

    return inventoryData.length;
  }

  /// Migrate customers
  Future<int> _migrateCustomers(String shopId, String userId) async {
    final localCustomers = await _db.select(_db.customers).get();

    if (localCustomers.isEmpty) return 0;

    final customerData = localCustomers
        .map(
          (cust) => {
            'id': cust.id,
            'shop_id': shopId,
            'name': cust.name,
            'email': cust.email,
            'phone': cust.phone,
            'address': cust.address,
            'city': cust.city,
            'state': cust.state,
            'loyalty_points': cust.loyaltyPoints,
            'total_spent_cents': cust.totalSpentCents,
            'total_orders': cust.totalOrders,
            'notes': cust.notes,
            'is_active': cust.isActive,
            'created_by': userId,
            'updated_by': userId,
            'created_at': cust.createdAt.toIso8601String(),
            'updated_at': cust.updatedAt.toIso8601String(),
          },
        )
        .toList();

    await SupabaseService.client.from('customers').upsert(customerData);

    return customerData.length;
  }

  /// Migrate orders
  Future<int> _migrateOrders(String shopId, String userId) async {
    final localOrders = await _db.select(_db.orders).get();

    if (localOrders.isEmpty) return 0;

    final orderData = localOrders
        .map(
          (order) => {
            'id': order.id,
            'shop_id': shopId,
            'customer_id': order.customerId,
            'order_number': order.orderNumber,
            'status': order.status,
            'channel': order.channel,
            'subtotal_cents': order.subtotalCents,
            'discount_cents': order.discountCents,
            'tax_cents': order.taxCents,
            'total_cents': order.totalCents,
            'amount_paid_cents': order.amountPaidCents,
            'ordered_at': order.orderedAt.toIso8601String(),
            'paid_at': order.paidAt?.toIso8601String(),
            'completed_at': order.completedAt?.toIso8601String(),
            'notes': order.notes,
            'device_id': order.deviceId,
            'created_by': userId,
            'updated_by': userId,
            'created_at': order.createdAt.toIso8601String(),
            'updated_at': order.updatedAt.toIso8601String(),
          },
        )
        .toList();

    await SupabaseService.client.from('orders').upsert(orderData);

    return orderData.length;
  }

  /// Migrate order items
  Future<int> _migrateOrderItems(String shopId, String userId) async {
    final localOrderItems = await _db.select(_db.orderItems).get();

    if (localOrderItems.isEmpty) return 0;

    final orderItemData = localOrderItems
        .map(
          (item) => {
            'id': item.id,
            'shop_id': shopId,
            'order_id': item.orderId,
            'product_id': item.productId,
            'product_name': item.productName,
            'product_sku': item.productSku,
            'quantity': item.quantity,
            'unit_price_cents': item.unitPriceCents,
            'discount_cents': item.discountCents,
            'tax_rate': item.taxRate,
            'tax_cents': item.taxCents,
            'line_total_cents': item.lineTotalCents,
            'notes': item.notes,
            'created_by': userId,
            'updated_by': userId,
            'created_at': item.createdAt.toIso8601String(),
            'updated_at': item.updatedAt.toIso8601String(),
          },
        )
        .toList();

    await SupabaseService.client.from('order_items').upsert(orderItemData);

    return orderItemData.length;
  }

  /// Migrate payments
  Future<int> _migratePayments(String shopId, String userId) async {
    final localPayments = await _db.select(_db.payments).get();

    if (localPayments.isEmpty) return 0;

    final paymentData = localPayments
        .map(
          (payment) => {
            'id': payment.id,
            'shop_id': shopId,
            'order_id': payment.orderId,
            'method': payment.method,
            'amount_cents': payment.amountCents,
            'transaction_ref': payment.transactionRef,
            'receipt_path': payment.receiptPath,
            'receipt_url': payment.receiptUrl,
            'status': payment.status,
            'processed_at': payment.processedAt.toIso8601String(),
            'notes': payment.notes,
            'created_by': userId,
            'updated_by': userId,
            'created_at': payment.createdAt.toIso8601String(),
            'updated_at': payment.updatedAt.toIso8601String(),
          },
        )
        .toList();

    await SupabaseService.client.from('payments').upsert(paymentData);

    return paymentData.length;
  }

  /// Migrate receipt images
  Future<int> _migrateReceiptImages(String shopId) async {
    int count = 0;

    final payments = await _db.select(_db.payments).get();

    for (final payment in payments) {
      if (payment.receiptPath == null) continue;

      try {
        final localReceiptFile = File(payment.receiptPath!);
        if (!await localReceiptFile.exists()) continue;

        // Upload to Supabase Storage
        final storagePath = await _storageService.uploadReceipt(
          shopId: shopId,
          orderId: payment.orderId,
          receiptFile: localReceiptFile,
        );

        // Update payment in Supabase
        await SupabaseService.client
            .from('payments')
            .update({'receipt_path': storagePath})
            .eq('id', payment.id);

        // Update local DB
        await (_db.update(_db.payments)..where((t) => t.id.equals(payment.id)))
            .write(PaymentsCompanion(receiptPath: Value(storagePath)));

        count++;
      } catch (e) {
        debugPrint('Error migrating receipt for payment ${payment.id}: $e');
      }
    }

    return count;
  }

  /// Mark migration as complete
  Future<void> _markMigrationComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_migrationCompleteKey, true);
    await prefs.setInt(_migrationVersionKey, _currentMigrationVersion);
  }

  /// Reset migration (for testing)
  Future<void> resetMigration() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_migrationCompleteKey);
    await prefs.remove(_migrationVersionKey);
  }
}

/// Migration result class
class MigrationResult {
  bool success = false;
  String? error;
  String message = '';
  Duration duration = Duration.zero;

  int categoriesMigrated = 0;
  int productsMigrated = 0;
  int imagesMigrated = 0;
  int inventoryMigrated = 0;
  int customersMigrated = 0;
  int ordersMigrated = 0;
  int orderItemsMigrated = 0;
  int paymentsMigrated = 0;
  int receiptsMigrated = 0;

  int get totalMigrated =>
      categoriesMigrated +
      productsMigrated +
      imagesMigrated +
      inventoryMigrated +
      customersMigrated +
      ordersMigrated +
      orderItemsMigrated +
      paymentsMigrated +
      receiptsMigrated;

  Map<String, int> get summary => {
    'categories': categoriesMigrated,
    'products': productsMigrated,
    'images': imagesMigrated,
    'inventory': inventoryMigrated,
    'customers': customersMigrated,
    'orders': ordersMigrated,
    'order_items': orderItemsMigrated,
    'payments': paymentsMigrated,
    'receipts': receiptsMigrated,
  };
}
