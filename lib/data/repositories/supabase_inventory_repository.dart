import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/product.dart';

/// Sale line item for perform_sale RPC
class SaleLine {
  final String productId;
  final num qty; // allow decimals if app supports it
  final int unitPriceCents;

  const SaleLine({
    required this.productId,
    required this.qty,
    required this.unitPriceCents,
  });

  Map<String, dynamic> toJson() => {
    'product_id': productId,
    'qty': qty,
    'unit_price_cents': unitPriceCents,
  };
}

/// Repository for inventory operations using Supabase
class SupabaseInventoryRepository {
  final SupabaseClient _client;

  SupabaseInventoryRepository([SupabaseClient? client])
    : _client = client ?? Supabase.instance.client;

  // =====================================================
  // PRODUCTS
  // =====================================================

  /// Get all products for a shop with inventory
  Future<List<Product>> getProducts({
    required String shopId,
    bool activeOnly = false,
  }) async {
    try {
      if (kDebugMode) {
        print(
          '[DEBUG] getProducts: shopId=$shopId, activeOnly=$activeOnly, table=products+inventory',
        );
      }

      // Build query with all filters before awaiting
      final queryBuilder = _client
          .from('products')
          .select('''
            id, shop_id, category_id, sku, name, price_cents, cost_cents,
            tax_rate, barcode, image_path, is_active, reorder_level,
            created_at, updated_at, last_modified, deleted_at, version,
            created_by, updated_by,
            inventory(product_id, shop_id, on_hand_qty, on_reserved_qty, 
                     created_at, updated_at, last_modified, version)
          ''')
          .eq('shop_id', shopId)
          .isFilter('deleted_at', null);

      // Apply active filter if needed
      final query = activeOnly
          ? queryBuilder.eq('is_active', true).order('name')
          : queryBuilder.order('name');

      final List<dynamic> rows = await query;

      if (kDebugMode)
        print('[DEBUG] getProducts: returned ${rows.length} products');
      return rows.map((row) => Product.fromJson(row)).toList();
    } catch (e) {
      if (kDebugMode) print('[ERROR] getProducts: shopId=$shopId, error=$e');
      rethrow;
    }
  }

  /// Get a single product by ID with inventory
  Future<Product?> getProduct({
    required String productId,
    required String shopId,
  }) async {
    try {
      final row = await _client
          .from('products')
          .select('''
            id, shop_id, category_id, sku, name, price_cents, cost_cents,
            tax_rate, barcode, image_path, is_active, reorder_level,
            created_at, updated_at, last_modified, deleted_at, version,
            created_by, updated_by,
            inventory(product_id, shop_id, on_hand_qty, on_reserved_qty,
                     created_at, updated_at, last_modified, version)
          ''')
          .eq('id', productId)
          .eq('shop_id', shopId)
          .isFilter('deleted_at', null)
          .maybeSingle();

      if (row == null) return null;
      return Product.fromJson(row);
    } catch (e) {
      print('ERROR: SupabaseInventoryRepository.getProduct() - $e');
      rethrow;
    }
  }

  /// Get products by barcode
  Future<Product?> getProductByBarcode({
    required String barcode,
    required String shopId,
  }) async {
    try {
      final row = await _client
          .from('products')
          .select('''
            id, shop_id, category_id, sku, name, price_cents, cost_cents,
            tax_rate, barcode, image_path, is_active, reorder_level,
            created_at, updated_at, last_modified, deleted_at, version,
            created_by, updated_by,
            inventory(product_id, shop_id, on_hand_qty, on_reserved_qty,
                     created_at, updated_at, last_modified, version)
          ''')
          .eq('barcode', barcode)
          .eq('shop_id', shopId)
          .eq('is_active', true)
          .isFilter('deleted_at', null)
          .maybeSingle();

      if (row == null) return null;
      return Product.fromJson(row);
    } catch (e) {
      print('ERROR: SupabaseInventoryRepository.getProductByBarcode() - $e');
      rethrow;
    }
  }

  /// Get low stock products
  Future<List<Product>> getLowStockProducts({required String shopId}) async {
    try {
      final products = await getProducts(shopId: shopId, activeOnly: true);

      // Filter products where on_hand_qty <= reorder_level
      return products.where((p) => p.isLowStock).toList();
    } catch (e) {
      print('ERROR: SupabaseInventoryRepository.getLowStockProducts() - $e');
      rethrow;
    }
  }

  /// Create a new product
  Future<Product> createProduct({
    required String shopId,
    required String name,
    required int priceCents,
    String? sku,
    String? barcode,
    String? categoryId,
    int? costCents,
    double taxRate = 0.0,
    String? imagePath,
    int reorderLevel = 0,
    int initialQty = 0,
  }) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (kDebugMode) {
        print(
          '[DEBUG] createProduct: shopId=$shopId, name=$name, initialQty=$initialQty, table=products',
        );
      }

      // Insert product
      final productRow = await _client
          .from('products')
          .insert({
            'shop_id': shopId,
            'name': name,
            'sku': sku,
            'price_cents': priceCents,
            'cost_cents': costCents,
            'tax_rate': taxRate,
            'barcode': barcode,
            'category_id': categoryId,
            'image_path': imagePath,
            'is_active': true,
            'reorder_level': reorderLevel,
            'created_by': userId,
            'updated_by': userId,
          })
          .select()
          .single();

      final product = Product.fromJson(productRow);
      if (kDebugMode)
        print('[DEBUG] createProduct: product created, id=${product.id}');

      // Create inventory record with initial stock
      final initialStock = initialQty > 0 ? initialQty : 0;
      if (kDebugMode) {
        print(
          '[DEBUG] createProduct: creating inventory record with $initialStock stock',
        );
      }

      await _client.from('inventory').upsert({
        'product_id': product.id,
        'shop_id': shopId,
        'on_hand_qty': initialStock,
        'on_reserved_qty': 0,
        'created_by': userId,
        'updated_by': userId,
      });

      if (kDebugMode) {
        print(
          '[DEBUG] inventory seeded ($initialStock) for productId=${product.id}',
        );
      }

      // Record stock movement if initial quantity was provided
      if (initialQty > 0) {
        try {
          await _client.from('stock_movements').insert({
            'product_id': product.id,
            'shop_id': shopId,
            'qty_delta': initialQty,
            'type': 'purchase',
            'reason': 'Initial stock',
            'created_by': userId,
          });
          if (kDebugMode) {
            print('[DEBUG] createProduct: stock movement recorded');
          }
        } catch (e) {
          print('[ERROR] createProduct: Failed to record stock movement: $e');
          // Continue - inventory record was created successfully
        }
      }

      if (kDebugMode) print('[DEBUG] createProduct: completed successfully');
      return product;
    } catch (e) {
      if (kDebugMode)
        print('[ERROR] createProduct: shopId=$shopId, name=$name, error=$e');
      rethrow;
    }
  }

  /// Update a product
  Future<Product> updateProduct({
    required String productId,
    required String shopId,
    String? name,
    int? priceCents,
    int? costCents,
    String? sku,
    String? barcode,
    String? categoryId,
    double? taxRate,
    String? imagePath,
    int? reorderLevel,
    bool? isActive,
  }) async {
    try {
      final userId = _client.auth.currentUser?.id;
      final updates = <String, dynamic>{'updated_by': userId};

      if (name != null) updates['name'] = name;
      if (priceCents != null) updates['price_cents'] = priceCents;
      if (costCents != null) updates['cost_cents'] = costCents;
      if (sku != null) updates['sku'] = sku;
      if (barcode != null) updates['barcode'] = barcode;
      if (categoryId != null) updates['category_id'] = categoryId;
      if (taxRate != null) updates['tax_rate'] = taxRate;
      if (imagePath != null) updates['image_path'] = imagePath;
      if (reorderLevel != null) updates['reorder_level'] = reorderLevel;
      if (isActive != null) updates['is_active'] = isActive;

      final row = await _client
          .from('products')
          .update(updates)
          .eq('id', productId)
          .eq('shop_id', shopId)
          .select()
          .single();

      return Product.fromJson(row);
    } catch (e) {
      print('ERROR: SupabaseInventoryRepository.updateProduct() - $e');
      rethrow;
    }
  }

  /// Soft delete a product
  Future<void> deleteProduct({
    required String productId,
    required String shopId,
  }) async {
    try {
      await _client
          .from('products')
          .update({
            'deleted_at': DateTime.now().toIso8601String(),
            'is_active': false,
          })
          .eq('id', productId)
          .eq('shop_id', shopId);
    } catch (e) {
      print('ERROR: SupabaseInventoryRepository.deleteProduct() - $e');
      rethrow;
    }
  }

  // =====================================================
  // INVENTORY
  // =====================================================

  /// Get inventory for a product
  Future<Inventory?> getInventory({
    required String productId,
    required String shopId,
  }) async {
    try {
      final row = await _client
          .from('inventory')
          .select()
          .eq('product_id', productId)
          .eq('shop_id', shopId)
          .maybeSingle();

      if (row == null) return null;
      return Inventory.fromJson(row);
    } catch (e) {
      print('ERROR: SupabaseInventoryRepository.getInventory() - $e');
      rethrow;
    }
  }

  /// Ensure inventory record exists for a product (creates if missing)
  Future<void> ensureInventoryRecord({
    required String productId,
    required String shopId,
  }) async {
    try {
      if (kDebugMode)
        print(
          '[DEBUG] ensureInventoryRecord: productId=$productId, shopId=$shopId',
        );

      await _client.from('inventory').upsert({
        'product_id': productId,
        'shop_id': shopId,
        'on_hand_qty': 0,
        'on_reserved_qty': 0,
        'created_by': _client.auth.currentUser?.id,
        'updated_by': _client.auth.currentUser?.id,
      });

      if (kDebugMode)
        print(
          '[DEBUG] ensureInventoryRecord: inventory record ensured for productId=$productId',
        );
    } catch (e) {
      print('[ERROR] ensureInventoryRecord: productId=$productId, error=$e');
      rethrow;
    }
  }

  /// Fix existing products that don't have inventory records
  Future<int> fixMissingInventoryRecords({required String shopId}) async {
    try {
      if (kDebugMode)
        print('[DEBUG] fixMissingInventoryRecords: shopId=$shopId');

      // Get all products for the shop
      final products = await _client
          .from('products')
          .select('id')
          .eq('shop_id', shopId)
          .isFilter('deleted_at', null);

      // Get all existing inventory records for the shop
      final existingInventory = await _client
          .from('inventory')
          .select('product_id')
          .eq('shop_id', shopId);

      final existingProductIds = existingInventory
          .map((row) => row['product_id'] as String)
          .toSet();

      // Find products without inventory records
      final missingInventory = products
          .where(
            (product) => !existingProductIds.contains(product['id'] as String),
          )
          .toList();

      if (missingInventory.isEmpty) {
        if (kDebugMode)
          print(
            '[DEBUG] fixMissingInventoryRecords: no missing inventory records found',
          );
        return 0;
      }

      // Create inventory records for missing products
      final inventoryRecords = missingInventory
          .map(
            (product) => {
              'product_id': product['id'] as String,
              'shop_id': shopId,
              'on_hand_qty': 0,
              'on_reserved_qty': 0,
              'created_by': _client.auth.currentUser?.id,
              'updated_by': _client.auth.currentUser?.id,
            },
          )
          .toList();

      await _client.from('inventory').insert(inventoryRecords);

      if (kDebugMode)
        print(
          '[DEBUG] fixMissingInventoryRecords: created ${missingInventory.length} inventory records',
        );

      return missingInventory.length;
    } catch (e) {
      print('[ERROR] fixMissingInventoryRecords: shopId=$shopId, error=$e');
      rethrow;
    }
  }

  /// Adjust stock (using RPC for atomic operation)
  Future<String> adjustStock({
    required String shopId,
    required String productId,
    required int qtyDelta,
    StockMovementType type = StockMovementType.adjustment,
    String? reason,
    String? linkedOrderId,
  }) async {
    try {
      if (kDebugMode) {
        print(
          '[DEBUG] adjustStock: shopId=$shopId, productId=$productId, qtyDelta=$qtyDelta, type=${type.name}, table=inventory+stock_movements',
        );
      }

      // Try RPC first (preferred method)
      try {
        final movementId = await _client.rpc<String>(
          'perform_stock_movement',
          params: {
            'p_shop_id': shopId,
            'p_product_id': productId,
            'p_type': type.name,
            'p_qty_delta': qtyDelta,
            'p_reason': reason,
            'p_linked_order_id': linkedOrderId,
          },
        );

        if (kDebugMode)
          print('[DEBUG] adjustStock: RPC completed, movementId=$movementId');
        return movementId;
      } catch (rpcError) {
        print('[ERROR] adjustStock: RPC failed: $rpcError');
        print('[INFO] adjustStock: falling back to direct inventory update');

        // Fallback: Direct inventory update if RPC is not available
        await _adjustStockFallback(
          shopId: shopId,
          productId: productId,
          qtyDelta: qtyDelta,
          type: type,
          reason: reason,
          linkedOrderId: linkedOrderId,
        );

        return 'fallback-${DateTime.now().millisecondsSinceEpoch}';
      }
    } catch (e) {
      print(
        '[ERROR] adjustStock: shopId=$shopId, productId=$productId, error=$e',
      );
      rethrow;
    }
  }

  /// Fallback method for stock adjustment when RPC is not available
  Future<void> _adjustStockFallback({
    required String shopId,
    required String productId,
    required int qtyDelta,
    StockMovementType type = StockMovementType.adjustment,
    String? reason,
    String? linkedOrderId,
  }) async {
    try {
      // Get current inventory (or 0 if doesn't exist)
      final existingInventory = await _client
          .from('inventory')
          .select('on_hand_qty')
          .eq('product_id', productId)
          .eq('shop_id', shopId)
          .maybeSingle();

      final currentQty = existingInventory?['on_hand_qty'] as int? ?? 0;
      final newQty = currentQty + qtyDelta;
      final finalQty = newQty < 0 ? 0 : newQty;

      if (kDebugMode) {
        print(
          '[DEBUG] adjustStock fallback: currentQty=$currentQty, qtyDelta=$qtyDelta, finalQty=$finalQty',
        );
      }

      // Upsert inventory with the new quantity
      await _client.from('inventory').upsert({
        'product_id': productId,
        'shop_id': shopId,
        'on_hand_qty': finalQty,
        'on_reserved_qty': 0,
        'updated_by': _client.auth.currentUser?.id,
      });

      // Record stock movement
      await _client.from('stock_movements').insert({
        'product_id': productId,
        'shop_id': shopId,
        'qty_delta': qtyDelta,
        'type': type.name,
        'reason': reason,
        'linked_order_id': linkedOrderId,
        'created_by': _client.auth.currentUser?.id,
      });

      if (kDebugMode)
        print('[DEBUG] adjustStock: fallback completed, finalQty=$finalQty');
    } catch (e) {
      print('[ERROR] adjustStock fallback failed: $e');
      rethrow;
    }
  }

  /// Process sale (decrement inventory)
  Future<String> processSale({
    required String shopId,
    required String productId,
    required int qtySold,
    String? orderId,
  }) async {
    try {
      final movementId = await _client.rpc<String>(
        'perform_sale_inventory_adjustment',
        params: {
          'p_shop_id': shopId,
          'p_product_id': productId,
          'p_qty_sold': qtySold,
          'p_order_id': orderId,
        },
      );

      return movementId;
    } catch (e) {
      print('ERROR: SupabaseInventoryRepository.processSale() - $e');
      rethrow;
    }
  }

  // =====================================================
  // STOCK MOVEMENTS
  // =====================================================

  /// Get stock movements for a product
  Future<List<StockMovement>> getStockMovements({
    required String shopId,
    String? productId,
    int limit = 100,
  }) async {
    try {
      // Build query with all filters before awaiting
      final queryBuilder = _client
          .from('stock_movements')
          .select('''
            id, shop_id, product_id, type, qty_delta, reason, linked_order_id,
            created_at, updated_at, last_modified, deleted_at, version,
            created_by, updated_by
          ''')
          .eq('shop_id', shopId);

      // Apply product filter if specified
      final query = productId != null
          ? queryBuilder
                .eq('product_id', productId)
                .order('created_at', ascending: false)
                .limit(limit)
          : queryBuilder.order('created_at', ascending: false).limit(limit);

      final List<dynamic> rows = await query;

      return rows.map((row) => StockMovement.fromJson(row)).toList();
    } catch (e) {
      print('ERROR: SupabaseInventoryRepository.getStockMovements() - $e');
      rethrow;
    }
  }

  // =====================================================
  // REALTIME SUBSCRIPTIONS
  // =====================================================

  /// Subscribe to product changes
  RealtimeChannel subscribeToProducts({
    required String shopId,
    required void Function(Product) onInsert,
    required void Function(Product) onUpdate,
    required void Function(String) onDelete,
  }) {
    final channel = _client.channel('products-$shopId');
    if (kDebugMode) print('[RT] Subscribing to products table, shopId=$shopId');

    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'products',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'shop_id',
            value: shopId,
          ),
          callback: (payload) {
            if (kDebugMode) {
              print(
                '[RT] products change: ${payload.table} ${payload.eventType.name} id=${payload.newRecord['id']}, name=${payload.newRecord['name']}, shop_id=${payload.newRecord['shop_id']}',
              );
            }
            final product = Product.fromJson(payload.newRecord);
            onInsert(product);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'products',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'shop_id',
            value: shopId,
          ),
          callback: (payload) {
            if (kDebugMode) {
              print(
                '[RT] products change: ${payload.table} ${payload.eventType.name} id=${payload.newRecord['id']}, name=${payload.newRecord['name']}, shop_id=${payload.newRecord['shop_id']}',
              );
            }
            final product = Product.fromJson(payload.newRecord);
            onUpdate(product);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'products',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'shop_id',
            value: shopId,
          ),
          callback: (payload) {
            if (kDebugMode) {
              print(
                '[RT] products change: ${payload.table} ${payload.eventType.name} id=${payload.oldRecord['id']}, shop_id=${payload.oldRecord['shop_id']}',
              );
            }
            final productId = payload.oldRecord['id'] as String;
            onDelete(productId);
          },
        )
        .subscribe();

    return channel;
  }

  /// Subscribe to inventory changes
  RealtimeChannel subscribeToInventory({
    required String shopId,
    required void Function() onChange,
  }) {
    final channel = _client.channel('inventory-$shopId');
    if (kDebugMode)
      print('[RT] Subscribing to inventory table, shopId=$shopId');

    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'inventory',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'shop_id',
            value: shopId,
          ),
          callback: (payload) {
            final productId =
                payload.newRecord['product_id'] ??
                payload.oldRecord['product_id'];
            final onHandQty = payload.newRecord['on_hand_qty'];
            if (kDebugMode) {
              print(
                '[RT] inventory change: ${payload.table} ${payload.eventType.name} product_id=$productId, on_hand_qty=$onHandQty, shop_id=${payload.newRecord['shop_id'] ?? payload.oldRecord['shop_id']}',
              );
            }
            onChange();
          },
        )
        .subscribe();

    return channel;
  }

  // =====================================================
  // SALES
  // =====================================================

  /// Calls SQL function public.perform_sale and returns (orderId, totalCents)
  Future<({String orderId, int totalCents})> performSale({
    required String shopId,
    required List<SaleLine> items,
    String channel = 'in_store',
    String? customerId,
    String paymentMethod = 'cash', // 'cash'|'card'|'transfer'
    int amountCents = 0, // amount actually paid (for immediate payments)
  }) async {
    assert(items.isNotEmpty, 'Sale must have at least one line');

    final payload = {
      'p_shop_id': shopId,
      'p_items': items.map((e) => e.toJson()).toList(),
      'p_channel': channel,
      'p_customer_id': customerId,
      'p_payment_method': paymentMethod,
      'p_amount_cents': amountCents,
    };

    if (kDebugMode) {
      print('[DEBUG] performSale payload = $payload');
    }

    try {
      final resp = await _client
          .rpc('perform_sale', params: payload)
          .single(); // returns { order_id: uuid, total_cents: int }

      final orderId = (resp['order_id'] ?? resp['orderId']).toString();
      final totalCents =
          (resp['total_cents'] ?? resp['totalCents'] ?? 0) as int;

      if (kDebugMode) {
        print(
          '[DEBUG] performSale success: orderId=$orderId, totalCents=$totalCents',
        );
      }

      return (orderId: orderId, totalCents: totalCents);
    } catch (e) {
      print('[ERROR] performSale failed: $e');
      rethrow;
    }
  }
}
