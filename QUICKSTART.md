# Qudris ShopKeeper - Supabase Migration Quickstart

**Complete refactoring to Supabase backend with offline-first sync!**

## 🎯 What's New

Your app now has:
- ✅ **Cloud Sync**: Automatic sync across all devices
- ✅ **Multi-user**: Owner/Manager/Cashier roles with permissions
- ✅ **Cloud Storage**: Product images and receipts in the cloud
- ✅ **Offline-First**: Works without internet, syncs when connected
- ✅ **Modern Auth**: Email, Google OAuth, Magic Links
- ✅ **Secure**: Row-Level Security on all data

## ⚡ Quick Start (5 Minutes)

### 1. Create Supabase Project

```bash
# 1. Go to https://supabase.com
# 2. Click "New Project"
# 3. Name: "Qudris ShopKeeper"
# 4. Save your database password!
```

### 2. Run SQL Migrations

```sql
-- In Supabase SQL Editor, paste and run:
-- File: supabase/migrations/001_initial_schema.sql
-- Then: supabase/migrations/002_storage_setup.sql
```

### 3. Deploy Edge Functions

```bash
npm install -g supabase
supabase login
supabase link --project-ref YOUR_PROJECT_REF
supabase functions deploy sync
supabase functions deploy sign-url
```

### 4. Configure App

Update `lib/config/env.dart`:

```dart
static const String supabaseUrl = 'https://YOUR_PROJECT.supabase.co';
static const String supabaseAnonKey = 'YOUR_ANON_KEY';
```

### 5. Install & Run

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run
```

**That's it! Your app is now connected to Supabase.**

---

## 📂 What Was Generated

### Supabase (Backend)

```
supabase/
├── migrations/
│   ├── 001_initial_schema.sql          # All tables, RLS, triggers
│   └── 002_storage_setup.sql           # Storage buckets & policies
└── functions/
    ├── sync/index.ts                   # Bi-directional sync
    └── sign-url/index.ts               # Signed URL generation
```

**Tables Created** (with RLS):
- `profiles` - User profiles
- `shops` - Shop/store entities
- `staff` - User-shop membership with roles
- `products`, `categories` - Product catalog
- `inventory`, `stock_movements` - Inventory tracking
- `customers` - Customer records
- `orders`, `order_items`, `payments` - Sales/POS
- `devices`, `sync_states` - Sync infrastructure
- `audit_logs` - Audit trail

**Storage Buckets**:
- `product_images` (public)
- `receipts` (private)
- `exports` (private, time-limited)

### Flutter App (Client)

```
lib/
├── services/
│   ├── supabase_client.dart            # Singleton client
│   ├── auth_service.dart               # Email, Google, Magic Link
│   ├── profile_service.dart            # User profiles
│   ├── shop_service.dart               # Shop management + invites
│   ├── sync_service.dart               # Offline-first sync engine
│   ├── storage_service.dart            # File uploads/downloads
│   └── migration_service.dart          # Google Drive → Supabase
│
├── data/local/
│   └── database.dart                   # Drift offline DB (8 tables)
│
├── features/
│   ├── auth/                           # SignIn, Register, MagicLink
│   └── migration/                      # Migration UI
│
├── providers/
│   └── auth_provider.dart              # Riverpod auth state
│
├── security/
│   └── permissions.dart                # Role-based access control
│
└── config/
    └── env.dart                        # Environment config
```

### Documentation

- `SUPABASE_ARCHITECTURE.md` - System design & architecture
- `SUPABASE_SETUP_README.md` - Complete setup guide
- `PLATFORM_SETUP.md` - Android/iOS deep link config
- `QUICKSTART.md` - This file!

### Tests & CI

- `test/auth_test.dart` - Permission tests
- `.github/workflows/ci.yml` - GitHub Actions CI

---

## 🔑 Key Features

### Authentication

```dart
// Email/Password
await authService.signInWithEmail(email: '...', password: '...');

// Google OAuth
await authService.signInWithGoogle();

// Magic Link
await authService.signInWithMagicLink(email: '...');
```

### Role-Based Permissions

```dart
// Check permissions
final perms = Permissions(userRole);
if (perms.canEditProducts) {
  // Show edit button
}

// Feature gates
if (FeatureGate.can('products.create', roleString)) {
  // Allow creation
}
```

### Offline-First Sync

```dart
// Automatic sync on app start & connectivity changes
await syncService.sync(shopId: activeShopId);

// Listen to sync status
syncService.statusStream.listen((status) {
  // SyncStatus.idle, syncing, success, error
});
```

### Cloud Storage

```dart
// Upload product image
final path = await storageService.uploadProductImage(
  shopId: shopId,
  productId: productId,
  imageFile: imageFile,
);

// Get public URL
final url = storageService.getProductImageUrl(path);
```

### Migration

```dart
// One-time migration from Google Drive
final result = await migrationService.migrate(
  shopId: shopId,
  userId: userId,
  onProgress: (step) => print(step),
);
```

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────┐
│         Flutter App (Offline)           │
│  ┌─────────────────────────────────┐   │
│  │   Drift Local DB (SQLite)       │   │
│  │   - Products, Orders, Inventory │   │
│  │   - Source of truth offline     │   │
│  └────────────┬────────────────────┘   │
│               │ Sync Service            │
└───────────────┼─────────────────────────┘
                │ (Delta sync, conflicts)
                ▼
┌───────────────────────────────────────────┐
│           Supabase Cloud                  │
│  ┌─────────────────────────────────────┐ │
│  │  Auth (Google, Email, Magic Link)   │ │
│  └─────────────────────────────────────┘ │
│  ┌─────────────────────────────────────┐ │
│  │  PostgreSQL (RLS enforced)          │ │
│  │  - Multi-tenant by shop_id          │ │
│  └─────────────────────────────────────┘ │
│  ┌─────────────────────────────────────┐ │
│  │  Storage (Images, Receipts)         │ │
│  └─────────────────────────────────────┘ │
│  ┌─────────────────────────────────────┐ │
│  │  Edge Functions (Sync, Sign URLs)   │ │
│  └─────────────────────────────────────┘ │
└───────────────────────────────────────────┘
```

**Sync Strategy**:
- **Pull**: Server → Client (delta based on `last_modified`)
- **Push**: Client → Server (dirty rows only)
- **Conflicts**: Newest-wins at row level
- **Tombstones**: Soft deletes via `deleted_at`

---

## 🚀 Next Steps

### Immediate

1. **Test Auth**: Sign up, sign in, magic link
2. **Create Shop**: Onboard your first shop
3. **Migrate Data**: Run one-time migration
4. **Invite Staff**: Generate invite codes
5. **Test Sync**: Make changes on two devices

### Short-term

1. **Configure Google OAuth**: Add client ID/secret
2. **Customize Branding**: Update theme, logo
3. **Test Offline Mode**: Airplane mode + sync
4. **Review RLS Policies**: Ensure security
5. **Set Up Monitoring**: Supabase dashboard

### Long-term

1. **Production Deployment**: Separate prod project
2. **App Store Submission**: iOS + Android
3. **Advanced Features**: Real-time, webhooks
4. **Analytics Integration**: Track metrics
5. **Multi-shop Support**: Users in multiple shops

---

## 📖 Full Documentation

- **Architecture**: [SUPABASE_ARCHITECTURE.md](SUPABASE_ARCHITECTURE.md)
- **Setup Guide**: [SUPABASE_SETUP_README.md](SUPABASE_SETUP_README.md)
- **Platform Config**: [PLATFORM_SETUP.md](PLATFORM_SETUP.md)

---

## 🛠️ Troubleshooting

### "Supabase not initialized"

```dart
// Add to main.dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService.initialize(
    url: Env.supabaseUrl,
    anonKey: Env.supabaseAnonKey,
  );
  runApp(MyApp());
}
```

### Sync Not Working

```bash
# Check Edge Function logs
supabase functions logs sync

# Check network
# Check auth token
# Verify RLS policies
```

### Build Errors

```bash
flutter clean
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

---

## 🎉 You're All Set!

Your app is now:
- ✅ Cloud-powered with Supabase
- ✅ Offline-first with Drift
- ✅ Multi-user with roles
- ✅ Secure with RLS
- ✅ Ready for production

**Happy coding!** 🚀

---

**Questions?** Check the docs or reach out!

