# Quick Integration Steps

## 1. Install Dependencies (if not already installed)

Add to `pubspec.yaml`:

```yaml
dependencies:
  freezed_annotation: ^2.4.1

dev_dependencies:
  build_runner: ^2.4.6
  freezed: ^2.4.5
  json_serializable: ^6.7.1
```

Then run:
```bash
flutter pub get
```

## 2. Generate Freezed Code

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

This will generate:
- `lib/data/models/product.freezed.dart`
- `lib/data/models/product.g.dart`

## 3. Run Supabase Migration

1. Go to your Supabase Dashboard → SQL Editor
2. Open `supabase/migrations/004_inventory_system.sql`
3. Copy the entire contents
4. Paste into SQL Editor and click "Run"
5. Verify tables created: `products`, `inventory`, `stock_movements`

## 4. Enable Realtime for Tables

In Supabase Dashboard → Database → Replication:

Enable realtime for:
- ✅ `products`
- ✅ `inventory`
- ✅ `stock_movements`

## 5. Update Router

In `lib/app/router.dart`, replace old inventory routes:

```dart
// Find these lines and replace:

// BEFORE:
import '../features/inventory/inventory_page.dart';
import '../features/inventory/low_stock_page.dart';

// AFTER:
import '../features/inventory/inventory_page_supabase.dart';
import '../features/inventory/low_stock_page_supabase.dart';

// BEFORE:
GoRoute(
  path: 'inventory',
  builder: (context, state) => const InventoryPage(),
),

// AFTER:
GoRoute(
  path: 'inventory',
  builder: (context, state) => const InventoryPageSupabase(),
),

// BEFORE:
GoRoute(
  path: 'low-stock',
  builder: (context, state) => const LowStockPage(),
),

// AFTER:
GoRoute(
  path: 'low-stock',
  builder: (context, state) => const LowStockPageSupabase(),
),
```

## 6. Update Sales Page (Optional but Recommended)

In `lib/features/sales/new_sale_page.dart`:

Replace manual stock decrement with Supabase provider:

```dart
// BEFORE (around line 418-434):
await db.into(db.stockMovements).insert(
  StockMovementsCompanion.insert(
    id: stockMovementId,
    shopId: currentShopId,
    itemId: saleItem.itemWithStock.item.id,
    type: 'out',
    qty: saleItem.quantity,
    unitCost: 0.0,
    unitPrice: saleItem.itemWithStock.item.salePrice,
    reason: const drift.Value('Sale - Item sold'),
    byUserId: byUserId,
    at: now,
  ),
);

// AFTER:
final processSale = ref.read(processSaleProvider);
await processSale(
  productId: saleItem.itemWithStock.item.id,
  qtySold: saleItem.quantity.toInt(),
  orderId: saleId,
);
```

Don't forget to add the import at the top:
```dart
import '../../providers/inventory_provider.dart';
```

## 7. Test the Integration

### Test 1: Owner Adds Product
1. Login as owner
2. Go to Inventory page
3. Click "Add Product"
4. Fill in product details
5. Submit
6. ✅ Product should appear in list

### Test 2: Staff Sees Product (Realtime)
1. Login as staff on another device/browser
2. Go to Inventory page
3. Have owner add a new product
4. ✅ Staff should see it appear within 1 second

### Test 3: Manager Adjusts Stock
1. Login as manager
2. Open a product
3. Click "Add Stock" or "Remove Stock"
4. Enter quantity
5. ✅ Stock should update immediately for all users

### Test 4: Cashier Processes Sale
1. Login as cashier
2. Go to Sales/POS page
3. Add items to cart
4. Complete sale
5. ✅ Inventory should decrement
6. ✅ All users see updated stock

### Test 5: Low Stock Alerts
1. Set a product's reorder level to 10
2. Reduce stock to 8
3. Go to Low Stock page
4. ✅ Product should appear in alert list

## 8. Verify RLS Policies Work

### Test as Cashier:
- ✅ Can view products
- ✅ Can process sales (decrements inventory)
- ❌ Cannot add products
- ❌ Cannot edit products
- ❌ Cannot adjust stock manually

### Test as Manager:
- ✅ Can view products
- ✅ Can add products
- ✅ Can edit products
- ✅ Can adjust stock
- ✅ Can process sales

### Test as Owner:
- ✅ Full access to everything

## 9. Optional: Remove Old Files

Once everything is tested and working:

```bash
# Backup first!
mv lib/features/inventory/inventory_page.dart lib/features/inventory/inventory_page.dart.backup
mv lib/features/inventory/low_stock_page.dart lib/features/inventory/low_stock_page.dart.backup

# Or delete permanently
rm lib/features/inventory/inventory_page.dart
rm lib/features/inventory/low_stock_page.dart
```

## Troubleshooting

### "Table does not exist" error
- Run the SQL migration again
- Check Supabase Dashboard → Database → Tables

### "RLS policy violation" error
- Verify user is in `staff` table for the shop
- Check `is_active` is true
- Verify `shop_id` matches

### Realtime not working
- Enable Realtime in Supabase Dashboard → Database → Replication
- Check browser console for WebSocket errors
- Verify Supabase URL and anon key are correct

### Products not loading
- Check Network tab in browser DevTools
- Look for 401/403 errors (RLS issue)
- Verify user authentication

### Build runner errors
```bash
# Clean and rebuild
flutter clean
flutter pub get
flutter pub run build_runner clean
flutter pub run build_runner build --delete-conflicting-outputs
```

## Support

If you encounter issues:
1. Check browser console for errors
2. Check Supabase logs (Dashboard → Logs → API)
3. Verify RLS policies with `EXPLAIN` queries
4. Test API calls directly in Supabase Dashboard → API

---

**You're all set!** 🎉 

Your inventory system now uses Supabase with real-time multi-user collaboration. Staff can see owner's inventory changes instantly!

