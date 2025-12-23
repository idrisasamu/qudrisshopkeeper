import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/models/product.dart';
import '../data/repositories/supabase_inventory_repository.dart';
import '../common/session.dart';

// =====================================================
// REPOSITORY PROVIDER
// =====================================================

final inventoryRepositoryProvider = Provider<SupabaseInventoryRepository>((
  ref,
) {
  return SupabaseInventoryRepository(Supabase.instance.client);
});

// =====================================================
// INVENTORY FIX PROVIDERS
// =====================================================

/// Provider to fix missing inventory records for existing products
final fixMissingInventoryProvider = FutureProvider.autoDispose<int>((
  ref,
) async {
  final repository = ref.read(inventoryRepositoryProvider);
  final sessionManager = SessionManager();
  final shopId = await sessionManager.getString('shop_id');

  if (shopId == null || shopId.isEmpty) {
    return 0;
  }

  try {
    final fixedCount = await repository.fixMissingInventoryRecords(
      shopId: shopId,
    );
    if (kDebugMode) {
      print(
        '[DEBUG] fixMissingInventoryProvider: fixed $fixedCount inventory records',
      );
    }
    return fixedCount;
  } catch (e) {
    print('[ERROR] fixMissingInventoryProvider: $e');
    rethrow;
  }
});

// =====================================================
// PRODUCTS PROVIDERS
// =====================================================

/// Provider for all products in the current shop
final productsProvider = StreamProvider.autoDispose<List<Product>>((
  ref,
) async* {
  final repository = ref.read(inventoryRepositoryProvider);
  final sessionManager = SessionManager();
  final shopId = await sessionManager.getString('shop_id');

  if (shopId == null || shopId.isEmpty) {
    yield [];
    return;
  }

  // Create a stream controller to emit fresh data immediately
  final controller = StreamController<List<Product>>();

  // Helper function to fetch and emit fresh data
  Future<void> fetchAndEmitFreshData() async {
    try {
      final freshProducts = await repository.getProducts(shopId: shopId);
      if (!controller.isClosed) {
        controller.add(freshProducts);
      }
    } catch (e) {
      if (!controller.isClosed) {
        controller.addError(e);
      }
    }
  }

  // Initial fetch
  await fetchAndEmitFreshData();

  // Subscribe to product changes (name, price, etc.)
  final productsChannel = repository.subscribeToProducts(
    shopId: shopId,
    onInsert: (product) async {
      // Immediately fetch and emit fresh data when new product added
      if (kDebugMode)
        print('🔄 Real-time: Product inserted, refreshing inventory...');
      await fetchAndEmitFreshData();
    },
    onUpdate: (product) async {
      // Immediately fetch and emit fresh data when product updated
      if (kDebugMode)
        print('🔄 Real-time: Product updated, refreshing inventory...');
      await fetchAndEmitFreshData();
    },
    onDelete: (productId) async {
      // Immediately fetch and emit fresh data when product deleted
      if (kDebugMode)
        print('🔄 Real-time: Product deleted, refreshing inventory...');
      await fetchAndEmitFreshData();
    },
  );

  // Subscribe to inventory changes (stock quantities)
  final inventoryChannel = repository.subscribeToInventory(
    shopId: shopId,
    onChange: () async {
      // Immediately fetch and emit fresh data when inventory changes
      if (kDebugMode)
        print('🔄 Real-time: Inventory changed, refreshing stock levels...');
      await fetchAndEmitFreshData();
    },
  );

  // Cleanup subscriptions when provider is disposed
  ref.onDispose(() {
    productsChannel.unsubscribe();
    inventoryChannel.unsubscribe();
    controller.close();
  });

  // Emit data from controller and keep stream alive
  await for (final products in controller.stream) {
    yield products;
  }
});

/// Provider for active products only
final activeProductsProvider = StreamProvider.autoDispose<List<Product>>((
  ref,
) async* {
  final repository = ref.read(inventoryRepositoryProvider);
  final sessionManager = SessionManager();
  final shopId = await sessionManager.getString('shop_id');

  if (shopId == null || shopId.isEmpty) {
    yield [];
    return;
  }

  // Create a stream controller to emit fresh data immediately
  final controller = StreamController<List<Product>>();

  // Helper function to fetch and emit fresh data
  Future<void> fetchAndEmitFreshData() async {
    try {
      final freshProducts = await repository.getProducts(
        shopId: shopId,
        activeOnly: true,
      );
      if (!controller.isClosed) {
        controller.add(freshProducts);
      }
    } catch (e) {
      if (!controller.isClosed) {
        controller.addError(e);
      }
    }
  }

  // Initial fetch
  await fetchAndEmitFreshData();

  // Subscribe to product changes (name, price, etc.)
  final productsChannel = repository.subscribeToProducts(
    shopId: shopId,
    onInsert: (_) async {
      if (kDebugMode)
        print('🔄 Real-time: Product inserted, refreshing active products...');
      await fetchAndEmitFreshData();
    },
    onUpdate: (_) async {
      if (kDebugMode)
        print('🔄 Real-time: Product updated, refreshing active products...');
      await fetchAndEmitFreshData();
    },
    onDelete: (_) async {
      if (kDebugMode)
        print('🔄 Real-time: Product deleted, refreshing active products...');
      await fetchAndEmitFreshData();
    },
  );

  // Subscribe to inventory changes (stock quantities)
  final inventoryChannel = repository.subscribeToInventory(
    shopId: shopId,
    onChange: () async {
      if (kDebugMode)
        print('🔄 Real-time: Inventory changed, refreshing active products...');
      await fetchAndEmitFreshData();
    },
  );

  // Cleanup subscriptions when provider is disposed
  ref.onDispose(() {
    productsChannel.unsubscribe();
    inventoryChannel.unsubscribe();
    controller.close();
  });

  // Emit data from controller and keep stream alive
  await for (final products in controller.stream) {
    yield products;
  }
});

/// Provider for a single product by ID
final productProvider = FutureProvider.autoDispose.family<Product?, String>((
  ref,
  productId,
) async {
  final repository = ref.read(inventoryRepositoryProvider);
  final sessionManager = SessionManager();
  final shopId = await sessionManager.getString('shop_id');

  if (shopId == null || shopId.isEmpty) {
    return null;
  }

  return repository.getProduct(productId: productId, shopId: shopId);
});

/// Provider for product by barcode
final productByBarcodeProvider = FutureProvider.autoDispose
    .family<Product?, String>((ref, barcode) async {
      final repository = ref.read(inventoryRepositoryProvider);
      final sessionManager = SessionManager();
      final shopId = await sessionManager.getString('shop_id');

      if (shopId == null || shopId.isEmpty) {
        return null;
      }

      return repository.getProductByBarcode(barcode: barcode, shopId: shopId);
    });

/// Provider for low stock products
final lowStockProductsProvider = StreamProvider.autoDispose<List<Product>>((
  ref,
) async* {
  final repository = ref.read(inventoryRepositoryProvider);
  final sessionManager = SessionManager();
  final shopId = await sessionManager.getString('shop_id');

  if (shopId == null || shopId.isEmpty) {
    yield [];
    return;
  }

  // Create a stream controller to emit fresh data immediately
  final controller = StreamController<List<Product>>();

  // Helper function to fetch and emit fresh data
  Future<void> fetchAndEmitFreshData() async {
    try {
      final freshProducts = await repository.getLowStockProducts(
        shopId: shopId,
      );
      if (!controller.isClosed) {
        controller.add(freshProducts);
      }
    } catch (e) {
      if (!controller.isClosed) {
        controller.addError(e);
      }
    }
  }

  // Initial fetch
  await fetchAndEmitFreshData();

  // Subscribe to inventory changes to update low stock list immediately
  final channel = repository.subscribeToInventory(
    shopId: shopId,
    onChange: () async {
      if (kDebugMode)
        print(
          '🔄 Real-time: Inventory changed, refreshing low stock alerts...',
        );
      await fetchAndEmitFreshData();
    },
  );

  // Cleanup subscription when provider is disposed
  ref.onDispose(() {
    channel.unsubscribe();
    controller.close();
  });

  // Emit data from controller and keep stream alive
  await for (final products in controller.stream) {
    yield products;
  }
});

// =====================================================
// INVENTORY PROVIDERS
// =====================================================

/// Provider for inventory of a specific product
final inventoryProvider = FutureProvider.autoDispose.family<Inventory?, String>(
  (ref, productId) async {
    final repository = ref.read(inventoryRepositoryProvider);
    final sessionManager = SessionManager();
    final shopId = await sessionManager.getString('shop_id');

    if (shopId == null || shopId.isEmpty) {
      return null;
    }

    return repository.getInventory(productId: productId, shopId: shopId);
  },
);

// =====================================================
// STOCK MOVEMENTS PROVIDERS
// =====================================================

/// Provider for stock movements (all or by product)
final stockMovementsProvider = FutureProvider.autoDispose
    .family<List<StockMovement>, String?>((ref, productId) async {
      final repository = ref.read(inventoryRepositoryProvider);
      final sessionManager = SessionManager();
      final shopId = await sessionManager.getString('shop_id');

      if (shopId == null || shopId.isEmpty) {
        return [];
      }

      return repository.getStockMovements(
        shopId: shopId,
        productId: productId,
        limit: 100,
      );
    });

// =====================================================
// MUTATIONS (Actions)
// =====================================================

/// Create product action
final createProductProvider =
    Provider.autoDispose<
      Future<Product> Function({
        required String name,
        required int priceCents,
        String? sku,
        String? barcode,
        String? categoryId,
        int? costCents,
        double taxRate,
        String? imagePath,
        int reorderLevel,
        int initialQty,
      })
    >((ref) {
      return ({
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
        final repository = ref.read(inventoryRepositoryProvider);
        final sessionManager = SessionManager();
        final shopId = await sessionManager.getString('shop_id');

        if (shopId == null || shopId.isEmpty) {
          throw Exception('No shop selected');
        }

        final product = await repository.createProduct(
          shopId: shopId,
          name: name,
          priceCents: priceCents,
          sku: sku,
          barcode: barcode,
          categoryId: categoryId,
          costCents: costCents,
          taxRate: taxRate,
          imagePath: imagePath,
          reorderLevel: reorderLevel,
          initialQty: initialQty,
        );

        // Invalidate products list
        ref.invalidate(productsProvider);
        ref.invalidate(activeProductsProvider);

        return product;
      };
    });

/// Update product action
final updateProductProvider =
    Provider.autoDispose<
      Future<Product> Function({
        required String productId,
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
      })
    >((ref) {
      return ({
        required String productId,
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
        final repository = ref.read(inventoryRepositoryProvider);
        final sessionManager = SessionManager();
        final shopId = await sessionManager.getString('shop_id');

        if (shopId == null || shopId.isEmpty) {
          throw Exception('No shop selected');
        }

        final product = await repository.updateProduct(
          productId: productId,
          shopId: shopId,
          name: name,
          priceCents: priceCents,
          costCents: costCents,
          sku: sku,
          barcode: barcode,
          categoryId: categoryId,
          taxRate: taxRate,
          imagePath: imagePath,
          reorderLevel: reorderLevel,
          isActive: isActive,
        );

        // Invalidate products list
        ref.invalidate(productsProvider);
        ref.invalidate(activeProductsProvider);
        ref.invalidate(productProvider(productId));

        return product;
      };
    });

/// Delete product action
final deleteProductProvider =
    Provider.autoDispose<Future<void> Function(String)>((ref) {
      return (String productId) async {
        final repository = ref.read(inventoryRepositoryProvider);
        final sessionManager = SessionManager();
        final shopId = await sessionManager.getString('shop_id');

        if (shopId == null || shopId.isEmpty) {
          throw Exception('No shop selected');
        }

        await repository.deleteProduct(productId: productId, shopId: shopId);

        // Invalidate products list
        ref.invalidate(productsProvider);
        ref.invalidate(activeProductsProvider);
        ref.invalidate(productProvider(productId));
      };
    });

/// Adjust stock action
final adjustStockProvider =
    Provider.autoDispose<
      Future<String> Function({
        required String productId,
        required int qtyDelta,
        StockMovementType type,
        String? reason,
        String? linkedOrderId,
      })
    >((ref) {
      return ({
        required String productId,
        required int qtyDelta,
        StockMovementType type = StockMovementType.adjustment,
        String? reason,
        String? linkedOrderId,
      }) async {
        final repository = ref.read(inventoryRepositoryProvider);
        final sessionManager = SessionManager();
        final shopId = await sessionManager.getString('shop_id');

        if (shopId == null || shopId.isEmpty) {
          throw Exception('No shop selected');
        }

        final movementId = await repository.adjustStock(
          shopId: shopId,
          productId: productId,
          qtyDelta: qtyDelta,
          type: type,
          reason: reason,
          linkedOrderId: linkedOrderId,
        );

        // Invalidate related providers
        ref.invalidate(productsProvider);
        ref.invalidate(activeProductsProvider);
        ref.invalidate(productProvider(productId));
        ref.invalidate(inventoryProvider(productId));
        ref.invalidate(lowStockProductsProvider);
        ref.invalidate(stockMovementsProvider(productId));

        return movementId;
      };
    });

/// Process sale action (for POS)
final processSaleProvider =
    Provider.autoDispose<
      Future<String> Function({
        required String productId,
        required int qtySold,
        String? orderId,
      })
    >((ref) {
      return ({
        required String productId,
        required int qtySold,
        String? orderId,
      }) async {
        final repository = ref.read(inventoryRepositoryProvider);
        final sessionManager = SessionManager();
        final shopId = await sessionManager.getString('shop_id');

        if (shopId == null || shopId.isEmpty) {
          throw Exception('No shop selected');
        }

        final movementId = await repository.processSale(
          shopId: shopId,
          productId: productId,
          qtySold: qtySold,
          orderId: orderId,
        );

        // Invalidate related providers
        ref.invalidate(productsProvider);
        ref.invalidate(activeProductsProvider);
        ref.invalidate(productProvider(productId));
        ref.invalidate(inventoryProvider(productId));
        ref.invalidate(lowStockProductsProvider);

        return movementId;
      };
    });
