// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'product.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

Product _$ProductFromJson(Map<String, dynamic> json) {
  return _Product.fromJson(json);
}

/// @nodoc
mixin _$Product {
  String get id => throw _privateConstructorUsedError;
  String get shopId => throw _privateConstructorUsedError;
  String? get categoryId => throw _privateConstructorUsedError;
  String? get sku => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  int get priceCents => throw _privateConstructorUsedError;
  int? get costCents => throw _privateConstructorUsedError;
  double get taxRate => throw _privateConstructorUsedError;
  String? get barcode => throw _privateConstructorUsedError;
  String? get imagePath => throw _privateConstructorUsedError;
  bool get isActive => throw _privateConstructorUsedError;
  int get reorderLevel => throw _privateConstructorUsedError;
  DateTime? get createdAt => throw _privateConstructorUsedError;
  DateTime? get updatedAt => throw _privateConstructorUsedError;
  DateTime? get lastModified => throw _privateConstructorUsedError;
  DateTime? get deletedAt => throw _privateConstructorUsedError;
  int get version => throw _privateConstructorUsedError;
  String? get createdBy => throw _privateConstructorUsedError;
  String? get updatedBy =>
      throw _privateConstructorUsedError; // Embedded inventory data (from join)
  Inventory? get inventory => throw _privateConstructorUsedError;

  /// Serializes this Product to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Product
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ProductCopyWith<Product> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ProductCopyWith<$Res> {
  factory $ProductCopyWith(Product value, $Res Function(Product) then) =
      _$ProductCopyWithImpl<$Res, Product>;
  @useResult
  $Res call({
    String id,
    String shopId,
    String? categoryId,
    String? sku,
    String name,
    int priceCents,
    int? costCents,
    double taxRate,
    String? barcode,
    String? imagePath,
    bool isActive,
    int reorderLevel,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastModified,
    DateTime? deletedAt,
    int version,
    String? createdBy,
    String? updatedBy,
    Inventory? inventory,
  });

  $InventoryCopyWith<$Res>? get inventory;
}

/// @nodoc
class _$ProductCopyWithImpl<$Res, $Val extends Product>
    implements $ProductCopyWith<$Res> {
  _$ProductCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Product
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? shopId = null,
    Object? categoryId = freezed,
    Object? sku = freezed,
    Object? name = null,
    Object? priceCents = null,
    Object? costCents = freezed,
    Object? taxRate = null,
    Object? barcode = freezed,
    Object? imagePath = freezed,
    Object? isActive = null,
    Object? reorderLevel = null,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
    Object? lastModified = freezed,
    Object? deletedAt = freezed,
    Object? version = null,
    Object? createdBy = freezed,
    Object? updatedBy = freezed,
    Object? inventory = freezed,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            shopId: null == shopId
                ? _value.shopId
                : shopId // ignore: cast_nullable_to_non_nullable
                      as String,
            categoryId: freezed == categoryId
                ? _value.categoryId
                : categoryId // ignore: cast_nullable_to_non_nullable
                      as String?,
            sku: freezed == sku
                ? _value.sku
                : sku // ignore: cast_nullable_to_non_nullable
                      as String?,
            name: null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                      as String,
            priceCents: null == priceCents
                ? _value.priceCents
                : priceCents // ignore: cast_nullable_to_non_nullable
                      as int,
            costCents: freezed == costCents
                ? _value.costCents
                : costCents // ignore: cast_nullable_to_non_nullable
                      as int?,
            taxRate: null == taxRate
                ? _value.taxRate
                : taxRate // ignore: cast_nullable_to_non_nullable
                      as double,
            barcode: freezed == barcode
                ? _value.barcode
                : barcode // ignore: cast_nullable_to_non_nullable
                      as String?,
            imagePath: freezed == imagePath
                ? _value.imagePath
                : imagePath // ignore: cast_nullable_to_non_nullable
                      as String?,
            isActive: null == isActive
                ? _value.isActive
                : isActive // ignore: cast_nullable_to_non_nullable
                      as bool,
            reorderLevel: null == reorderLevel
                ? _value.reorderLevel
                : reorderLevel // ignore: cast_nullable_to_non_nullable
                      as int,
            createdAt: freezed == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            updatedAt: freezed == updatedAt
                ? _value.updatedAt
                : updatedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            lastModified: freezed == lastModified
                ? _value.lastModified
                : lastModified // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            deletedAt: freezed == deletedAt
                ? _value.deletedAt
                : deletedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            version: null == version
                ? _value.version
                : version // ignore: cast_nullable_to_non_nullable
                      as int,
            createdBy: freezed == createdBy
                ? _value.createdBy
                : createdBy // ignore: cast_nullable_to_non_nullable
                      as String?,
            updatedBy: freezed == updatedBy
                ? _value.updatedBy
                : updatedBy // ignore: cast_nullable_to_non_nullable
                      as String?,
            inventory: freezed == inventory
                ? _value.inventory
                : inventory // ignore: cast_nullable_to_non_nullable
                      as Inventory?,
          )
          as $Val,
    );
  }

  /// Create a copy of Product
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $InventoryCopyWith<$Res>? get inventory {
    if (_value.inventory == null) {
      return null;
    }

    return $InventoryCopyWith<$Res>(_value.inventory!, (value) {
      return _then(_value.copyWith(inventory: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$ProductImplCopyWith<$Res> implements $ProductCopyWith<$Res> {
  factory _$$ProductImplCopyWith(
    _$ProductImpl value,
    $Res Function(_$ProductImpl) then,
  ) = __$$ProductImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String shopId,
    String? categoryId,
    String? sku,
    String name,
    int priceCents,
    int? costCents,
    double taxRate,
    String? barcode,
    String? imagePath,
    bool isActive,
    int reorderLevel,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastModified,
    DateTime? deletedAt,
    int version,
    String? createdBy,
    String? updatedBy,
    Inventory? inventory,
  });

  @override
  $InventoryCopyWith<$Res>? get inventory;
}

/// @nodoc
class __$$ProductImplCopyWithImpl<$Res>
    extends _$ProductCopyWithImpl<$Res, _$ProductImpl>
    implements _$$ProductImplCopyWith<$Res> {
  __$$ProductImplCopyWithImpl(
    _$ProductImpl _value,
    $Res Function(_$ProductImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of Product
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? shopId = null,
    Object? categoryId = freezed,
    Object? sku = freezed,
    Object? name = null,
    Object? priceCents = null,
    Object? costCents = freezed,
    Object? taxRate = null,
    Object? barcode = freezed,
    Object? imagePath = freezed,
    Object? isActive = null,
    Object? reorderLevel = null,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
    Object? lastModified = freezed,
    Object? deletedAt = freezed,
    Object? version = null,
    Object? createdBy = freezed,
    Object? updatedBy = freezed,
    Object? inventory = freezed,
  }) {
    return _then(
      _$ProductImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        shopId: null == shopId
            ? _value.shopId
            : shopId // ignore: cast_nullable_to_non_nullable
                  as String,
        categoryId: freezed == categoryId
            ? _value.categoryId
            : categoryId // ignore: cast_nullable_to_non_nullable
                  as String?,
        sku: freezed == sku
            ? _value.sku
            : sku // ignore: cast_nullable_to_non_nullable
                  as String?,
        name: null == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        priceCents: null == priceCents
            ? _value.priceCents
            : priceCents // ignore: cast_nullable_to_non_nullable
                  as int,
        costCents: freezed == costCents
            ? _value.costCents
            : costCents // ignore: cast_nullable_to_non_nullable
                  as int?,
        taxRate: null == taxRate
            ? _value.taxRate
            : taxRate // ignore: cast_nullable_to_non_nullable
                  as double,
        barcode: freezed == barcode
            ? _value.barcode
            : barcode // ignore: cast_nullable_to_non_nullable
                  as String?,
        imagePath: freezed == imagePath
            ? _value.imagePath
            : imagePath // ignore: cast_nullable_to_non_nullable
                  as String?,
        isActive: null == isActive
            ? _value.isActive
            : isActive // ignore: cast_nullable_to_non_nullable
                  as bool,
        reorderLevel: null == reorderLevel
            ? _value.reorderLevel
            : reorderLevel // ignore: cast_nullable_to_non_nullable
                  as int,
        createdAt: freezed == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        updatedAt: freezed == updatedAt
            ? _value.updatedAt
            : updatedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        lastModified: freezed == lastModified
            ? _value.lastModified
            : lastModified // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        deletedAt: freezed == deletedAt
            ? _value.deletedAt
            : deletedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        version: null == version
            ? _value.version
            : version // ignore: cast_nullable_to_non_nullable
                  as int,
        createdBy: freezed == createdBy
            ? _value.createdBy
            : createdBy // ignore: cast_nullable_to_non_nullable
                  as String?,
        updatedBy: freezed == updatedBy
            ? _value.updatedBy
            : updatedBy // ignore: cast_nullable_to_non_nullable
                  as String?,
        inventory: freezed == inventory
            ? _value.inventory
            : inventory // ignore: cast_nullable_to_non_nullable
                  as Inventory?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$ProductImpl extends _Product {
  const _$ProductImpl({
    required this.id,
    required this.shopId,
    this.categoryId,
    this.sku,
    required this.name,
    this.priceCents = 0,
    this.costCents,
    this.taxRate = 0.0,
    this.barcode,
    this.imagePath,
    this.isActive = true,
    this.reorderLevel = 0,
    this.createdAt,
    this.updatedAt,
    this.lastModified,
    this.deletedAt,
    this.version = 1,
    this.createdBy,
    this.updatedBy,
    this.inventory,
  }) : super._();

  factory _$ProductImpl.fromJson(Map<String, dynamic> json) =>
      _$$ProductImplFromJson(json);

  @override
  final String id;
  @override
  final String shopId;
  @override
  final String? categoryId;
  @override
  final String? sku;
  @override
  final String name;
  @override
  @JsonKey()
  final int priceCents;
  @override
  final int? costCents;
  @override
  @JsonKey()
  final double taxRate;
  @override
  final String? barcode;
  @override
  final String? imagePath;
  @override
  @JsonKey()
  final bool isActive;
  @override
  @JsonKey()
  final int reorderLevel;
  @override
  final DateTime? createdAt;
  @override
  final DateTime? updatedAt;
  @override
  final DateTime? lastModified;
  @override
  final DateTime? deletedAt;
  @override
  @JsonKey()
  final int version;
  @override
  final String? createdBy;
  @override
  final String? updatedBy;
  // Embedded inventory data (from join)
  @override
  final Inventory? inventory;

  @override
  String toString() {
    return 'Product(id: $id, shopId: $shopId, categoryId: $categoryId, sku: $sku, name: $name, priceCents: $priceCents, costCents: $costCents, taxRate: $taxRate, barcode: $barcode, imagePath: $imagePath, isActive: $isActive, reorderLevel: $reorderLevel, createdAt: $createdAt, updatedAt: $updatedAt, lastModified: $lastModified, deletedAt: $deletedAt, version: $version, createdBy: $createdBy, updatedBy: $updatedBy, inventory: $inventory)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ProductImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.shopId, shopId) || other.shopId == shopId) &&
            (identical(other.categoryId, categoryId) ||
                other.categoryId == categoryId) &&
            (identical(other.sku, sku) || other.sku == sku) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.priceCents, priceCents) ||
                other.priceCents == priceCents) &&
            (identical(other.costCents, costCents) ||
                other.costCents == costCents) &&
            (identical(other.taxRate, taxRate) || other.taxRate == taxRate) &&
            (identical(other.barcode, barcode) || other.barcode == barcode) &&
            (identical(other.imagePath, imagePath) ||
                other.imagePath == imagePath) &&
            (identical(other.isActive, isActive) ||
                other.isActive == isActive) &&
            (identical(other.reorderLevel, reorderLevel) ||
                other.reorderLevel == reorderLevel) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt) &&
            (identical(other.lastModified, lastModified) ||
                other.lastModified == lastModified) &&
            (identical(other.deletedAt, deletedAt) ||
                other.deletedAt == deletedAt) &&
            (identical(other.version, version) || other.version == version) &&
            (identical(other.createdBy, createdBy) ||
                other.createdBy == createdBy) &&
            (identical(other.updatedBy, updatedBy) ||
                other.updatedBy == updatedBy) &&
            (identical(other.inventory, inventory) ||
                other.inventory == inventory));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hashAll([
    runtimeType,
    id,
    shopId,
    categoryId,
    sku,
    name,
    priceCents,
    costCents,
    taxRate,
    barcode,
    imagePath,
    isActive,
    reorderLevel,
    createdAt,
    updatedAt,
    lastModified,
    deletedAt,
    version,
    createdBy,
    updatedBy,
    inventory,
  ]);

  /// Create a copy of Product
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ProductImplCopyWith<_$ProductImpl> get copyWith =>
      __$$ProductImplCopyWithImpl<_$ProductImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ProductImplToJson(this);
  }
}

abstract class _Product extends Product {
  const factory _Product({
    required final String id,
    required final String shopId,
    final String? categoryId,
    final String? sku,
    required final String name,
    final int priceCents,
    final int? costCents,
    final double taxRate,
    final String? barcode,
    final String? imagePath,
    final bool isActive,
    final int reorderLevel,
    final DateTime? createdAt,
    final DateTime? updatedAt,
    final DateTime? lastModified,
    final DateTime? deletedAt,
    final int version,
    final String? createdBy,
    final String? updatedBy,
    final Inventory? inventory,
  }) = _$ProductImpl;
  const _Product._() : super._();

  factory _Product.fromJson(Map<String, dynamic> json) = _$ProductImpl.fromJson;

  @override
  String get id;
  @override
  String get shopId;
  @override
  String? get categoryId;
  @override
  String? get sku;
  @override
  String get name;
  @override
  int get priceCents;
  @override
  int? get costCents;
  @override
  double get taxRate;
  @override
  String? get barcode;
  @override
  String? get imagePath;
  @override
  bool get isActive;
  @override
  int get reorderLevel;
  @override
  DateTime? get createdAt;
  @override
  DateTime? get updatedAt;
  @override
  DateTime? get lastModified;
  @override
  DateTime? get deletedAt;
  @override
  int get version;
  @override
  String? get createdBy;
  @override
  String? get updatedBy; // Embedded inventory data (from join)
  @override
  Inventory? get inventory;

  /// Create a copy of Product
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ProductImplCopyWith<_$ProductImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

Inventory _$InventoryFromJson(Map<String, dynamic> json) {
  return _Inventory.fromJson(json);
}

/// @nodoc
mixin _$Inventory {
  String get productId => throw _privateConstructorUsedError;
  String get shopId => throw _privateConstructorUsedError;
  int get onHandQty => throw _privateConstructorUsedError;
  int get onReservedQty => throw _privateConstructorUsedError;
  DateTime? get createdAt => throw _privateConstructorUsedError;
  DateTime? get updatedAt => throw _privateConstructorUsedError;
  DateTime? get lastModified => throw _privateConstructorUsedError;
  DateTime? get deletedAt => throw _privateConstructorUsedError;
  int get version => throw _privateConstructorUsedError;
  String? get createdBy => throw _privateConstructorUsedError;
  String? get updatedBy => throw _privateConstructorUsedError;

  /// Serializes this Inventory to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Inventory
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $InventoryCopyWith<Inventory> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $InventoryCopyWith<$Res> {
  factory $InventoryCopyWith(Inventory value, $Res Function(Inventory) then) =
      _$InventoryCopyWithImpl<$Res, Inventory>;
  @useResult
  $Res call({
    String productId,
    String shopId,
    int onHandQty,
    int onReservedQty,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastModified,
    DateTime? deletedAt,
    int version,
    String? createdBy,
    String? updatedBy,
  });
}

/// @nodoc
class _$InventoryCopyWithImpl<$Res, $Val extends Inventory>
    implements $InventoryCopyWith<$Res> {
  _$InventoryCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Inventory
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? productId = null,
    Object? shopId = null,
    Object? onHandQty = null,
    Object? onReservedQty = null,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
    Object? lastModified = freezed,
    Object? deletedAt = freezed,
    Object? version = null,
    Object? createdBy = freezed,
    Object? updatedBy = freezed,
  }) {
    return _then(
      _value.copyWith(
            productId: null == productId
                ? _value.productId
                : productId // ignore: cast_nullable_to_non_nullable
                      as String,
            shopId: null == shopId
                ? _value.shopId
                : shopId // ignore: cast_nullable_to_non_nullable
                      as String,
            onHandQty: null == onHandQty
                ? _value.onHandQty
                : onHandQty // ignore: cast_nullable_to_non_nullable
                      as int,
            onReservedQty: null == onReservedQty
                ? _value.onReservedQty
                : onReservedQty // ignore: cast_nullable_to_non_nullable
                      as int,
            createdAt: freezed == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            updatedAt: freezed == updatedAt
                ? _value.updatedAt
                : updatedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            lastModified: freezed == lastModified
                ? _value.lastModified
                : lastModified // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            deletedAt: freezed == deletedAt
                ? _value.deletedAt
                : deletedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            version: null == version
                ? _value.version
                : version // ignore: cast_nullable_to_non_nullable
                      as int,
            createdBy: freezed == createdBy
                ? _value.createdBy
                : createdBy // ignore: cast_nullable_to_non_nullable
                      as String?,
            updatedBy: freezed == updatedBy
                ? _value.updatedBy
                : updatedBy // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$InventoryImplCopyWith<$Res>
    implements $InventoryCopyWith<$Res> {
  factory _$$InventoryImplCopyWith(
    _$InventoryImpl value,
    $Res Function(_$InventoryImpl) then,
  ) = __$$InventoryImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String productId,
    String shopId,
    int onHandQty,
    int onReservedQty,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastModified,
    DateTime? deletedAt,
    int version,
    String? createdBy,
    String? updatedBy,
  });
}

/// @nodoc
class __$$InventoryImplCopyWithImpl<$Res>
    extends _$InventoryCopyWithImpl<$Res, _$InventoryImpl>
    implements _$$InventoryImplCopyWith<$Res> {
  __$$InventoryImplCopyWithImpl(
    _$InventoryImpl _value,
    $Res Function(_$InventoryImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of Inventory
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? productId = null,
    Object? shopId = null,
    Object? onHandQty = null,
    Object? onReservedQty = null,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
    Object? lastModified = freezed,
    Object? deletedAt = freezed,
    Object? version = null,
    Object? createdBy = freezed,
    Object? updatedBy = freezed,
  }) {
    return _then(
      _$InventoryImpl(
        productId: null == productId
            ? _value.productId
            : productId // ignore: cast_nullable_to_non_nullable
                  as String,
        shopId: null == shopId
            ? _value.shopId
            : shopId // ignore: cast_nullable_to_non_nullable
                  as String,
        onHandQty: null == onHandQty
            ? _value.onHandQty
            : onHandQty // ignore: cast_nullable_to_non_nullable
                  as int,
        onReservedQty: null == onReservedQty
            ? _value.onReservedQty
            : onReservedQty // ignore: cast_nullable_to_non_nullable
                  as int,
        createdAt: freezed == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        updatedAt: freezed == updatedAt
            ? _value.updatedAt
            : updatedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        lastModified: freezed == lastModified
            ? _value.lastModified
            : lastModified // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        deletedAt: freezed == deletedAt
            ? _value.deletedAt
            : deletedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        version: null == version
            ? _value.version
            : version // ignore: cast_nullable_to_non_nullable
                  as int,
        createdBy: freezed == createdBy
            ? _value.createdBy
            : createdBy // ignore: cast_nullable_to_non_nullable
                  as String?,
        updatedBy: freezed == updatedBy
            ? _value.updatedBy
            : updatedBy // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$InventoryImpl extends _Inventory {
  const _$InventoryImpl({
    required this.productId,
    required this.shopId,
    this.onHandQty = 0,
    this.onReservedQty = 0,
    this.createdAt,
    this.updatedAt,
    this.lastModified,
    this.deletedAt,
    this.version = 1,
    this.createdBy,
    this.updatedBy,
  }) : super._();

  factory _$InventoryImpl.fromJson(Map<String, dynamic> json) =>
      _$$InventoryImplFromJson(json);

  @override
  final String productId;
  @override
  final String shopId;
  @override
  @JsonKey()
  final int onHandQty;
  @override
  @JsonKey()
  final int onReservedQty;
  @override
  final DateTime? createdAt;
  @override
  final DateTime? updatedAt;
  @override
  final DateTime? lastModified;
  @override
  final DateTime? deletedAt;
  @override
  @JsonKey()
  final int version;
  @override
  final String? createdBy;
  @override
  final String? updatedBy;

  @override
  String toString() {
    return 'Inventory(productId: $productId, shopId: $shopId, onHandQty: $onHandQty, onReservedQty: $onReservedQty, createdAt: $createdAt, updatedAt: $updatedAt, lastModified: $lastModified, deletedAt: $deletedAt, version: $version, createdBy: $createdBy, updatedBy: $updatedBy)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$InventoryImpl &&
            (identical(other.productId, productId) ||
                other.productId == productId) &&
            (identical(other.shopId, shopId) || other.shopId == shopId) &&
            (identical(other.onHandQty, onHandQty) ||
                other.onHandQty == onHandQty) &&
            (identical(other.onReservedQty, onReservedQty) ||
                other.onReservedQty == onReservedQty) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt) &&
            (identical(other.lastModified, lastModified) ||
                other.lastModified == lastModified) &&
            (identical(other.deletedAt, deletedAt) ||
                other.deletedAt == deletedAt) &&
            (identical(other.version, version) || other.version == version) &&
            (identical(other.createdBy, createdBy) ||
                other.createdBy == createdBy) &&
            (identical(other.updatedBy, updatedBy) ||
                other.updatedBy == updatedBy));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    productId,
    shopId,
    onHandQty,
    onReservedQty,
    createdAt,
    updatedAt,
    lastModified,
    deletedAt,
    version,
    createdBy,
    updatedBy,
  );

  /// Create a copy of Inventory
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$InventoryImplCopyWith<_$InventoryImpl> get copyWith =>
      __$$InventoryImplCopyWithImpl<_$InventoryImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$InventoryImplToJson(this);
  }
}

abstract class _Inventory extends Inventory {
  const factory _Inventory({
    required final String productId,
    required final String shopId,
    final int onHandQty,
    final int onReservedQty,
    final DateTime? createdAt,
    final DateTime? updatedAt,
    final DateTime? lastModified,
    final DateTime? deletedAt,
    final int version,
    final String? createdBy,
    final String? updatedBy,
  }) = _$InventoryImpl;
  const _Inventory._() : super._();

  factory _Inventory.fromJson(Map<String, dynamic> json) =
      _$InventoryImpl.fromJson;

  @override
  String get productId;
  @override
  String get shopId;
  @override
  int get onHandQty;
  @override
  int get onReservedQty;
  @override
  DateTime? get createdAt;
  @override
  DateTime? get updatedAt;
  @override
  DateTime? get lastModified;
  @override
  DateTime? get deletedAt;
  @override
  int get version;
  @override
  String? get createdBy;
  @override
  String? get updatedBy;

  /// Create a copy of Inventory
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$InventoryImplCopyWith<_$InventoryImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

StockMovement _$StockMovementFromJson(Map<String, dynamic> json) {
  return _StockMovement.fromJson(json);
}

/// @nodoc
mixin _$StockMovement {
  String get id => throw _privateConstructorUsedError;
  String get shopId => throw _privateConstructorUsedError;
  String get productId => throw _privateConstructorUsedError;
  StockMovementType get type => throw _privateConstructorUsedError;
  int get qtyDelta => throw _privateConstructorUsedError;
  String? get reason => throw _privateConstructorUsedError;
  String? get linkedOrderId => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;
  DateTime get updatedAt => throw _privateConstructorUsedError;
  DateTime get lastModified => throw _privateConstructorUsedError;
  DateTime? get deletedAt => throw _privateConstructorUsedError;
  int get version => throw _privateConstructorUsedError;
  String? get createdBy => throw _privateConstructorUsedError;
  String? get updatedBy =>
      throw _privateConstructorUsedError; // Optional embedded product data
  Product? get product => throw _privateConstructorUsedError;

  /// Serializes this StockMovement to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of StockMovement
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $StockMovementCopyWith<StockMovement> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $StockMovementCopyWith<$Res> {
  factory $StockMovementCopyWith(
    StockMovement value,
    $Res Function(StockMovement) then,
  ) = _$StockMovementCopyWithImpl<$Res, StockMovement>;
  @useResult
  $Res call({
    String id,
    String shopId,
    String productId,
    StockMovementType type,
    int qtyDelta,
    String? reason,
    String? linkedOrderId,
    DateTime createdAt,
    DateTime updatedAt,
    DateTime lastModified,
    DateTime? deletedAt,
    int version,
    String? createdBy,
    String? updatedBy,
    Product? product,
  });

  $ProductCopyWith<$Res>? get product;
}

/// @nodoc
class _$StockMovementCopyWithImpl<$Res, $Val extends StockMovement>
    implements $StockMovementCopyWith<$Res> {
  _$StockMovementCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of StockMovement
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? shopId = null,
    Object? productId = null,
    Object? type = null,
    Object? qtyDelta = null,
    Object? reason = freezed,
    Object? linkedOrderId = freezed,
    Object? createdAt = null,
    Object? updatedAt = null,
    Object? lastModified = null,
    Object? deletedAt = freezed,
    Object? version = null,
    Object? createdBy = freezed,
    Object? updatedBy = freezed,
    Object? product = freezed,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            shopId: null == shopId
                ? _value.shopId
                : shopId // ignore: cast_nullable_to_non_nullable
                      as String,
            productId: null == productId
                ? _value.productId
                : productId // ignore: cast_nullable_to_non_nullable
                      as String,
            type: null == type
                ? _value.type
                : type // ignore: cast_nullable_to_non_nullable
                      as StockMovementType,
            qtyDelta: null == qtyDelta
                ? _value.qtyDelta
                : qtyDelta // ignore: cast_nullable_to_non_nullable
                      as int,
            reason: freezed == reason
                ? _value.reason
                : reason // ignore: cast_nullable_to_non_nullable
                      as String?,
            linkedOrderId: freezed == linkedOrderId
                ? _value.linkedOrderId
                : linkedOrderId // ignore: cast_nullable_to_non_nullable
                      as String?,
            createdAt: null == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            updatedAt: null == updatedAt
                ? _value.updatedAt
                : updatedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            lastModified: null == lastModified
                ? _value.lastModified
                : lastModified // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            deletedAt: freezed == deletedAt
                ? _value.deletedAt
                : deletedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            version: null == version
                ? _value.version
                : version // ignore: cast_nullable_to_non_nullable
                      as int,
            createdBy: freezed == createdBy
                ? _value.createdBy
                : createdBy // ignore: cast_nullable_to_non_nullable
                      as String?,
            updatedBy: freezed == updatedBy
                ? _value.updatedBy
                : updatedBy // ignore: cast_nullable_to_non_nullable
                      as String?,
            product: freezed == product
                ? _value.product
                : product // ignore: cast_nullable_to_non_nullable
                      as Product?,
          )
          as $Val,
    );
  }

  /// Create a copy of StockMovement
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $ProductCopyWith<$Res>? get product {
    if (_value.product == null) {
      return null;
    }

    return $ProductCopyWith<$Res>(_value.product!, (value) {
      return _then(_value.copyWith(product: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$StockMovementImplCopyWith<$Res>
    implements $StockMovementCopyWith<$Res> {
  factory _$$StockMovementImplCopyWith(
    _$StockMovementImpl value,
    $Res Function(_$StockMovementImpl) then,
  ) = __$$StockMovementImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String shopId,
    String productId,
    StockMovementType type,
    int qtyDelta,
    String? reason,
    String? linkedOrderId,
    DateTime createdAt,
    DateTime updatedAt,
    DateTime lastModified,
    DateTime? deletedAt,
    int version,
    String? createdBy,
    String? updatedBy,
    Product? product,
  });

  @override
  $ProductCopyWith<$Res>? get product;
}

/// @nodoc
class __$$StockMovementImplCopyWithImpl<$Res>
    extends _$StockMovementCopyWithImpl<$Res, _$StockMovementImpl>
    implements _$$StockMovementImplCopyWith<$Res> {
  __$$StockMovementImplCopyWithImpl(
    _$StockMovementImpl _value,
    $Res Function(_$StockMovementImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of StockMovement
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? shopId = null,
    Object? productId = null,
    Object? type = null,
    Object? qtyDelta = null,
    Object? reason = freezed,
    Object? linkedOrderId = freezed,
    Object? createdAt = null,
    Object? updatedAt = null,
    Object? lastModified = null,
    Object? deletedAt = freezed,
    Object? version = null,
    Object? createdBy = freezed,
    Object? updatedBy = freezed,
    Object? product = freezed,
  }) {
    return _then(
      _$StockMovementImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        shopId: null == shopId
            ? _value.shopId
            : shopId // ignore: cast_nullable_to_non_nullable
                  as String,
        productId: null == productId
            ? _value.productId
            : productId // ignore: cast_nullable_to_non_nullable
                  as String,
        type: null == type
            ? _value.type
            : type // ignore: cast_nullable_to_non_nullable
                  as StockMovementType,
        qtyDelta: null == qtyDelta
            ? _value.qtyDelta
            : qtyDelta // ignore: cast_nullable_to_non_nullable
                  as int,
        reason: freezed == reason
            ? _value.reason
            : reason // ignore: cast_nullable_to_non_nullable
                  as String?,
        linkedOrderId: freezed == linkedOrderId
            ? _value.linkedOrderId
            : linkedOrderId // ignore: cast_nullable_to_non_nullable
                  as String?,
        createdAt: null == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        updatedAt: null == updatedAt
            ? _value.updatedAt
            : updatedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        lastModified: null == lastModified
            ? _value.lastModified
            : lastModified // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        deletedAt: freezed == deletedAt
            ? _value.deletedAt
            : deletedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        version: null == version
            ? _value.version
            : version // ignore: cast_nullable_to_non_nullable
                  as int,
        createdBy: freezed == createdBy
            ? _value.createdBy
            : createdBy // ignore: cast_nullable_to_non_nullable
                  as String?,
        updatedBy: freezed == updatedBy
            ? _value.updatedBy
            : updatedBy // ignore: cast_nullable_to_non_nullable
                  as String?,
        product: freezed == product
            ? _value.product
            : product // ignore: cast_nullable_to_non_nullable
                  as Product?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$StockMovementImpl extends _StockMovement {
  const _$StockMovementImpl({
    required this.id,
    required this.shopId,
    required this.productId,
    required this.type,
    required this.qtyDelta,
    this.reason,
    this.linkedOrderId,
    required this.createdAt,
    required this.updatedAt,
    required this.lastModified,
    this.deletedAt,
    this.version = 1,
    this.createdBy,
    this.updatedBy,
    this.product,
  }) : super._();

  factory _$StockMovementImpl.fromJson(Map<String, dynamic> json) =>
      _$$StockMovementImplFromJson(json);

  @override
  final String id;
  @override
  final String shopId;
  @override
  final String productId;
  @override
  final StockMovementType type;
  @override
  final int qtyDelta;
  @override
  final String? reason;
  @override
  final String? linkedOrderId;
  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;
  @override
  final DateTime lastModified;
  @override
  final DateTime? deletedAt;
  @override
  @JsonKey()
  final int version;
  @override
  final String? createdBy;
  @override
  final String? updatedBy;
  // Optional embedded product data
  @override
  final Product? product;

  @override
  String toString() {
    return 'StockMovement(id: $id, shopId: $shopId, productId: $productId, type: $type, qtyDelta: $qtyDelta, reason: $reason, linkedOrderId: $linkedOrderId, createdAt: $createdAt, updatedAt: $updatedAt, lastModified: $lastModified, deletedAt: $deletedAt, version: $version, createdBy: $createdBy, updatedBy: $updatedBy, product: $product)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$StockMovementImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.shopId, shopId) || other.shopId == shopId) &&
            (identical(other.productId, productId) ||
                other.productId == productId) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.qtyDelta, qtyDelta) ||
                other.qtyDelta == qtyDelta) &&
            (identical(other.reason, reason) || other.reason == reason) &&
            (identical(other.linkedOrderId, linkedOrderId) ||
                other.linkedOrderId == linkedOrderId) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt) &&
            (identical(other.lastModified, lastModified) ||
                other.lastModified == lastModified) &&
            (identical(other.deletedAt, deletedAt) ||
                other.deletedAt == deletedAt) &&
            (identical(other.version, version) || other.version == version) &&
            (identical(other.createdBy, createdBy) ||
                other.createdBy == createdBy) &&
            (identical(other.updatedBy, updatedBy) ||
                other.updatedBy == updatedBy) &&
            (identical(other.product, product) || other.product == product));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    shopId,
    productId,
    type,
    qtyDelta,
    reason,
    linkedOrderId,
    createdAt,
    updatedAt,
    lastModified,
    deletedAt,
    version,
    createdBy,
    updatedBy,
    product,
  );

  /// Create a copy of StockMovement
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$StockMovementImplCopyWith<_$StockMovementImpl> get copyWith =>
      __$$StockMovementImplCopyWithImpl<_$StockMovementImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$StockMovementImplToJson(this);
  }
}

abstract class _StockMovement extends StockMovement {
  const factory _StockMovement({
    required final String id,
    required final String shopId,
    required final String productId,
    required final StockMovementType type,
    required final int qtyDelta,
    final String? reason,
    final String? linkedOrderId,
    required final DateTime createdAt,
    required final DateTime updatedAt,
    required final DateTime lastModified,
    final DateTime? deletedAt,
    final int version,
    final String? createdBy,
    final String? updatedBy,
    final Product? product,
  }) = _$StockMovementImpl;
  const _StockMovement._() : super._();

  factory _StockMovement.fromJson(Map<String, dynamic> json) =
      _$StockMovementImpl.fromJson;

  @override
  String get id;
  @override
  String get shopId;
  @override
  String get productId;
  @override
  StockMovementType get type;
  @override
  int get qtyDelta;
  @override
  String? get reason;
  @override
  String? get linkedOrderId;
  @override
  DateTime get createdAt;
  @override
  DateTime get updatedAt;
  @override
  DateTime get lastModified;
  @override
  DateTime? get deletedAt;
  @override
  int get version;
  @override
  String? get createdBy;
  @override
  String? get updatedBy; // Optional embedded product data
  @override
  Product? get product;

  /// Create a copy of StockMovement
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$StockMovementImplCopyWith<_$StockMovementImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
