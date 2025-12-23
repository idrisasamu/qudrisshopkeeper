# 🧪 Dual Emulator Testing Guide - Realtime Inventory Sync

## 🎯 Goal
Verify that when the **Owner adds/edits inventory** on Device 1, the **Staff sees it instantly** on Device 2.

## 🚀 Setup: Launch 2 Emulators

### Option 1: iOS + Android
```bash
# Terminal 1 - Start iOS simulator
open -a Simulator

# Terminal 2 - Start Android emulator
~/Library/Android/sdk/emulator/emulator -avd Pixel_7_API_34 &

# Terminal 3 - Run on iOS
cd "/Users/idrisasamu/projects/Qudris ShopKeeper/qudris_shopkeeper"
flutter run -d "iPhone 15 Pro"

# Terminal 4 - Run on Android (in new terminal)
flutter run -d emulator-5554
```

### Option 2: Two Android Emulators
```bash
# Terminal 1 - Start first emulator
~/Library/Android/sdk/emulator/emulator -avd Pixel_7_API_34 &

# Terminal 2 - Start second emulator (different AVD)
~/Library/Android/sdk/emulator/emulator -avd Pixel_6_API_33 &

# Terminal 3 - Run on first device
flutter run -d emulator-5554

# Terminal 4 - Run on second device
flutter run -d emulator-5556
```

### Option 3: Using Flutter Device Selector
```bash
# List available devices
flutter devices

# Run with device selector (opens picker)
flutter run
# Choose Device 1 from list

# In another terminal, run again
flutter run
# Choose Device 2 from list
```

## 📱 Test Scenarios

### Test 1: Owner Adds Product → Staff Sees Instantly ⚡

**Device 1 (Owner):**
1. Login as Owner (Google Sign-In)
2. Navigate to **Inventory** page
3. Click **"+ Add Product"** button
4. Fill in:
   - Name: `Test Laptop`
   - SKU: `LAP001`
   - Sale Price: `999.99`
   - Initial Quantity: `10`
5. Click **"Add Product"**

**Device 2 (Staff):**
1. Login as Staff (PIN: Use staff account)
2. Navigate to **Inventory** page
3. **WATCH THE SCREEN** 👀

**✅ Expected Result:**
- Within 1-2 seconds, "Test Laptop" appears on Staff device
- No manual refresh needed
- Stock shows "10"

**📹 What to Look For:**
- New product card fades in automatically
- Product appears at correct alphabetical position
- Stock badge shows correct quantity

---

### Test 2: Manager Adjusts Stock → All Devices Update 📊

**Device 1 (Manager/Owner):**
1. Find "Test Laptop" in inventory
2. Tap on the product
3. Click **"Add Stock"**
4. Enter quantity: `5`
5. Reason: `Restock from supplier`
6. Click **"Confirm"**

**Device 2 (Staff - watching Inventory page):**
**✅ Expected Result:**
- Stock changes from "10" → "15" instantly
- No reload needed

**Device 2 (Alternative - watching Low Stock page):**
- If product was in low stock list and stock goes above reorder level
- Product disappears from low stock list automatically

---

### Test 3: Cashier Processes Sale → Inventory Decrements 🛒

**Device 2 (Staff/Cashier):**
1. Navigate to **Sales/POS** page
2. Search for "Test Laptop"
3. Add to cart: Quantity `2`
4. Complete the sale

**Device 1 (Owner - watching Inventory page):**
**✅ Expected Result:**
- "Test Laptop" stock changes from "15" → "13" instantly
- Update happens immediately after sale completion

---

### Test 4: Owner Edits Product Details → Staff Sees Changes ✏️

**Device 1 (Owner):**
1. Tap on "Test Laptop"
2. Click **"Edit"** (three-dot menu)
3. Change:
   - Name: `Premium Laptop`
   - Price: `1299.99`
4. Save changes

**Device 2 (Staff):**
**✅ Expected Result:**
- Product name updates to "Premium Laptop"
- Price updates to "$1,299.99"
- Changes appear within 1-2 seconds

---

### Test 5: Low Stock Alerts → Realtime Threshold Triggers 🚨

**Setup:**
1. Create product with Reorder Level: `10`
2. Set Initial Stock: `12`

**Device 1 (Owner):**
1. Process stock adjustment: `-5` (brings stock to 7)

**Device 2 (Staff - on Low Stock page):**
**✅ Expected Result:**
- Product appears in low stock list automatically
- Orange warning badge appears
- Progress bar turns red

**Device 1 (Owner):**
1. Add stock: `+5` (brings stock back to 12)

**Device 2 (Staff - still on Low Stock page):**
**✅ Expected Result:**
- Product disappears from low stock list
- No longer shows warning

---

### Test 6: Owner Deletes Product → Staff Sees Removal 🗑️

**Device 1 (Owner):**
1. Tap on "Test Laptop"
2. Click **three-dot menu** → **"Delete"**
3. Confirm deletion

**Device 2 (Staff):**
**✅ Expected Result:**
- "Test Laptop" card fades out
- Product removed from list instantly
- Total count updates

---

### Test 7: Search Still Works During Realtime Updates 🔍

**Device 2 (Staff):**
1. Type in search box: `laptop`
2. Only laptop products visible

**Device 1 (Owner):**
1. Add new product: `Gaming Mouse`

**Device 2 (Staff):**
**✅ Expected Result:**
- "Gaming Mouse" does NOT appear (filtered out by search)
- "Test Laptop" still visible (matches search)

**Device 2 (Staff):**
1. Clear search box

**✅ Expected Result:**
- "Gaming Mouse" now appears (search cleared)

---

## 🔧 Debugging Realtime Connection

### Check Realtime Status in Code

Add this debug widget to see connection status:

```dart
// In inventory_page_supabase.dart, add to AppBar actions:
IconButton(
  icon: Icon(
    Supabase.instance.client.realtime.connectedChannels.isNotEmpty
        ? Icons.wifi
        : Icons.wifi_off,
    color: Supabase.instance.client.realtime.connectedChannels.isNotEmpty
        ? Colors.green
        : Colors.red,
  ),
  onPressed: () {
    print('Connected channels: ${Supabase.instance.client.realtime.connectedChannels}');
  },
),
```

### Check Browser Console (if using Chrome DevTools)

```bash
# Connect Flutter DevTools
flutter run --observatory-port=8888

# In Chrome: chrome://inspect
# Look for WebSocket connections to Supabase
```

### Verify Realtime in Supabase Dashboard

1. Go to Supabase Dashboard
2. Navigate to **Database** → **Replication**
3. Verify these are enabled:
   - ✅ `products`
   - ✅ `inventory`
   - ✅ `stock_movements`

### Check Network Logs

**Terminal Output:**
```
DEBUG: Subscribed to products-{shop_id}
DEBUG: Realtime channel active: products-{shop_id}
DEBUG: Received postgres_changes event: INSERT
DEBUG: Invalidating productsProvider
```

---

## 📊 Performance Benchmarks

| Action | Expected Latency | Max Acceptable |
|--------|------------------|----------------|
| Product Insert | < 1 second | 2 seconds |
| Stock Update | < 500ms | 1 second |
| Product Edit | < 1 second | 2 seconds |
| Product Delete | < 500ms | 1 second |
| Low Stock Alert | < 2 seconds | 3 seconds |

---

## ✅ Test Checklist

Print this and check off as you test:

### Realtime Sync
- [ ] Owner adds product → Staff sees instantly
- [ ] Manager adjusts stock → All devices update
- [ ] Cashier processes sale → Inventory decrements everywhere
- [ ] Owner edits product → Staff sees changes
- [ ] Owner deletes product → Staff sees removal
- [ ] Low stock threshold triggers alerts on all devices

### Permissions (RLS)
- [ ] Cashier CANNOT add products (button hidden/disabled)
- [ ] Cashier CANNOT edit products
- [ ] Cashier CANNOT adjust stock manually
- [ ] Cashier CAN process sales (decrements inventory)
- [ ] Manager CAN add/edit products
- [ ] Manager CAN adjust stock
- [ ] Owner has full access

### UI/UX
- [ ] Products appear in alphabetical order
- [ ] Search filters correctly during realtime updates
- [ ] Stock badges show correct quantities
- [ ] Low stock items have red badges
- [ ] Loading states show while fetching
- [ ] Error states show if network fails

### Edge Cases
- [ ] Network disconnect → reconnect (realtime resumes)
- [ ] Multiple rapid updates don't crash
- [ ] Negative stock prevented
- [ ] Empty inventory shows empty state
- [ ] Search with no results shows "No products found"

---

## 🎬 Video Recording Tips

If recording a demo:

1. **Split Screen Setup:**
   - Left: Owner device
   - Right: Staff device
   - Both showing Inventory page

2. **Demo Script:**
   ```
   "Watch the right screen (Staff) as I add a product on the left (Owner)..."
   [Add product on left]
   [Point to right screen when it appears]
   "There! It appeared within 1 second with no manual refresh!"
   ```

3. **Camera Angles:**
   - Show both emulators simultaneously
   - Highlight the exact moment the update appears
   - Show timestamp difference is < 1 second

---

## 🐛 Common Issues & Fixes

### Issue: Realtime not working
**Symptoms:** Changes don't appear on other device

**Fixes:**
1. Check Supabase Dashboard → Database → Replication (enable tables)
2. Verify internet connection on both emulators
3. Check Supabase project URL and anon key are correct
4. Restart the app (hot reload may not reinitialize realtime)

### Issue: "RLS policy violation" error
**Symptoms:** 401/403 errors in console

**Fixes:**
1. Verify user is in `staff` table for the shop
2. Check `shop_id` matches current shop
3. Run migration SQL again
4. Check `is_active` is true

### Issue: Duplicate products appear
**Symptoms:** Same product shows multiple times

**Fixes:**
1. Invalidate provider: `ref.invalidate(productsProvider)`
2. Check unique constraint on `(shop_id, sku)`
3. Clear app data and re-login

### Issue: Stock doesn't decrement on sale
**Symptoms:** Sale completes but inventory unchanged

**Fixes:**
1. Check `perform_sale_inventory_adjustment` RPC exists
2. Verify RLS policies allow INSERT into `stock_movements`
3. Check console for SQL errors

---

## 🎉 Success Criteria

Your realtime inventory sync is working if:

✅ All 7 test scenarios pass  
✅ Updates appear within 2 seconds  
✅ No manual refresh needed  
✅ RLS permissions work correctly  
✅ Multiple users can collaborate simultaneously  
✅ Stock levels stay consistent across devices  
✅ Low stock alerts trigger for all users  

---

## 📸 Screenshots to Capture

1. **Before/After Product Add:**
   - Device 1: Add Product form
   - Device 2: Empty list → Product appears

2. **Stock Adjustment:**
   - Device 1: Stock adjustment dialog
   - Device 2: Stock number changing

3. **Low Stock Alert:**
   - Device 1: Product below threshold
   - Device 2: Alert appears automatically

4. **Permissions:**
   - Cashier screen: "Add Product" button hidden
   - Manager screen: Full access visible

---

**Happy Testing! 🚀**

If all tests pass, your Supabase inventory system is production-ready for multi-user collaboration!

