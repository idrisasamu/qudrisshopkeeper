# 🚀 Quick Start - Testing Your Supabase Inventory

**Status**: ✅ Code fixed and ready  
**Next**: Run the app and test!

---

## ⚡ Start the App

The app is building in the background. Once it starts, you'll see:

### 1. Visual Debug Banner (Yellow)
```
🔍 DEBUG: Shop: c497593c | Source: Supabase | Count: 0
```

This confirms:
- ✅ Using the correct shop
- ✅ Connected to Supabase (not local Drive)
- ✅ Current product count

### 2. Dev Test Button (Blue)
```
DEV: Create Test Product
```

**Click this** to test the complete flow!

---

## 🧪 What the Test Button Does

```
1. Creates a test product in Supabase
   ↓
2. Adds 10 units of initial stock
   ↓
3. Waits 500ms
   ↓
4. Adjusts stock +10 more
   ↓
5. Final: Product with 20 units total
```

---

## 🔍 Console Logs to Watch

### When App Starts:
```
[RT] Subscribing to products table, shopId=c497593c...
[RT] Subscribing to inventory table, shopId=c497593c...
[DEBUG] getProducts: shopId=c497593c..., returned 0 products
```

### When You Click Test Button:
```
[DEV TEST] Starting inventory test...
[DEV TEST] ShopId: c497593c-8a20-4a43-8548-8043f58c4fde

[DEBUG] createProduct: shopId=c497593c..., name=Test Product..., initialQty=10
[DEBUG] createProduct: product created, id=abc123...
[DEBUG] createProduct: creating inventory record, qty=10, table=inventory
[DEBUG] createProduct: recording stock movement, table=stock_movements
[DEBUG] createProduct: completed successfully

[DEV TEST] Product created: id=abc123..., name=Test Product...

[DEBUG] adjustStock: shopId=c497593c..., productId=abc123..., qtyDelta=10
[DEBUG] adjustStock: completed, movementId=mov456...

[DEV TEST] Stock adjusted: movementId=mov456...

[RT] products change: products INSERT id=abc123..., shop_id=c497593c...
🔄 Real-time: Product inserted, refreshing inventory...
[DEBUG] getProducts: shopId=c497593c..., returned 1 products

[RT] inventory change: inventory INSERT product_id=abc123..., on_hand_qty=10
🔄 Real-time: Inventory changed, refreshing stock levels...
[DEBUG] getProducts: shopId=c497593c..., returned 1 products

[RT] inventory change: inventory UPDATE product_id=abc123..., on_hand_qty=20
🔄 Real-time: Inventory changed, refreshing stock levels...
[DEBUG] getProducts: shopId=c497593c..., returned 1 products
```

### Success Message:
```
✅ DEV TEST: Created "Test Product 1728567890123" with 20 units total
```

---

## ✅ What to Verify

After clicking the test button:

1. **Green snackbar** appears: "DEV TEST: Created..."
2. **New product** appears in list with **[20]** units
3. **Console shows all logs** above
4. **Realtime events** trigger (`[RT]` messages)
5. **Multiple refreshes** happen (initial insert + 2 inventory updates)

---

## 🎯 Next: Test Multi-Device

### Setup:
1. Keep Device A running (current emulator)
2. Start Device B in another terminal:
   ```bash
   flutter run -d <device-id>
   ```

### Test:
1. **Device A**: Click test button (creates product)
2. **Device B**: Should see product appear **< 2 seconds** ⚡

---

## ⚠️ Critical: Enable Realtime in Supabase

For multi-device sync to work, you MUST:

1. Go to https://app.supabase.com
2. Open your project
3. Navigate to: **Database → Replication**
4. Enable realtime for:
   - ✅ `products` table
   - ✅ `inventory` table

**Without this, realtime won't work across devices!**

---

## 🔧 If Issues Occur

### No Test Button Visible?
- Check you're logged in as Owner (not Staff)
- Check you're on the Inventory page
- Button is blue, says "DEV: Create Test Product"

### Test Fails?
- Check console for `[DEV TEST ERROR]` message
- Verify shopId is not NULL in logs
- Check Supabase dashboard for RLS policy errors

### No Realtime Updates?
- Enable realtime in Supabase dashboard
- Check for `[RT]` logs in console
- Verify both devices use same shop_id

---

## 📊 Files Modified (3 total)

1. `lib/app/router.dart` - Uses Supabase screens
2. `lib/data/repositories/supabase_inventory_repository.dart` - Debug logs
3. `lib/features/inventory/inventory_page_supabase.dart` - UI + test button

---

**Ready?** The app should be running. Look for the yellow debug banner! 🎉

