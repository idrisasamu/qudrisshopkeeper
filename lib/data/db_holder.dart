import 'package:flutter/foundation.dart';
import 'local/app_database.dart';

/// Centralized database lifecycle management
/// Ensures database is properly opened/closed when shop/session changes
class DbHolder extends ChangeNotifier {
  AppDatabase? _db;

  /// Get the current database instance
  /// Throws StateError if database is not opened yet
  AppDatabase get db {
    final d = _db;
    if (d == null) throw StateError('DB not opened yet');
    return d;
  }

  /// Check if database is currently open
  bool get isOpen => _db != null;

  /// Open database for a specific shop
  /// Closes any existing database first
  Future<void> openForShop(String shopId) async {
    print('DEBUG: DbHolder.openForShop($shopId)');

    // Close existing database if open
    await _db?.close();

    // Create new database instance
    _db = AppDatabase();
    print('DEBUG: AppDatabase constructed for shop: $shopId');

    print('DEBUG: Database opened for shop: $shopId');
    notifyListeners(); // Rebuild all listeners (pages/repos/DAOs)
  }

  /// Close the database and clear the reference
  Future<void> close() async {
    print('DEBUG: DbHolder.close()');

    await _db?.close();
    _db = null;

    print('DEBUG: Database closed');
    notifyListeners();
  }

  @override
  void dispose() {
    _db?.close();
    super.dispose();
  }
}
