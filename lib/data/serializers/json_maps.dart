import '../local/app_database.dart';

extension ItemJson on Item {
  Map<String, dynamic> toJson() => {
    'id': id,
    'shopId': shopId,
    'name': name,
    'sku': sku,
    'barcode': barcode,
    'category': category,
    'unit': unit,
    'costPrice': costPrice,
    'salePrice': salePrice,
    'minQty': minQty,
    'isActive': isActive,
    'updatedAt': updatedAt.toIso8601String(),
  };

  static Item fromJson(Map<String, dynamic> j) => Item(
    id: j['id'] as String,
    shopId: j['shopId'] as String,
    name: j['name'] as String,
    sku: j['sku'] as String?,
    barcode: j['barcode'] as String?,
    category: j['category'] as String?,
    unit: j['unit'] as String,
    costPrice: (j['costPrice'] as num).toDouble(),
    salePrice: (j['salePrice'] as num).toDouble(),
    minQty: (j['minQty'] as num).toDouble(),
    isActive: j['isActive'] as bool,
    updatedAt: DateTime.parse(j['updatedAt'] as String),
  );
}

extension StockMovementJson on StockMovement {
  Map<String, dynamic> toJson() => {
    'id': id,
    'shopId': shopId,
    'itemId': itemId,
    'type': type,
    'qty': qty,
    'unitCost': unitCost,
    'unitPrice': unitPrice,
    'reason': reason,
    'byUserId': byUserId,
    'at': at.toIso8601String(),
  };

  static StockMovement fromJson(Map<String, dynamic> j) => StockMovement(
    id: j['id'] as String,
    shopId: j['shopId'] as String,
    itemId: j['itemId'] as String,
    type: j['type'] as String,
    qty: (j['qty'] as num).toDouble(),
    unitCost: (j['unitCost'] as num).toDouble(),
    unitPrice: (j['unitPrice'] as num).toDouble(),
    reason: j['reason'] as String?,
    byUserId: j['byUserId'] as String,
    at: DateTime.parse(j['at'] as String),
  );
}

extension SaleJson on Sale {
  Map<String, dynamic> toJson(List<SaleItem> lines) => {
    'id': id,
    'shopId': shopId,
    'totalAmount': totalAmount,
    'byUserId': byUserId,
    'createdAt': createdAt.toIso8601String(),
    'lines': lines.map((l) => l.toJson()).toList(),
  };

  static Sale fromJson(Map<String, dynamic> j) => Sale(
    id: j['id'] as String,
    shopId: j['shopId'] as String,
    totalAmount: (j['totalAmount'] as num).toDouble(),
    byUserId: j['byUserId'] as String,
    createdAt: DateTime.parse(j['createdAt'] as String),
  );
}

extension SaleItemJson on SaleItem {
  Map<String, dynamic> toJson() => {
    'id': id,
    'saleId': saleId,
    'itemId': itemId,
    'itemName': itemName,
    'quantity': quantity,
    'unitPrice': unitPrice,
    'totalPrice': totalPrice,
  };

  static SaleItem fromJson(Map<String, dynamic> j) => SaleItem(
    id: j['id'] as String,
    saleId: j['saleId'] as String,
    itemId: j['itemId'] as String,
    itemName: j['itemName'] as String,
    quantity: (j['quantity'] as num).toDouble(),
    unitPrice: (j['unitPrice'] as num).toDouble(),
    totalPrice: (j['totalPrice'] as num).toDouble(),
  );
}

/// Inventory operation for delta sync
class InventoryOp {
  final String opId; // uuid
  final String type; // 'upsert' | 'delete'
  final Map<String, dynamic> item;
  final String eventTime; // ISO

  InventoryOp(this.opId, this.type, this.item, this.eventTime);

  Map<String, dynamic> toJson() => {
    'opId': opId,
    'type': type,
    'item': item,
    'eventTime': eventTime,
  };

  static InventoryOp fromJson(Map<String, dynamic> j) => InventoryOp(
    j['opId'] as String,
    j['type'] as String,
    Map<String, dynamic>.from(j['item']),
    j['eventTime'] as String,
  );
}
