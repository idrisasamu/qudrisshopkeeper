# 📦 What is SKU?

## Definition

**SKU** = **S**tock **K**eeping **U**nit

It's a **unique identifier code** you create for each product in your inventory to help track and organize it.

---

## 🏷️ Real-World Examples

| Product | SKU Example | Meaning |
|---------|-------------|---------|
| Red T-Shirt (Medium) | `TSHIRT-RED-M` | T-Shirt, Red color, Medium size |
| Laptop Dell XPS 15 | `DELL-XPS15-512` | Dell brand, XPS 15 model, 512GB storage |
| Coca-Cola 500ml | `COKE-500ML` | Coke product, 500ml size |
| iPhone 15 Pro Max | `IPHONE-15PM-256-BLK` | iPhone 15 Pro Max, 256GB, Black |
| Pen (Blue) | `PEN-BLUE-001` | Pen, Blue ink, variant 001 |

---

## 🎯 Why Use SKU?

### 1. **Easy Identification**
- Quickly find products
- Avoid confusion with similar items
- Track variants (sizes, colors)

### 2. **Inventory Management**
- Track stock levels per SKU
- Reorder specific variants
- Audit trail

### 3. **Barcode Alternative**
- Use when product doesn't have a barcode
- Create your own system
- Works offline

### 4. **Reporting**
- "SKU PEN-BLUE-001 sold 50 units this week"
- Better than "Pen sold 50 units" (which pen?)

---

## 📝 SKU vs Barcode

| Feature | SKU | Barcode |
|---------|-----|---------|
| **Who creates it?** | You (store owner) | Manufacturer |
| **Format** | Any text (flexible) | Numbers only |
| **Scanning** | Type manually | Scan with scanner |
| **Uniqueness** | Unique in YOUR store | Unique globally |
| **Best for** | Custom tracking | Fast checkout |

---

## ✅ In Your App

### SKU Field (Optional)
When adding a product, you can:

**Option 1**: Leave it blank
```
Product Name: Pen
SKU: [empty]  ← Skip it
Price: $2.50
```

**Option 2**: Create your own code
```
Product Name: Pen (Blue)
SKU: PEN-BLUE-001  ← Your unique code
Price: $2.50
```

**Option 3**: Use barcode as SKU
```
Product Name: Coca-Cola
SKU: 1234567890  ← Same as barcode
Barcode: 1234567890
Price: $1.50
```

---

## 💡 Best Practices

### Good SKU Examples:
- ✅ `LAPTOP-DELL-XPS15` - Clear, descriptive
- ✅ `TSHIRT-RED-M` - Includes variant
- ✅ `COKE-500ML` - Includes size
- ✅ `PEN-001` - Sequential numbering

### Bad SKU Examples:
- ❌ `1` - Too short, not descriptive
- ❌ `asdfghjkl` - Random, meaningless
- ❌ `THE-BEST-LAPTOP-IN-THE-WORLD-DELL-XPS-15-512GB-BLACK` - Too long

### Tips:
1. Keep it short (5-15 characters)
2. Use dashes or underscores for readability
3. Include key info (brand, size, color)
4. Use sequential numbers for similar items
5. Make it memorable

---

## 🎯 Do You NEED SKU?

**NO!** SKU is **optional** in your app.

### When to Skip SKU:
- Small store with few products
- All products have barcodes
- You prefer searching by name

### When to Use SKU:
- Large inventory (100+ products)
- Products have variants (sizes, colors)
- No barcodes available
- Want better reporting

---

## 🔍 In Your Inventory System

### How SKU Works:

1. **Adding Product** (SKU optional):
   ```
   Product Name: Pen      ← Required
   SKU: PEN-001          ← Optional (you can leave blank!)
   Barcode: [empty]      ← Optional
   ```

2. **Searching Products**:
   - Search by name: "Pen" ✅
   - Search by SKU: "PEN-001" ✅
   - Search by barcode: works too ✅

3. **Display**:
   ```
   Pen
   SKU: PEN-001         ← Shows if you entered one
   $2.50            [50] ← Stock quantity
   ```

---

## ✅ Summary

**SKU** = Your own product code/ID

- ✅ **Optional** - you don't have to use it
- ✅ **Flexible** - create any format you want
- ✅ **Helpful** - for organizing large inventories
- ✅ **Alternative** - to barcodes when not available

**For your store**: If you only have a few products, you can **skip SKU** and just use product names!

---

**Example for your case**:
```
Product Name: Pen       ← Everyone understands this
SKU: [leave blank]      ← Skip it if you want!
Price: $2.50
Quantity: 500
```

Or if you want to organize:
```
Product Name: Pen (Blue)
SKU: PEN-BLUE          ← Makes it easier to find
Price: $2.50
Quantity: 500

Product Name: Pen (Black)
SKU: PEN-BLACK         ← Different from blue pen
Price: $2.50
Quantity: 300
```

---

**Bottom line**: SKU helps you organize, but it's **totally optional**! 🎉

