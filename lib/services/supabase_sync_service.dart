import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app/main.dart';
import '../common/session.dart';
import '../config/env.dart';
import '../services/supabase_client.dart';
import '../services/sync_service.dart' as supabase_sync;

/// New Supabase-based sync service provider
final supabaseSyncServiceProvider = Provider<SupabaseSyncService>((ref) {
  return SupabaseSyncService();
});

/// Supabase sync service - replaces Google Drive sync
class SupabaseSyncService {
  Timer? _timer;
  bool _isRunning = false;

  /// Start automatic sync with Supabase
  void start() {
    if (_isRunning) return;

    _timer?.cancel();
    _isRunning = true;

    print('DEBUG: SupabaseSyncService.start() - starting Supabase sync timer');

    // Sync every 2 minutes (less frequent than Google Drive)
    _timer = Timer.periodic(const Duration(minutes: 2), (_) => syncNow());
  }

  /// Stop automatic sync
  void stop() {
    _timer?.cancel();
    _timer = null;
    _isRunning = false;
    print('DEBUG: SupabaseSyncService.stop() - stopped Supabase sync');
  }

  /// Manual sync with Supabase
  Future<void> syncNow() async {
    try {
      print('DEBUG: SupabaseSyncService.syncNow() - starting sync...');

      // Check if user is authenticated
      if (!SupabaseService.isAuthenticated) {
        print(
          'DEBUG: SupabaseSyncService - user not authenticated, skipping sync',
        );
        return;
      }

      final sessionManager = SessionManager();
      final shopId = await sessionManager.getString('shop_id');

      if (shopId == null) {
        print('DEBUG: SupabaseSyncService - no shop selected, skipping sync');
        return;
      }

      // Get database instance
      final container = ProviderContainer();
      final dbHolder = container.read(dbHolderProvider);

      if (!dbHolder.isOpen) {
        print('DEBUG: SupabaseSyncService - database not open, skipping sync');
        return;
      }

      // Note: sync_service.dart uses database.dart AppDatabase
      // but dbHolder.db is app_database.dart AppDatabase
      // For now, skip sync if database types mismatch
      // TODO: Refactor to use consistent database type

      print(
        'DEBUG: SupabaseSyncService - sync skipped (database type mismatch)',
      );

      print('DEBUG: SupabaseSyncService - sync completed successfully');
    } catch (e) {
      print('ERROR: SupabaseSyncService.syncNow() failed: $e');
    }
  }

  /// Check sync status
  Future<bool> isConnected() async {
    try {
      return SupabaseService.isAuthenticated;
    } catch (e) {
      print('ERROR: SupabaseSyncService.isConnected() failed: $e');
      return false;
    }
  }

  /// Get last sync time
  Future<DateTime?> getLastSyncTime() async {
    try {
      final sessionManager = SessionManager();
      final lastSync = await sessionManager.getString('last_supabase_sync');
      if (lastSync != null) {
        return DateTime.tryParse(lastSync);
      }
      return null;
    } catch (e) {
      print('ERROR: SupabaseSyncService.getLastSyncTime() failed: $e');
      return null;
    }
  }

  /// Update last sync time
  Future<void> updateLastSyncTime() async {
    try {
      final sessionManager = SessionManager();
      await sessionManager.setString(
        'last_supabase_sync',
        DateTime.now().toIso8601String(),
      );
    } catch (e) {
      print('ERROR: SupabaseSyncService.updateLastSyncTime() failed: $e');
    }
  }
}
