# 📊 Data Flow: Where Your Inventory Is Stored

## ✅ Your Inventory Is Stored in Supabase Cloud!

When the owner (or any authorized user) adds inventory, here's what happens:

---

## 🔄 Complete Flow

```
┌─────────────────────────────────────────────────────────────┐
│  OWNER'S PHONE                                              │
│                                                             │
│  1. Owner opens "Add Product" screen                        │
│  2. Fills in: Name, Price, SKU, Initial Stock               │
│  3. Clicks "Add Product"                                    │
│     ↓                                                        │
│  4. App calls: createProduct()                              │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      │ ⬇️ SENDS DATA TO CLOUD
                      │
    ┌─────────────────▼──────────────────────────────┐
    │   SUPABASE CLOUD DATABASE (PostgreSQL)         │
    │   🌐 Hosted on Supabase servers                │
    │                                                 │
    │   ✅ INSERT INTO products TABLE:                │
    │      - id: uuid                                 │
    │      - shop_id: your_shop_id                   │
    │      - name: "Product Name"                    │
    │      - price_cents: 99900                      │
    │      - sku: "SKU001"                           │
    │      - reorder_level: 10                       │
    │      - created_by: owner_user_id               │
    │      - created_at: timestamp                   │
    │                                                 │
    │   ✅ INSERT INTO inventory TABLE:               │
    │      - product_id: uuid                        │
    │      - shop_id: your_shop_id                   │
    │      - on_hand_qty: 50                         │
    │      - on_reserved_qty: 0                      │
    │                                                 │
    │   ✅ INSERT INTO stock_movements TABLE:         │
    │      - id: uuid                                │
    │      - product_id: uuid                        │
    │      - type: 'purchase'                        │
    │      - qty_delta: +50                          │
    │      - reason: 'Initial stock'                 │
    │                                                 │
    └─────────────────┬──────────────────────────────┘
                      │
                      │ ⬇️ REAL-TIME BROADCAST
                      │
    ┌─────────────────▼──────────────────────────────┐
    │   REAL-TIME WEBSOCKET NOTIFICATION             │
    │   "New product added to shop!"                 │
    └─────────────────┬──────────────────────────────┘
                      │
        ┌─────────────┼─────────────┬─────────────┐
        │             │             │             │
        ▼             ▼             ▼             ▼
┌───────────┐ ┌───────────┐ ┌───────────┐ ┌───────────┐
│  OWNER'S  │ │  STAFF    │ │  STAFF    │ │  MANAGER  │
│  PHONE    │ │  PHONE 1  │ │  PHONE 2  │ │  TABLET   │
│           │ │           │ │           │ │           │
│ ✅ Updated│ │ ✅ Updated│ │ ✅ Updated│ │ ✅ Updated│
│ Shows new │ │ Shows new │ │ Shows new │ │ Shows new │
│ product!  │ │ product!  │ │ product!  │ │ product!  │
└───────────┘ └───────────┘ └───────────┘ └───────────┘
```

---

## 🎯 To Answer Your Question

### Where is the data stored?

| Storage Location | Is Data Saved Here? | Purpose |
|-----------------|-------------------|---------|
| **Supabase Cloud** | ✅ **YES! PRIMARY STORAGE** | Main database, accessible by all devices |
| Owner's Phone | ❌ No (not permanently) | Only cached temporarily for offline viewing |
| Staff Phone | ❌ No (not permanently) | Only cached temporarily for offline viewing |

### Key Points

1. **Primary Storage = Supabase Cloud** ☁️
   - All inventory data lives in Supabase PostgreSQL database
   - Accessible from anywhere with internet
   - Shared by all devices in the store
   - Backed up by Supabase

2. **Phones = Temporary Cache** 📱
   - Phones only cache data temporarily for faster viewing
   - Cache clears when app closes or memory is cleared
   - Phones always fetch fresh data from Supabase

---

## 📝 Detailed Code Breakdown

### When Owner Clicks "Add Product"

```dart
// File: lib/features/inventory/inventory_page_supabase.dart
// Line 458: Submit handler

Future<void> _handleSubmit() async {
  // Prepare data
  final createProduct = ref.read(createProductProvider);
  
  // This calls the repository
  await createProduct(
    name: 'Test Product',
    priceCents: 99900,
    initialQty: 50,
    // ... other fields
  );
}
```

### Repository Sends to Supabase

```dart
// File: lib/data/repositories/supabase_inventory_repository.dart
// Lines 138-156: Direct Supabase insert

Future<Product> createProduct(...) async {
  final userId = _client.auth.currentUser?.id;

  // ✅ INSERT INTO SUPABASE CLOUD DATABASE
  final productRow = await _client
      .from('products')              // ← Supabase cloud table
      .insert({                      // ← Sends to cloud!
        'shop_id': shopId,
        'name': name,
        'price_cents': priceCents,
        'sku': sku,
        'reorder_level': reorderLevel,
        'created_by': userId,        // Tracks who created it
        'created_at': now(),         // Tracks when created
      })
      .select()
      .single();

  // ✅ INSERT INVENTORY INTO SUPABASE
  if (initialQty > 0) {
    await _client.from('inventory').upsert({  // ← Cloud database
      'product_id': product.id,
      'shop_id': shopId,
      'on_hand_qty': initialQty,  // Initial stock quantity
    });

    // ✅ RECORD STOCK MOVEMENT IN SUPABASE
    await _client.rpc('perform_stock_movement', params: {
      'p_shop_id': shopId,
      'p_product_id': product.id,
      'p_qty_delta': initialQty,
      'p_reason': 'Initial stock',
    });
  }

  return product;
}
```

**As you can see**: All `.from('table_name')` calls go directly to **Supabase cloud**!

---

## 🌐 Why This Is Great for Your Store

### 1. **Centralized Data** ☁️
- One source of truth for all devices
- No conflicts between devices
- Everyone sees the same inventory

### 2. **Real-Time Sync** ⚡
- Owner adds product → All staff see it instantly
- Staff makes sale → Owner sees stock decrease
- No manual syncing needed

### 3. **Accessible Anywhere** 🌍
- Owner can check inventory from home
- Manager can view reports from anywhere
- Staff can use any device

### 4. **Data Safety** 🔒
- Backed up automatically by Supabase
- Not lost if phone breaks
- Can restore anytime

### 5. **Multi-Device** 📱💻
- Works on phones, tablets, computers
- Owner can use multiple devices
- Staff can share devices

### 6. **Audit Trail** 📊
- Every change tracked in `stock_movements` table
- Know who created what and when
- Full history for reporting

---

## 🔍 How to Verify Data Is in Supabase

### Option 1: Supabase Dashboard

1. Go to https://app.supabase.com
2. Open your project
3. Click **Table Editor**
4. View tables:
   - **products** - See all products
   - **inventory** - See stock levels
   - **stock_movements** - See all changes

### Option 2: Add Product and Check

1. Owner adds a product on Phone A
2. Open Supabase dashboard
3. Go to **Table Editor** → **products**
4. See the new product row with all details!

### Option 3: Test with Second Device

1. Owner adds product on Phone A
2. Staff opens app on Phone B
3. Staff sees the product immediately
4. This proves it's in Supabase cloud (not local)!

---

## 📊 What Gets Stored in Supabase

### Products Table
```sql
CREATE TABLE products (
  id UUID PRIMARY KEY,
  shop_id UUID NOT NULL,           -- Your store ID
  name TEXT NOT NULL,               -- Product name
  sku TEXT,                         -- SKU code
  price_cents INTEGER NOT NULL,     -- Price in cents
  cost_cents INTEGER,               -- Cost price
  barcode TEXT,                     -- Barcode
  reorder_level INTEGER DEFAULT 0,  -- Low stock threshold
  is_active BOOLEAN DEFAULT TRUE,   -- Active/inactive
  created_by UUID,                  -- Who created it
  created_at TIMESTAMPTZ,           -- When created
  updated_at TIMESTAMPTZ,           -- Last updated
  version INTEGER                   -- For conflict resolution
);
```

### Inventory Table
```sql
CREATE TABLE inventory (
  product_id UUID PRIMARY KEY,
  shop_id UUID NOT NULL,
  on_hand_qty INTEGER NOT NULL,      -- Available stock
  on_reserved_qty INTEGER NOT NULL,  -- Reserved for orders
  updated_at TIMESTAMPTZ,
  version INTEGER
);
```

### Stock Movements Table (Audit Trail)
```sql
CREATE TABLE stock_movements (
  id UUID PRIMARY KEY,
  shop_id UUID NOT NULL,
  product_id UUID NOT NULL,
  type TEXT NOT NULL,                -- 'purchase', 'sale', 'adjustment'
  qty_delta INTEGER NOT NULL,        -- +50 or -2
  reason TEXT,                       -- Why changed
  created_by UUID,                   -- Who made the change
  created_at TIMESTAMPTZ             -- When it happened
);
```

---

## 🚀 Summary

### Your Question
> "When owner adds inventory, does it record in Supabase for the store or just on the phone?"

### Answer
✅ **Records in Supabase (Cloud Database for the ENTIRE Store)**

**NOT** just on the phone!

### Why This Matters

1. **All devices** in your store access the **same cloud database**
2. **Changes by anyone** are immediately visible to **everyone**
3. **Data is safe** in the cloud, not dependent on one phone
4. **You can access** your inventory from **any device, anywhere**
5. **Supabase handles** backups, security, and real-time sync

### Visual Summary

```
❌ NOT THIS (Local Only):
Owner's Phone → Local Storage
   ↓
   Only owner sees it
   Lost if phone breaks

✅ YES THIS (Cloud Shared):
Owner's Phone → Supabase Cloud ← Staff Phone 1
                      ↑         ← Staff Phone 2
                      ↑         ← Manager Tablet
                      ↑         ← Owner's Home Computer
                      ↑
                All devices see same data!
                Backed up automatically!
                Accessible anywhere!
```

---

## 🎉 You Have a Modern Cloud-Based POS System!

Your inventory system uses **Supabase** as a centralized cloud database, making it:

- ✅ Multi-user (unlimited devices)
- ✅ Real-time synced (< 1 second updates)
- ✅ Cloud-backed (never lose data)
- ✅ Accessible anywhere (internet required)
- ✅ Enterprise-grade (PostgreSQL database)

**Bottom line**: When owner adds inventory, it goes **straight to the cloud** and is **immediately available to everyone** in the store! 🚀

---

**Need proof?** Add a product on one device, then open the Supabase dashboard - you'll see it right there in the cloud database! 🌐

