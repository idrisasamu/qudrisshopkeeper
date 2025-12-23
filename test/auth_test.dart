import 'package:flutter_test/flutter_test.dart';
import 'package:qudris_shopkeeper/security/permissions.dart';

void main() {
  group('Permissions Tests', () {
    test('Owner has all permissions', () {
      final perms = Permissions(UserRole.owner);

      expect(perms.isOwner, true);
      expect(perms.isManager, true);
      expect(perms.canEditShop, true);
      expect(perms.canInviteStaff, true);
      expect(perms.canEditProducts, true);
      expect(perms.canDeleteProducts, true);
      expect(perms.canViewReports, true);
      expect(perms.canExportData, true);
    });

    test('Manager has limited permissions', () {
      final perms = Permissions(UserRole.manager);

      expect(perms.isOwner, false);
      expect(perms.isManager, true);
      expect(perms.canEditShop, false); // Only owners
      expect(perms.canInviteStaff, false); // Only owners
      expect(perms.canEditProducts, true);
      expect(perms.canDeleteProducts, false); // Only owners
      expect(perms.canViewReports, true);
      expect(perms.canExportData, true);
    });

    test('Cashier has minimal permissions', () {
      final perms = Permissions(UserRole.cashier);

      expect(perms.isOwner, false);
      expect(perms.isManager, false);
      expect(perms.isCashier, true);
      expect(perms.canViewProducts, true);
      expect(perms.canCreateProducts, false);
      expect(perms.canEditProducts, false);
      expect(perms.canCreateOrders, true);
      expect(perms.canCreatePayments, true);
      expect(perms.canViewReports, false);
      expect(perms.canDeleteOrders, false);
    });

    test('parseRole correctly parses role strings', () {
      expect(parseRole('owner'), UserRole.owner);
      expect(parseRole('manager'), UserRole.manager);
      expect(parseRole('cashier'), UserRole.cashier);
      expect(parseRole('invalid'), null);
      expect(parseRole(null), null);
    });

    test('roleToString correctly converts roles', () {
      expect(roleToString(UserRole.owner), 'owner');
      expect(roleToString(UserRole.manager), 'manager');
      expect(roleToString(UserRole.cashier), 'cashier');
    });

    test('FeatureGate.can works correctly', () {
      expect(FeatureGate.can('products.create', 'owner'), true);
      expect(FeatureGate.can('products.create', 'manager'), true);
      expect(FeatureGate.can('products.create', 'cashier'), false);

      expect(FeatureGate.can('shop.edit', 'owner'), true);
      expect(FeatureGate.can('shop.edit', 'manager'), false);
      expect(FeatureGate.can('shop.edit', 'cashier'), false);
    });
  });

  group('Role Hierarchy Tests', () {
    test('Owner has minimum role of any level', () {
      final perms = Permissions(UserRole.owner);

      expect(perms.hasMinimumRole(UserRole.owner), true);
      expect(perms.hasMinimumRole(UserRole.manager), true);
      expect(perms.hasMinimumRole(UserRole.cashier), true);
    });

    test('Manager has minimum role for manager and cashier', () {
      final perms = Permissions(UserRole.manager);

      expect(perms.hasMinimumRole(UserRole.owner), false);
      expect(perms.hasMinimumRole(UserRole.manager), true);
      expect(perms.hasMinimumRole(UserRole.cashier), true);
    });

    test('Cashier only has minimum role for cashier', () {
      final perms = Permissions(UserRole.cashier);

      expect(perms.hasMinimumRole(UserRole.owner), false);
      expect(perms.hasMinimumRole(UserRole.manager), false);
      expect(perms.hasMinimumRole(UserRole.cashier), true);
    });
  });
}
