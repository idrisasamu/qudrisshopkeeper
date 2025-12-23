# Qudris ShopKeeper - Supabase Setup Guide

This guide walks you through setting up Qudris ShopKeeper with Supabase for cloud sync, authentication, and storage.

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Supabase Project Setup](#supabase-project-setup)
- [Local Development Setup](#local-development-setup)
- [Running the App](#running-the-app)
- [Migration from Google Drive](#migration-from-google-drive)
- [Troubleshooting](#troubleshooting)
- [Next Steps](#next-steps)

---

## Overview

Qudris ShopKeeper now uses Supabase as its backend, providing:

- **Authentication**: Email/password, Google OAuth, Magic Links
- **Database**: PostgreSQL with Row-Level Security (RLS)
- **Storage**: Cloud storage for images and exports
- **Edge Functions**: Custom serverless functions for sync logic
- **Offline-First**: Local Drift database syncs with Supabase

### Architecture Highlights

```
Flutter App (Offline-First)
  ↓
Local Drift Database (Source of Truth)
  ↕ (Bi-directional Sync)
Supabase Cloud
  ├─ Auth (Google, Email, Magic Link)
  ├─ PostgreSQL (with RLS)
  ├─ Storage (Images, Receipts, Exports)
  └─ Edge Functions (Sync, Sign URLs)
```

---

## Prerequisites

1. **Flutter SDK**: 3.27.0 or higher
2. **Dart SDK**: 3.9.0 or higher
3. **Supabase Account**: Sign up at [supabase.com](https://supabase.com)
4. **Git**: For version control
5. **IDE**: VS Code or Android Studio with Flutter plugins

---

## Supabase Project Setup

### Step 1: Create a Supabase Project

1. Go to [app.supabase.com](https://app.supabase.com)
2. Click **New Project**
3. Fill in:
   - **Name**: `Qudris ShopKeeper`
   - **Database Password**: (save this securely)
   - **Region**: Choose closest to your users
4. Click **Create new project**

### Step 2: Run Database Migrations

1. In your Supabase project, go to **SQL Editor**
2. Open `supabase/migrations/001_initial_schema.sql` from this repo
3. Copy the entire contents and paste into the SQL editor
4. Click **Run** to execute
5. Verify: Go to **Table Editor** and confirm tables are created

6. Repeat for `supabase/migrations/002_storage_setup.sql`

### Step 3: Deploy Edge Functions

Install Supabase CLI:

```bash
npm install -g supabase
```

Login to Supabase:

```bash
supabase login
```

Link your project:

```bash
supabase link --project-ref YOUR_PROJECT_REF
```

Deploy functions:

```bash
supabase functions deploy sync
supabase functions deploy sign-url
```

### Step 4: Configure Authentication

#### Enable Email Authentication

1. Go to **Authentication** → **Providers**
2. **Email** should be enabled by default
3. Configure email templates (optional)

#### Enable Google OAuth

1. Go to **Authentication** → **Providers** → **Google**
2. Toggle **Enable Google provider**
3. You'll need:
   - **Client ID** from [Google Cloud Console](https://console.cloud.google.com)
   - **Client Secret** from Google Cloud Console

**Setting up Google OAuth:**

1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Create a new project or select existing
3. Enable **Google+ API**
4. Go to **Credentials** → **Create Credentials** → **OAuth 2.0 Client ID**
5. Configure consent screen
6. Create credentials for:
   - **Android** (requires SHA-1 fingerprint)
   - **iOS** (requires Bundle ID)
7. Add authorized redirect URIs:
   - `https://YOUR_PROJECT_REF.supabase.co/auth/v1/callback`

#### Configure Redirect URLs

1. Go to **Authentication** → **URL Configuration**
2. Add these to **Redirect URLs**:
   - `qudrisshopkeeper://auth/callback` (mobile)
   - `http://localhost:3000/auth/callback` (web dev)

### Step 5: Get API Keys

1. Go to **Settings** → **API**
2. Copy:
   - **Project URL** (e.g., `https://abcdefgh.supabase.co`)
   - **anon public** key

---

## Local Development Setup

### Step 1: Clone and Install Dependencies

```bash
cd qudris_shopkeeper
flutter pub get
```

### Step 2: Configure Environment

Create a file `lib/config/env.dart` and update with your values:

```dart
class Env {
  static const String supabaseUrl = 'https://YOUR_PROJECT_REF.supabase.co';
  static const String supabaseAnonKey = 'YOUR_ANON_KEY_HERE';
  static const String deepLinkScheme = 'qudrisshopkeeper';
  
  // ... rest of the file
}
```

**IMPORTANT**: Do NOT commit real keys to version control!

### Step 3: Platform-Specific Configuration

Follow the [PLATFORM_SETUP.md](PLATFORM_SETUP.md) guide to configure:

- Android deep links
- iOS URL schemes
- OAuth redirect URIs

### Step 4: Generate Code

Run code generation for Drift and JSON serialization:

```bash
dart run build_runner build --delete-conflicting-outputs
```

### Step 5: Verify Setup

Run the app:

```bash
flutter run
```

---

## Running the App

### Development

```bash
# Run on connected device/emulator
flutter run

# Run with environment variables
flutter run \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-key

# Hot reload is enabled - just save files to update
```

### Build for Release

#### Android

```bash
flutter build apk --release
# or
flutter build appbundle --release
```

#### iOS

```bash
flutter build ios --release
# Then open in Xcode for signing
```

---

## Migration from Google Drive

### Automatic Migration (Recommended)

1. **Sign in** to the app
2. You'll be prompted: "Migrate your data to Supabase?"
3. Click **Start Migration**
4. Wait for completion (progress shown)
5. Migration summary displays items migrated

### What Gets Migrated

- ✅ Product categories
- ✅ Products with pricing
- ✅ Product images (uploaded to Storage)
- ✅ Inventory levels
- ✅ Customers
- ✅ Orders and order items
- ✅ Payments
- ✅ Receipt images (uploaded to Storage)

### Manual Migration (If Needed)

If automatic migration fails, use the Migration page:

```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => MigrationPage(
      shopId: activeShopId,
      userId: currentUserId,
    ),
  ),
);
```

---

## Troubleshooting

### Common Issues

#### 1. "Supabase not initialized" error

**Solution**: Ensure `SupabaseService.initialize()` is called in `main()`:

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await SupabaseService.initialize(
    url: Env.supabaseUrl,
    anonKey: Env.supabaseAnonKey,
  );
  
  runApp(MyApp());
}
```

#### 2. Auth callback not working

**Possible causes**:
- Deep link not configured correctly
- Redirect URLs not set in Supabase dashboard
- URL scheme mismatch

**Solution**: Check [PLATFORM_SETUP.md](PLATFORM_SETUP.md) and verify:
- Android: `AndroidManifest.xml` intent filter
- iOS: `Info.plist` URL types
- Supabase: Redirect URLs in dashboard

#### 3. Sync not working

**Check**:
- Device has internet connection
- User is authenticated
- Edge functions deployed correctly
- RLS policies allow user access

**Debug**:
```bash
# Check Edge Function logs
supabase functions logs sync

# Check database logs in Supabase dashboard
```

#### 4. RLS Policy Denial

**Error**: "new row violates row-level security policy"

**Solution**:
- User must be a staff member of the shop
- Check `staff` table for user's membership
- Verify user has correct role (owner/manager/cashier)

#### 5. Build Errors After Pub Get

**Solution**: Run code generation:
```bash
flutter clean
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

### Getting Help

- **Documentation**: See [SUPABASE_ARCHITECTURE.md](SUPABASE_ARCHITECTURE.md)
- **Platform Setup**: See [PLATFORM_SETUP.md](PLATFORM_SETUP.md)
- **Supabase Docs**: [supabase.com/docs](https://supabase.com/docs)
- **Flutter Docs**: [docs.flutter.dev](https://docs.flutter.dev)

---

## Project Structure

```
qudris_shopkeeper/
├── lib/
│   ├── app/                    # App-level config (routes, theme)
│   ├── config/                 # Environment config
│   ├── data/
│   │   └── local/              # Drift local database
│   ├── features/
│   │   ├── auth/               # Authentication screens
│   │   ├── migration/          # Migration UI
│   │   ├── dashboard/          # Main dashboard
│   │   ├── inventory/          # Inventory management
│   │   └── sales/              # POS & sales
│   ├── providers/              # Riverpod providers
│   ├── security/               # Permissions & access control
│   └── services/
│       ├── auth_service.dart
│       ├── supabase_client.dart
│       ├── sync_service.dart
│       ├── storage_service.dart
│       ├── shop_service.dart
│       └── migration_service.dart
├── supabase/
│   ├── functions/              # Edge Functions
│   │   ├── sync/
│   │   └── sign-url/
│   └── migrations/             # SQL migrations
├── test/                       # Unit & widget tests
└── pubspec.yaml
```

---

## Development Workflow

### 1. Make Changes

Edit Dart files as needed. Hot reload works for most changes.

### 2. Add Database Changes

If you modify Drift tables:

```bash
dart run build_runner build --delete-conflicting-outputs
```

### 3. Test Locally

```bash
flutter test
```

### 4. Lint & Format

```bash
dart format .
flutter analyze
```

### 5. Commit

```bash
git add .
git commit -m "feat: add new feature"
git push
```

### 6. Deploy Edge Functions

After updating Edge Functions:

```bash
supabase functions deploy sync
```

---

## CI/CD

GitHub Actions workflow is configured in `.github/workflows/ci.yml`:

- **On Push/PR**: Runs analyze, tests, builds Android & iOS
- **Coverage**: Uploads to Codecov
- **Artifacts**: APK and iOS builds available

---

## Security Best Practices

1. **Never commit secrets**: Use environment variables
2. **Enable RLS**: All tables have Row-Level Security
3. **Validate input**: Client and server-side validation
4. **Use HTTPS**: Always in production
5. **Rotate keys**: Regularly update API keys
6. **Audit logs**: Track all critical actions

---

## Performance Tips

1. **Sync throttling**: Max once per 30 seconds
2. **Batch operations**: Sync uses batch upserts
3. **Indexes**: All sync tables indexed on `last_modified`
4. **Offline-first**: App works without internet
5. **Image optimization**: Compress images before upload

---

## Next Steps

### For Development

- [ ] Implement remaining CRUD screens
- [ ] Add real-time sync (optional)
- [ ] Implement push notifications
- [ ] Add analytics/reporting
- [ ] Multi-shop support

### For Production

- [ ] Configure production Supabase project
- [ ] Set up custom domain
- [ ] Enable backups
- [ ] Configure monitoring/alerting
- [ ] Submit to App Store / Play Store

### Advanced Features

- [ ] Webhook integrations
- [ ] BigQuery export for analytics
- [ ] Multi-currency support
- [ ] Advanced inventory forecasting
- [ ] Loyalty program integration

---

## Resources

### Documentation
- [Supabase Architecture](SUPABASE_ARCHITECTURE.md)
- [Platform Setup](PLATFORM_SETUP.md)

### External Links
- [Supabase Documentation](https://supabase.com/docs)
- [Flutter Documentation](https://docs.flutter.dev)
- [Drift Documentation](https://drift.simonbinder.eu)
- [Riverpod Documentation](https://riverpod.dev)

### Support
- GitHub Issues: [Create an issue](#)
- Supabase Discord: [discord.supabase.com](https://discord.supabase.com)
- Flutter Discord: [discord.gg/flutter](https://discord.gg/flutter)

---

## License

This project is proprietary. All rights reserved.

---

**Last Updated**: October 8, 2025  
**Version**: 1.0.0

