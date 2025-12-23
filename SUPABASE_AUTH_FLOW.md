# Supabase Authentication & Role Management

## Overview
The app now uses a streamlined Supabase-first authentication flow that eliminates the need for the "Continue As" page and Google Drive sync. User roles are automatically determined from the `staff` table in Supabase.

## Changes Made

### 1. **Removed Routes**
- ❌ `/continue-as` - No longer needed
- ❌ `/auth/admin-login` - Replaced by Supabase auth
- ❌ `/auth/staff-login` - Replaced by Supabase auth

### 2. **New Authentication Flow**

#### Before (Old Flow)
```
Sign in → Select Shop → Continue As (Admin/Staff) → Login Again → Dashboard
```

#### After (New Supabase Flow)
```
Sign in with Supabase → Select Shop → Dashboard (auto-routed by role)
```

### 3. **Role Auto-Detection**

When a user selects a shop, the app:
1. Queries the `staff` table for the user's role in that shop
2. Saves role to session
3. Routes directly to the appropriate dashboard:
   - `owner` or `manager` → `/admin` (AdminDashboardPage)
   - `cashier` → `/staff` (StaffHomePage)

### 4. **Database Trigger**

Added trigger to auto-add shop creators as owners:

```sql
-- File: supabase/migrations/003_auto_add_shop_owner.sql
CREATE OR REPLACE FUNCTION public.auto_add_shop_owner()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.staff (shop_id, user_id, role, is_active, ...)
  VALUES (NEW.id, NEW.created_by, 'owner', true, ...)
  ON CONFLICT DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

### 5. **Switch Role → Switch Shop**

The "Switch Role" button has been renamed to "Switch Shop" and now:
- Clears current shop and role data
- Closes the database
- Navigates back to `/onboarding` (shop selection)
- User's role is re-determined from Supabase when they select a shop

### 6. **New Riverpod Providers**

Created clean state management providers:

```dart
// Active shop ID
final activeShopIdProvider = StateProvider<String?>((ref) => null);

// Current user's role
final currentRoleProvider = FutureProvider<String?>((ref) async {
  // Fetches role from Supabase staff table
});

// Permission helpers
final permissionsProvider = Provider<Permissions?>((ref) {
  // Returns permission helpers based on role
});
```

### 7. **Permission System**

```dart
// Usage example
final permissions = ref.watch(permissionsProvider);

if (permissions?.canEditCatalog == true) {
  // Show "Add Product" button
}

if (permissions?.canManageStaff == true) {
  // Show "Manage Staff" button
}
```

## How to Use

### For Shop Selection
```dart
final shopService = ref.read(shopServiceProvider);
final shops = await shopService.getUserShops();

// Select a shop
await _selectShop(StaffMembership membership) {
  // Save to session
  await sessionManager.setString('shop_id', membership.shopId);
  await sessionManager.setString('role', membership.role);
  
  // Open database
  await dbHolder.openForShop(membership.shopId);
  
  // Navigate based on role
  if (membership.isOwner || membership.isManager) {
    context.go('/admin');
  } else {
    context.go('/staff');
  }
}
```

### For Permission Checks in UI
```dart
class InventoryPage extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permissions = ref.watch(permissionsProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory'),
        actions: [
          if (permissions?.canEditCatalog == true)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => _addProduct(),
            ),
        ],
      ),
      // ...
    );
  }
}
```

### For Shop Switching
```dart
// In Settings/Sync page
ElevatedButton.icon(
  onPressed: () async {
    await sessionManager.removeMany(['role', 'shop_id', 'shop_name']);
    await dbHolder.close();
    ref.invalidate(itemsWithStockProvider);
    context.go('/onboarding');
  },
  icon: const Icon(Icons.storefront),
  label: const Text('Switch Shop'),
)
```

## Database Setup

Run the migration in Supabase SQL Editor:

```bash
# Apply the migration
psql -h <your-supabase-db-host> -U postgres < supabase/migrations/003_auto_add_shop_owner.sql
```

Or use Supabase CLI:
```bash
supabase db push
```

## Benefits

1. ✅ **Simpler Flow** - One less screen to navigate
2. ✅ **Single Sign-In** - No need to re-authenticate after selecting role
3. ✅ **Automatic Role Management** - Roles are determined from Supabase
4. ✅ **Better Security** - Role checks happen server-side with RLS
5. ✅ **Cleaner Code** - Removed Google Drive sync dependencies
6. ✅ **Multi-Shop Support** - Easy to switch between shops

## Migration Checklist

- [x] Added database trigger for auto-adding owners
- [x] Removed `/continue-as` route
- [x] Updated shop selection to auto-route by role
- [x] Changed "Switch Role" to "Switch Shop"
- [x] Created Riverpod providers for state management
- [x] Updated router to skip auth pages
- [x] Removed Google Drive sync from shop selection
- [ ] Run database migration in Supabase
- [ ] Test multi-shop flow
- [ ] Test permission system in UI

## Next Steps

1. **Run the database migration** in your Supabase project
2. **Test the new flow** by signing in and selecting a shop
3. **Update existing shops** - ensure all shop owners have entries in the `staff` table
4. **Remove unused files** - can delete old `ContinueAsPage`, `LoginAdminPage`, `LoginStaffPage` if no longer needed
5. **Update UI components** to use the new `permissionsProvider`

## Support

If you encounter any issues:
1. Check that the database trigger is installed
2. Verify RLS policies are active on the `staff` table
3. Ensure users have entries in the `staff` table for their shops

