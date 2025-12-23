# 🎬 Realtime Demo - Visual Guide

## Quick Start

```bash
# Option 1: Automated script
./test_realtime.sh

# Option 2: Manual
flutter run    # Select first device
flutter run    # Select second device
```

---

## 📱 Side-by-Side Visual Test

```
┌─────────────────────────────┐    ┌─────────────────────────────┐
│   DEVICE 1 - OWNER          │    │   DEVICE 2 - STAFF          │
│   (Google Login)            │    │   (PIN Login)               │
├─────────────────────────────┤    ├─────────────────────────────┤
│                             │    │                             │
│  📦 Inventory               │    │  📦 Inventory               │
│  ────────────────────       │    │  ────────────────────       │
│                             │    │                             │
│  [Search products...]       │    │  [Search products...]       │
│                             │    │                             │
│  ┌─────────────────────┐   │    │  ┌─────────────────────┐   │
│  │ 💻 Desktop PC       │   │    │  │ 💻 Desktop PC       │   │
│  │ SKU: PC001          │   │    │  │ SKU: PC001          │   │
│  │ $1,299.00      [25] │   │    │  │ $1,299.00      [25] │   │
│  └─────────────────────┘   │    │  └─────────────────────┘   │
│                             │    │                             │
│  ┌─────────────────────┐   │    │  ┌─────────────────────┐   │
│  │ ⌨️  Keyboard        │   │    │  │ ⌨️  Keyboard        │   │
│  │ SKU: KB001          │   │    │  │ SKU: KB001          │   │
│  │ $79.99         [50] │   │    │  │ $79.99         [50] │   │
│  └─────────────────────┘   │    │  └─────────────────────┘   │
│                             │    │                             │
│                             │    │                             │
│  [+ Add Product]            │    │                             │
│                             │    │                             │
└─────────────────────────────┘    └─────────────────────────────┘
```

---

## 🎯 Test 1: Owner Adds Product

### STEP 1: Owner clicks "Add Product"

```
┌─────────────────────────────┐    ┌─────────────────────────────┐
│   DEVICE 1 - OWNER          │    │   DEVICE 2 - STAFF          │
├─────────────────────────────┤    ├─────────────────────────────┤
│                             │    │                             │
│  Add New Product            │    │  📦 Inventory               │
│  ────────────────            │    │  ────────────────────       │
│                             │    │                             │
│  Product Name *             │    │  [Search products...]       │
│  ┌────────────────────┐    │    │                             │
│  │ Test Laptop        │    │    │  ┌─────────────────────┐   │
│  └────────────────────┘    │    │  │ 💻 Desktop PC       │   │
│                             │    │  │ $1,299.00      [25] │   │
│  SKU         Barcode        │    │  └─────────────────────┘   │
│  ┌────────┐ ┌────────┐     │    │                             │
│  │ LAP001 │ │        │     │    │  ┌─────────────────────┐   │
│  └────────┘ └────────┘     │    │  │ ⌨️  Keyboard        │   │
│                             │    │  │ $79.99         [50] │   │
│  Sale Price  Cost Price     │    │  └─────────────────────┘   │
│  ┌────────┐ ┌────────┐     │    │                             │
│  │ 999.99 │ │ 750.00 │     │    │    👀 Watching...          │
│  └────────┘ └────────┘     │    │                             │
│                             │    │                             │
│  Reorder Lvl Initial Qty    │    │                             │
│  ┌────────┐ ┌────────┐     │    │                             │
│  │   5    │ │   10   │     │    │                             │
│  └────────┘ └────────┘     │    │                             │
│                             │    │                             │
│  [Cancel]  [Add Product]    │    │                             │
│                             │    │                             │
└─────────────────────────────┘    └─────────────────────────────┘
```

### STEP 2: Owner clicks "Add Product" → 0.5 seconds later...

```
┌─────────────────────────────┐    ┌─────────────────────────────┐
│   DEVICE 1 - OWNER          │    │   DEVICE 2 - STAFF          │
├─────────────────────────────┤    ├─────────────────────────────┤
│                             │    │                             │
│  ✅ Product added!          │    │  📦 Inventory               │
│                             │    │  ────────────────────       │
│  📦 Inventory               │    │                             │
│  ────────────────────       │    │  [Search products...]       │
│                             │    │                             │
│  [Search products...]       │    │  ┌─────────────────────┐   │
│                             │    │  │ 💻 Desktop PC       │   │
│  ┌─────────────────────┐   │    │  │ $1,299.00      [25] │   │
│  │ 💻 Desktop PC       │   │    │  └─────────────────────┘   │
│  │ $1,299.00      [25] │   │    │                             │
│  └─────────────────────┘   │    │  ┌─────────────────────┐   │
│                             │    │  │ ⌨️  Keyboard        │   │
│  ┌─────────────────────┐   │    │  │ $79.99         [50] │   │
│  │ ⌨️  Keyboard        │   │    │  └─────────────────────┘   │
│  │ $79.99         [50] │   │    │                             │
│  └─────────────────────┘   │    │  ┌─────────────────────┐   │
│                             │    │  │ 💻 Test Laptop ⚡   │◄──┐│
│  ┌─────────────────────┐   │    │  │ SKU: LAP001         │   ││
│  │ 💻 Test Laptop ⭐   │   │    │  │ $999.99        [10] │   ││
│  │ SKU: LAP001         │   │    │  └─────────────────────┘   ││
│  │ $999.99        [10] │   │    │      ↑                     ││
│  └─────────────────────┘   │    │      │                     ││
│                             │    │   APPEARED                 ││
│  [+ Add Product]            │    │   INSTANTLY! 🎉            ││
│                             │    │                             │
└─────────────────────────────┘    └─────────────────────────────┘
                                              ⬆️
                                        REALTIME SYNC
                                        < 1 SECOND!
```

**✅ SUCCESS INDICATOR:** New product appears on Device 2 without refresh!

---

## 📊 Test 2: Manager Adjusts Stock

### STEP 1: Owner adjusts stock on Device 1

```
┌─────────────────────────────┐    ┌─────────────────────────────┐
│   DEVICE 1 - OWNER          │    │   DEVICE 2 - STAFF          │
├─────────────────────────────┤    ├─────────────────────────────┤
│                             │    │                             │
│  Test Laptop                │    │  📦 Inventory               │
│  ────────────────            │    │                             │
│                             │    │  ┌─────────────────────┐   │
│  SKU: LAP001                │    │  │ 💻 Test Laptop      │   │
│  Barcode: -                 │    │  │ SKU: LAP001         │   │
│  Price: $999.99             │    │  │ $999.99        [10] │◄─┐│
│  Cost: $750.00              │    │  └─────────────────────┘  │││
│  Current Stock: 10 🔴       │    │                            ││
│  Reorder Level: 5           │    │   Current stock: 10        ││
│                             │    │                            ││
│  Stock Adjustment           │    │                            ││
│  ─────────────────          │    │                            ││
│                             │    │                            ││
│  [➕ Add Stock]             │◄───┐                           ││
│  [➖ Remove Stock]          │    │                            ││
│                             │    │                            ││
│  ┌──────────────────────┐  │    │                            ││
│  │ Add Stock            │  │    │                            ││
│  │ ──────────────       │  │    │                            ││
│  │ Quantity:            │  │    │                            ││
│  │ ┌──────────────────┐ │  │    │                            ││
│  │ │ 5                │ │  │    │                            ││
│  │ └──────────────────┘ │  │    │                            ││
│  │                      │  │    │                            ││
│  │ [Cancel] [Confirm]──┼──┼────┼─ CLICK!                    ││
│  └──────────────────────┘  │    │                            ││
└─────────────────────────────┘    └─────────────────────────────┘
                                                                 │
                                    After 0.5 seconds...         │
                                                                 │
┌─────────────────────────────┐    ┌─────────────────────────────┐
│   DEVICE 1 - OWNER          │    │   DEVICE 2 - STAFF          │
├─────────────────────────────┤    ├─────────────────────────────┤
│                             │    │                             │
│  Test Laptop                │    │  📦 Inventory               │
│  ────────────────            │    │                             │
│                             │    │  ┌─────────────────────┐   │
│  Current Stock: 15 ✅       │    │  │ 💻 Test Laptop      │   │
│                             │    │  │ SKU: LAP001         │   │
│  ✅ Stock adjusted!         │    │  │ $999.99        [15] │⚡ ││
│                             │    │  └─────────────────────┘   ││
│                             │    │         ↑                  ││
│  [← Back]                   │    │    UPDATED TO 15!          ││
│                             │    │    (was 10)                ││
└─────────────────────────────┘    └─────────────────────────────┘
                                              ⬆️
                                        REALTIME UPDATE!
                                        Stock 10 → 15
```

**✅ SUCCESS INDICATOR:** Stock badge changes from [10] to [15] automatically!

---

## 🛒 Test 3: Cashier Processes Sale

### Staff processes sale on Device 2

```
┌─────────────────────────────┐    ┌─────────────────────────────┐
│   DEVICE 1 - OWNER          │    │   DEVICE 2 - STAFF/CASHIER  │
│   (Watching Inventory)      │    │   (Processing Sale)         │
├─────────────────────────────┤    ├─────────────────────────────┤
│                             │    │                             │
│  📦 Inventory               │    │  🛒 New Sale                │
│                             │    │                             │
│  ┌─────────────────────┐   │    │  [Search products...]       │
│  │ 💻 Test Laptop      │   │    │                             │
│  │ SKU: LAP001         │   │    │  Cart:                      │
│  │ $999.99        [15] │◄─┐│    │  ┌──────────────────────┐  │
│  └─────────────────────┘  ││    │  │ 💻 Test Laptop       │  │
│     ↑                     ││    │  │ Qty: 2               │  │
│     │                     ││    │  │ $999.99 × 2          │  │
│  Stock: 15                ││    │  │ = $1,999.98          │  │
│                           ││    │  └──────────────────────┘  │
│                           ││    │                             │
│                           ││    │  Total: $1,999.98           │
│                           ││    │                             │
│                           ││    │  [Complete Sale] ─────────┐ │
│                           ││    │                           │ │
└─────────────────────────────┘    └─────────────────────────────┘
                            │                                  │
                            │                                  │
                            │      CLICK!                      │
                            │                                  │
After sale completes (0.5s)│                                  │
                            ↓                                  ↓
┌─────────────────────────────┐    ┌─────────────────────────────┐
│   DEVICE 1 - OWNER          │    │   DEVICE 2 - STAFF          │
├─────────────────────────────┤    ├─────────────────────────────┤
│                             │    │                             │
│  📦 Inventory               │    │  ✅ Sale completed!         │
│                             │    │                             │
│  ┌─────────────────────┐   │    │  Receipt #SA-123456         │
│  │ 💻 Test Laptop      │   │    │  Total: $1,999.98           │
│  │ SKU: LAP001         │   │    │  Items: 2                   │
│  │ $999.99        [13] │⚡ │    │                             │
│  └─────────────────────┘   │    │  [New Sale]                 │
│         ↑                   │    │                             │
│    DECREASED TO 13!         │    │                             │
│    (was 15, sold 2)         │    │                             │
└─────────────────────────────┘    └─────────────────────────────┘
        ⬆️
   INVENTORY DECREMENTED
   AUTOMATICALLY! 🎯
   15 - 2 = 13
```

**✅ SUCCESS INDICATOR:** Owner sees stock decrease from 15 → 13 instantly!

---

## 🚨 Test 4: Low Stock Alert (Realtime)

### Product crosses reorder threshold

```
BEFORE: Stock = 12, Reorder Level = 10

┌─────────────────────────────┐    ┌─────────────────────────────┐
│   DEVICE 1 - OWNER          │    │   DEVICE 2 - STAFF          │
│   (Inventory Page)          │    │   (Low Stock Page)          │
├─────────────────────────────┤    ├─────────────────────────────┤
│                             │    │                             │
│  ┌─────────────────────┐   │    │  ⚠️  Low Stock              │
│  │ 💻 Test Laptop      │   │    │                             │
│  │ $999.99        [12] │   │    │  ✅ All products well       │
│  └─────────────────────┘   │    │     stocked!                │
│                             │    │                             │
│  [Adjust: -5] ────────────┐ │    │                             │
└─────────────────────────────┘    └─────────────────────────────┘
                             │
                     CLICK! (Remove 5)
                             │
                             ↓
AFTER: Stock = 7, Below Reorder Level!

┌─────────────────────────────┐    ┌─────────────────────────────┐
│   DEVICE 1 - OWNER          │    │   DEVICE 2 - STAFF          │
├─────────────────────────────┤    ├─────────────────────────────┤
│                             │    │                             │
│  ┌─────────────────────┐   │    │  ⚠️  Low Stock              │
│  │ 💻 Test Laptop 🔴   │   │    │                             │
│  │ $999.99         [7] │   │    │  ⚠️  1 Product Low on Stock │
│  └─────────────────────┘   │    │  ────────────────────       │
│     ↑                       │    │                             │
│  Low Stock!                 │    │  ┌──────────────────────┐  │
│                             │    │  │ 💻 Test Laptop 🔴   │⚡ │
│                             │    │  │ SKU: LAP001          │  │
│                             │    │  │                      │  │
│                             │    │  │ Current: 7           │  │
│                             │    │  │ Reorder: 10          │  │
│                             │    │  │ Shortage: 3          │  │
│                             │    │  │ [━━━━━░░░░░] 70%    │  │
│                             │    │  │                      │  │
│                             │    │  │ [Restock]            │  │
│                             │    │  └──────────────────────┘  │
│                             │    │     ↑                       │
│                             │    │  APPEARED                   │
│                             │    │  AUTOMATICALLY! 🚨          │
└─────────────────────────────┘    └─────────────────────────────┘
                                              ⬆️
                                       ALERT TRIGGERED
                                       REALTIME! < 1s
```

**✅ SUCCESS INDICATOR:** Low stock alert appears automatically on Staff device!

---

## 🎬 Perfect Demo Recording

### Camera Setup
```
┌────────────────────────────────────────────────────┐
│                                                    │
│  SCREEN RECORDING (OBS/QuickTime)                 │
│  ────────────────────────────────────              │
│                                                    │
│  ┌──────────────────┐  ┌──────────────────┐      │
│  │  DEVICE 1        │  │  DEVICE 2        │      │
│  │  (Owner)         │  │  (Staff)         │      │
│  │                  │  │                  │      │
│  │  Add Product →   │  │  ← Appears Here  │      │
│  │                  │  │                  │      │
│  │  [+ Add]         │  │  [⚡ New Item!]  │      │
│  └──────────────────┘  └──────────────────┘      │
│                                                    │
│  ⏱️  SHOW TIMESTAMP: < 1 second                   │
│                                                    │
└────────────────────────────────────────────────────┘
```

### Demo Script
1. **Setup (5 sec):**
   - "Two devices, same shop"
   - "Left: Owner, Right: Staff"

2. **Action (3 sec):**
   - "Owner adds product..."
   - [Click Add Product]

3. **Result (2 sec):**
   - "Watch the staff screen..."
   - [Product appears]
   - "There! Instant sync!"

4. **Outro (5 sec):**
   - "No refresh needed"
   - "Real collaboration"
   - "Powered by Supabase"

---

## 🎉 Success Checklist

After testing, verify:

- ✅ Products appear on other devices < 2 seconds
- ✅ Stock updates propagate automatically
- ✅ Low stock alerts trigger for all users
- ✅ Sales decrement inventory everywhere
- ✅ Edits reflect on all devices
- ✅ Deletions remove from all lists
- ✅ No manual refresh needed
- ✅ Search still works during updates
- ✅ RLS permissions enforced correctly

---

**If all tests pass → Your realtime sync is PERFECT! 🚀**

