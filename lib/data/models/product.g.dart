// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'product.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ProductImpl _$$ProductImplFromJson(Map<String, dynamic> json) =>
    _$ProductImpl(
      id: json['id'] as String,
      shopId: json['shop_id'] as String,
      categoryId: json['category_id'] as String?,
      sku: json['sku'] as String?,
      name: json['name'] as String,
      priceCents: (json['price_cents'] as num?)?.toInt() ?? 0,
      costCents: (json['cost_cents'] as num?)?.toInt(),
      taxRate: (json['tax_rate'] as num?)?.toDouble() ?? 0.0,
      barcode: json['barcode'] as String?,
      imagePath: json['image_path'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      reorderLevel: (json['reorder_level'] as num?)?.toInt() ?? 0,
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.parse(json['updated_at'] as String),
      lastModified: json['last_modified'] == null
          ? null
          : DateTime.parse(json['last_modified'] as String),
      deletedAt: json['deleted_at'] == null
          ? null
          : DateTime.parse(json['deleted_at'] as String),
      version: (json['version'] as num?)?.toInt() ?? 1,
      createdBy: json['created_by'] as String?,
      updatedBy: json['updated_by'] as String?,
      inventory: json['inventory'] == null
          ? null
          : Inventory.fromJson(json['inventory'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$$ProductImplToJson(_$ProductImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'shop_id': instance.shopId,
      'category_id': instance.categoryId,
      'sku': instance.sku,
      'name': instance.name,
      'price_cents': instance.priceCents,
      'cost_cents': instance.costCents,
      'tax_rate': instance.taxRate,
      'barcode': instance.barcode,
      'image_path': instance.imagePath,
      'is_active': instance.isActive,
      'reorder_level': instance.reorderLevel,
      'created_at': instance.createdAt?.toIso8601String(),
      'updated_at': instance.updatedAt?.toIso8601String(),
      'last_modified': instance.lastModified?.toIso8601String(),
      'deleted_at': instance.deletedAt?.toIso8601String(),
      'version': instance.version,
      'created_by': instance.createdBy,
      'updated_by': instance.updatedBy,
      'inventory': instance.inventory?.toJson(),
    };

_$InventoryImpl _$$InventoryImplFromJson(Map<String, dynamic> json) =>
    _$InventoryImpl(
      productId: json['product_id'] as String,
      shopId: json['shop_id'] as String,
      onHandQty: (json['on_hand_qty'] as num?)?.toInt() ?? 0,
      onReservedQty: (json['on_reserved_qty'] as num?)?.toInt() ?? 0,
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.parse(json['updated_at'] as String),
      lastModified: json['last_modified'] == null
          ? null
          : DateTime.parse(json['last_modified'] as String),
      deletedAt: json['deleted_at'] == null
          ? null
          : DateTime.parse(json['deleted_at'] as String),
      version: (json['version'] as num?)?.toInt() ?? 1,
      createdBy: json['created_by'] as String?,
      updatedBy: json['updated_by'] as String?,
    );

Map<String, dynamic> _$$InventoryImplToJson(_$InventoryImpl instance) =>
    <String, dynamic>{
      'product_id': instance.productId,
      'shop_id': instance.shopId,
      'on_hand_qty': instance.onHandQty,
      'on_reserved_qty': instance.onReservedQty,
      'created_at': instance.createdAt?.toIso8601String(),
      'updated_at': instance.updatedAt?.toIso8601String(),
      'last_modified': instance.lastModified?.toIso8601String(),
      'deleted_at': instance.deletedAt?.toIso8601String(),
      'version': instance.version,
      'created_by': instance.createdBy,
      'updated_by': instance.updatedBy,
    };

_$StockMovementImpl _$$StockMovementImplFromJson(Map<String, dynamic> json) =>
    _$StockMovementImpl(
      id: json['id'] as String,
      shopId: json['shop_id'] as String,
      productId: json['product_id'] as String,
      type: $enumDecode(_$StockMovementTypeEnumMap, json['type']),
      qtyDelta: (json['qty_delta'] as num).toInt(),
      reason: json['reason'] as String?,
      linkedOrderId: json['linked_order_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      lastModified: DateTime.parse(json['last_modified'] as String),
      deletedAt: json['deleted_at'] == null
          ? null
          : DateTime.parse(json['deleted_at'] as String),
      version: (json['version'] as num?)?.toInt() ?? 1,
      createdBy: json['created_by'] as String?,
      updatedBy: json['updated_by'] as String?,
      product: json['product'] == null
          ? null
          : Product.fromJson(json['product'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$$StockMovementImplToJson(_$StockMovementImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'shop_id': instance.shopId,
      'product_id': instance.productId,
      'type': _$StockMovementTypeEnumMap[instance.type]!,
      'qty_delta': instance.qtyDelta,
      'reason': instance.reason,
      'linked_order_id': instance.linkedOrderId,
      'created_at': instance.createdAt.toIso8601String(),
      'updated_at': instance.updatedAt.toIso8601String(),
      'last_modified': instance.lastModified.toIso8601String(),
      'deleted_at': instance.deletedAt?.toIso8601String(),
      'version': instance.version,
      'created_by': instance.createdBy,
      'updated_by': instance.updatedBy,
      'product': instance.product?.toJson(),
    };

const _$StockMovementTypeEnumMap = {
  StockMovementType.sale: 'sale',
  StockMovementType.purchase: 'purchase',
  StockMovementType.adjustment: 'adjustment',
  StockMovementType.returnType: 'return',
};
