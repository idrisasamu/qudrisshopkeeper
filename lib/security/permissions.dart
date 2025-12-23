/// Role-based permissions for Qudris ShopKeeper
///
/// Three roles:
/// - Owner: Full control of shop
/// - Manager: Can manage products, inventory, orders, view reports
/// - Cashier: Can create orders, take payments, view products/customers

enum UserRole { owner, manager, cashier }

/// Parse role from string
UserRole? parseRole(String? roleString) {
  if (roleString == null) return null;

  switch (roleString.toLowerCase()) {
    case 'owner':
      return UserRole.owner;
    case 'manager':
      return UserRole.manager;
    case 'cashier':
      return UserRole.cashier;
    default:
      return null;
  }
}

/// Convert role to string
String roleToString(UserRole role) {
  switch (role) {
    case UserRole.owner:
      return 'owner';
    case UserRole.manager:
      return 'manager';
    case UserRole.cashier:
      return 'cashier';
  }
}

/// Get display name for role
String getRoleDisplayName(UserRole role) {
  switch (role) {
    case UserRole.owner:
      return 'Owner';
    case UserRole.manager:
      return 'Manager';
    case UserRole.cashier:
      return 'Cashier';
  }
}

/// Permissions checker
class Permissions {
  final UserRole? role;

  Permissions(this.role);

  bool get isOwner => role == UserRole.owner;
  bool get isManager => role == UserRole.manager || isOwner;
  bool get isCashier => role != null; // All roles can do cashier tasks

  // ================================================
  // SHOP MANAGEMENT
  // ================================================

  bool get canEditShop => isOwner;
  bool get canDeleteShop => isOwner;
  bool get canViewShopSettings => isOwner;

  // ================================================
  // STAFF MANAGEMENT
  // ================================================

  bool get canViewStaff => isManager;
  bool get canInviteStaff => isOwner;
  bool get canRemoveStaff => isOwner;
  bool get canEditStaffRoles => isOwner;

  // ================================================
  // PRODUCT CATALOG
  // ================================================

  bool get canViewProducts => isCashier;
  bool get canCreateProducts => isManager;
  bool get canEditProducts => isManager;
  bool get canDeleteProducts => isOwner;
  bool get canManageCategories => isManager;

  // ================================================
  // INVENTORY
  // ================================================

  bool get canViewInventory => isCashier;
  bool get canAdjustInventory => isManager;
  bool get canViewStockMovements => isManager;
  bool get canCreateStockMovements => isManager;

  // ================================================
  // CUSTOMERS
  // ================================================

  bool get canViewCustomers => isCashier;
  bool get canCreateCustomers => isCashier;
  bool get canEditCustomers => isCashier;
  bool get canDeleteCustomers => isManager;

  // ================================================
  // ORDERS & POS
  // ================================================

  bool get canViewOrders => isCashier;
  bool get canCreateOrders => isCashier;
  bool get canEditOrders => isCashier;
  bool get canDeleteOrders => isManager;
  bool get canRefundOrders => isManager;
  bool get canVoidOrders => isManager;

  // ================================================
  // PAYMENTS
  // ================================================

  bool get canViewPayments => isCashier;
  bool get canCreatePayments => isCashier;
  bool get canEditPayments => isManager;
  bool get canDeletePayments => isOwner;

  // ================================================
  // REPORTS & ANALYTICS
  // ================================================

  bool get canViewReports => isManager;
  bool get canViewSalesReports => isManager;
  bool get canViewInventoryReports => isManager;
  bool get canViewFinancialReports => isOwner;
  bool get canExportData => isManager;

  // ================================================
  // SETTINGS
  // ================================================

  bool get canEditSettings => isOwner;
  bool get canManageIntegrations => isOwner;
  bool get canViewAuditLogs => isOwner;

  // ================================================
  // HELPER METHODS
  // ================================================

  /// Check if user has minimum role level
  bool hasMinimumRole(UserRole minimumRole) {
    if (role == null) return false;

    switch (minimumRole) {
      case UserRole.owner:
        return isOwner;
      case UserRole.manager:
        return isManager;
      case UserRole.cashier:
        return isCashier;
    }
  }

  /// Check if user can perform action
  bool can(String action) {
    switch (action) {
      // Shop
      case 'shop.edit':
        return canEditShop;
      case 'shop.delete':
        return canDeleteShop;

      // Staff
      case 'staff.view':
        return canViewStaff;
      case 'staff.invite':
        return canInviteStaff;
      case 'staff.remove':
        return canRemoveStaff;

      // Products
      case 'products.view':
        return canViewProducts;
      case 'products.create':
        return canCreateProducts;
      case 'products.edit':
        return canEditProducts;
      case 'products.delete':
        return canDeleteProducts;

      // Inventory
      case 'inventory.view':
        return canViewInventory;
      case 'inventory.adjust':
        return canAdjustInventory;

      // Orders
      case 'orders.view':
        return canViewOrders;
      case 'orders.create':
        return canCreateOrders;
      case 'orders.edit':
        return canEditOrders;
      case 'orders.delete':
        return canDeleteOrders;
      case 'orders.refund':
        return canRefundOrders;

      // Reports
      case 'reports.view':
        return canViewReports;
      case 'reports.export':
        return canExportData;

      default:
        return false;
    }
  }

  /// Get all permissions as a map
  Map<String, bool> toMap() {
    return {
      'shop.edit': canEditShop,
      'shop.delete': canDeleteShop,
      'staff.view': canViewStaff,
      'staff.invite': canInviteStaff,
      'staff.remove': canRemoveStaff,
      'products.view': canViewProducts,
      'products.create': canCreateProducts,
      'products.edit': canEditProducts,
      'products.delete': canDeleteProducts,
      'inventory.view': canViewInventory,
      'inventory.adjust': canAdjustInventory,
      'orders.view': canViewOrders,
      'orders.create': canCreateOrders,
      'orders.edit': canEditOrders,
      'orders.delete': canDeleteOrders,
      'orders.refund': canRefundOrders,
      'reports.view': canViewReports,
      'reports.export': canExportData,
    };
  }
}

/// Feature gate widget helper
/// Usage: if (FeatureGate.can('products.edit', role)) { ... }
class FeatureGate {
  static bool can(String action, String? roleString) {
    final role = parseRole(roleString);
    final permissions = Permissions(role);
    return permissions.can(action);
  }

  static bool hasMinimumRole(UserRole minimumRole, String? roleString) {
    final role = parseRole(roleString);
    final permissions = Permissions(role);
    return permissions.hasMinimumRole(minimumRole);
  }
}
