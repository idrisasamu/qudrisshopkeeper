import 'package:freezed_annotation/freezed_annotation.dart';

part 'product.freezed.dart';
part 'product.g.dart';

/// Product model for Supabase inventory system
@freezed
class Product with _$Product {
  const factory Product({
    required String id,
    required String shopId,
    String? categoryId,
    String? sku,
    required String name,
    @Default(0) int priceCents,
    int? costCents,
    @Default(0.0) double taxRate,
    String? barcode,
    String? imagePath,
    @Default(true) bool isActive,
    @Default(0) int reorderLevel,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastModified,
    DateTime? deletedAt,
    @Default(1) int version,
    String? createdBy,
    String? updatedBy,
    // Embedded inventory data (from join)
    Inventory? inventory,
  }) = _Product;

  factory Product.fromJson(Map<String, dynamic> json) =>
      _$ProductFromJson(json);

  const Product._();

  /// Get price in dollars
  double get price => priceCents / 100.0;

  /// Get cost in dollars
  double? get cost => costCents != null ? costCents! / 100.0 : null;

  /// Check if product is low on stock
  bool get isLowStock {
    if (inventory == null) return false;
    return inventory!.onHandQty <= reorderLevel;
  }

  /// Get current available quantity
  int get availableQty => inventory?.onHandQty ?? 0;
}

/// Inventory model for stock levels
@freezed
class Inventory with _$Inventory {
  const factory Inventory({
    required String productId,
    required String shopId,
    @Default(0) int onHandQty,
    @Default(0) int onReservedQty,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastModified,
    DateTime? deletedAt,
    @Default(1) int version,
    String? createdBy,
    String? updatedBy,
  }) = _Inventory;

  factory Inventory.fromJson(Map<String, dynamic> json) =>
      _$InventoryFromJson(json);

  const Inventory._();

  /// Get available (not reserved) quantity
  int get availableQty => onHandQty - onReservedQty;
}

/// Stock movement model for audit trail
@freezed
class StockMovement with _$StockMovement {
  const factory StockMovement({
    required String id,
    required String shopId,
    required String productId,
    required StockMovementType type,
    required int qtyDelta,
    String? reason,
    String? linkedOrderId,
    required DateTime createdAt,
    required DateTime updatedAt,
    required DateTime lastModified,
    DateTime? deletedAt,
    @Default(1) int version,
    String? createdBy,
    String? updatedBy,
    // Optional embedded product data
    Product? product,
  }) = _StockMovement;

  factory StockMovement.fromJson(Map<String, dynamic> json) =>
      _$StockMovementFromJson(_preprocessJson(json));

  const StockMovement._();

  /// Preprocess JSON to convert string type to enum
  static Map<String, dynamic> _preprocessJson(Map<String, dynamic> json) {
    if (json['type'] is String) {
      final typeStr = json['type'] as String;
      json['type'] = typeStr; // Will be parsed by freezed
    }
    return json;
  }
}

/// Stock movement types
enum StockMovementType {
  @JsonValue('sale')
  sale,
  @JsonValue('purchase')
  purchase,
  @JsonValue('adjustment')
  adjustment,
  @JsonValue('return')
  returnType,
}

/// Extension for stock movement type display
extension StockMovementTypeX on StockMovementType {
  String get displayName {
    switch (this) {
      case StockMovementType.sale:
        return 'Sale';
      case StockMovementType.purchase:
        return 'Purchase';
      case StockMovementType.adjustment:
        return 'Adjustment';
      case StockMovementType.returnType:
        return 'Return';
    }
  }

  String get icon {
    switch (this) {
      case StockMovementType.sale:
        return '📤';
      case StockMovementType.purchase:
        return '📥';
      case StockMovementType.adjustment:
        return '⚖️';
      case StockMovementType.returnType:
        return '↩️';
    }
  }
}

/// Product with inventory helper class
class ProductWithInventory {
  final Product product;
  final Inventory? inventory;

  ProductWithInventory({required this.product, this.inventory});

  int get currentStock => inventory?.onHandQty ?? 0;
  bool get isLowStock => currentStock <= product.reorderLevel;
}
