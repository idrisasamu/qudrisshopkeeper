import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../data/local/app_database.dart' hide AppDatabase;
import '../data/local/database.dart';
import 'supabase_client.dart';

/// Sync status enum
enum SyncStatus { idle, syncing, success, error }

/// Sync result class
class SyncResult {
  final bool success;
  final Map<String, TableSyncSummary> tableSummaries;
  final List<String> errors;
  final Duration duration;

  SyncResult({
    required this.success,
    required this.tableSummaries,
    required this.errors,
    required this.duration,
  });

  int get totalPulled =>
      tableSummaries.values.fold(0, (sum, t) => sum + t.pulledCount);
  int get totalPushed =>
      tableSummaries.values.fold(0, (sum, t) => sum + t.pushedCount);
  int get totalConflicts =>
      tableSummaries.values.fold(0, (sum, t) => sum + t.conflictsCount);
}

class TableSyncSummary {
  final String tableName;
  final int pulledCount;
  final int pushedCount;
  final int conflictsCount;

  TableSyncSummary({
    required this.tableName,
    required this.pulledCount,
    required this.pushedCount,
    required this.conflictsCount,
  });
}

/// Offline-first sync service
class SyncService {
  final AppDatabase _db;
  final Dio _dio;
  final String supabaseUrl;
  final String supabaseKey;
  final String shopId;
  SyncStatus _status = SyncStatus.idle;
  DateTime? _lastSyncAt;
  String? _deviceId;
  Timer? _periodicSyncTimer;

  final _statusController = StreamController<SyncStatus>.broadcast();
  final _resultController = StreamController<SyncResult>.broadcast();

  Stream<SyncStatus> get statusStream => _statusController.stream;
  Stream<SyncResult> get resultStream => _resultController.stream;
  SyncStatus get status => _status;
  DateTime? get lastSyncAt => _lastSyncAt;

  // Sync configuration
  static const _syncInterval = Duration(minutes: 5);
  static const _maxRetries = 3;
  static const _retryDelays = [
    Duration(seconds: 1),
    Duration(seconds: 2),
    Duration(seconds: 4),
  ];

  // Tables to sync (order matters for FK dependencies)
  static const _syncTables = [
    'categories',
    'products',
    'inventory',
    'customers',
    'orders',
    'order_items',
    'payments',
    'stock_movements',
  ];

  SyncService({
    required AppDatabase db,
    required this.supabaseUrl,
    required this.supabaseKey,
    required this.shopId,
  }) : _db = db,
       _dio = Dio();

  /// Initialize sync service
  Future<void> initialize() async {
    _deviceId = await _getDeviceId();

    // Listen to connectivity changes
    Connectivity().onConnectivityChanged.listen((result) {
      if (result.contains(ConnectivityResult.wifi) ||
          result.contains(ConnectivityResult.mobile)) {
        // Connected - trigger sync
        sync();
      }
    });

    debugPrint('SyncService initialized with device ID: $_deviceId');
  }

  /// Start periodic background sync
  void startPeriodicSync() {
    stopPeriodicSync();

    _periodicSyncTimer = Timer.periodic(_syncInterval, (_) {
      sync();
    });

    debugPrint(
      'Started periodic sync every ${_syncInterval.inMinutes} minutes',
    );
  }

  /// Stop periodic sync
  void stopPeriodicSync() {
    _periodicSyncTimer?.cancel();
    _periodicSyncTimer = null;
  }

  /// Perform full sync
  Future<SyncResult> sync({String? shopId}) async {
    if (_status == SyncStatus.syncing) {
      debugPrint('Sync already in progress, skipping');
      return SyncResult(
        success: false,
        tableSummaries: {},
        errors: ['Sync already in progress'],
        duration: Duration.zero,
      );
    }

    _updateStatus(SyncStatus.syncing);
    final startTime = DateTime.now();
    final errors = <String>[];
    final summaries = <String, TableSyncSummary>{};

    try {
      // Check connectivity
      final connectivity = await Connectivity().checkConnectivity();
      if (!connectivity.contains(ConnectivityResult.wifi) &&
          !connectivity.contains(ConnectivityResult.mobile)) {
        throw Exception('No internet connection');
      }

      // Get active shop ID (from parameter or stored preference)
      final activeShopId = shopId ?? await _getActiveShopId();
      if (activeShopId == null) {
        throw Exception('No active shop selected');
      }

      // Sync each table
      for (final tableName in _syncTables) {
        try {
          final summary = await _syncTable(tableName, activeShopId);
          summaries[tableName] = summary;
        } catch (e) {
          debugPrint('Error syncing table $tableName: $e');
          errors.add('$tableName: ${e.toString()}');
        }
      }

      _lastSyncAt = DateTime.now();
      _updateStatus(SyncStatus.success);

      final result = SyncResult(
        success: errors.isEmpty,
        tableSummaries: summaries,
        errors: errors,
        duration: DateTime.now().difference(startTime),
      );

      _resultController.add(result);
      debugPrint(
        'Sync completed in ${result.duration.inSeconds}s - '
        'Pulled: ${result.totalPulled}, '
        'Pushed: ${result.totalPushed}, '
        'Conflicts: ${result.totalConflicts}',
      );

      return result;
    } catch (e, stackTrace) {
      debugPrint('Sync failed: $e');
      debugPrint('StackTrace: $stackTrace');

      _updateStatus(SyncStatus.error);

      final result = SyncResult(
        success: false,
        tableSummaries: summaries,
        errors: [...errors, e.toString()],
        duration: DateTime.now().difference(startTime),
      );

      _resultController.add(result);
      return result;
    }
  }

  /// Sync a single table
  Future<TableSyncSummary> _syncTable(String tableName, String shopId) async {
    // Get sync state
    // TODO: Implement when database.dart is active
    final syncState = null; // await _db.getSyncState(tableName, shopId);
    final lastPulledAt = syncState?.lastPulledAt;

    // Gather dirty rows to push
    final dirtyRows = await _getDirtyRows(tableName, shopId);

    // Call sync edge function
    final response = await _callSyncFunction(
      shopId: shopId,
      tableName: tableName,
      lastPulledAt: lastPulledAt,
      pushData: dirtyRows,
    );

    // Process response
    final pulledData = response['pulled_data'] as List? ?? [];
    final deletedData = response['deleted_data'] as List? ?? [];
    final pulledCount = response['pulled_count'] as int? ?? 0;
    final pushedCount = response['pushed_count'] as int? ?? 0;
    final conflictsCount = response['conflicts_count'] as int? ?? 0;

    // Apply pulled data to local DB
    await _applyPulledData(tableName, pulledData);

    // Apply deletions (soft delete locally)
    await _applyDeletions(tableName, deletedData);

    // Clear dirty flags for successfully pushed rows
    if (dirtyRows.isNotEmpty) {
      final pushedIds = dirtyRows.map((r) => r['id'] as String).toList();
      // TODO: Implement when database.dart is active
      // await _db.clearDirtyFlag(tableName, pushedIds);
    }

    // Update sync state
    // TODO: Implement when database.dart is active
    // await _db.updateSyncState(
    //   tableName,
    //   shopId,
    //   lastPulledAt: DateTime.now(),
    //   lastPushedAt: dirtyRows.isNotEmpty ? DateTime.now() : null,
    //   rowsPulled: pulledCount,
    //   rowsPushed: pushedCount,
    // );

    return TableSyncSummary(
      tableName: tableName,
      pulledCount: pulledCount,
      pushedCount: pushedCount,
      conflictsCount: conflictsCount,
    );
  }

  /// Call Supabase sync edge function
  Future<Map<String, dynamic>> _callSyncFunction({
    required String shopId,
    required String tableName,
    DateTime? lastPulledAt,
    List<Map<String, dynamic>> pushData = const [],
  }) async {
    final accessToken = SupabaseService.currentSession?.accessToken;
    if (accessToken == null) {
      throw Exception('Not authenticated');
    }

    final url = '$supabaseUrl/functions/v1/sync';

    final requestData = {
      'device_id': _deviceId,
      'shop_id': shopId,
      'tables': [
        {
          'table_name': tableName,
          if (lastPulledAt != null)
            'last_pulled_at': lastPulledAt.toIso8601String(),
          if (pushData.isNotEmpty) 'push_data': pushData,
        },
      ],
    };

    final response = await _dio.post(
      url,
      data: requestData,
      options: Options(
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      ),
    );

    if (response.statusCode != 200) {
      throw Exception('Sync failed: ${response.statusMessage}');
    }

    final data = response.data as Map<String, dynamic>;
    if (data['success'] != true) {
      final errors = data['errors'] as List? ?? [];
      throw Exception('Sync errors: ${errors.join(', ')}');
    }

    final results = data['results'] as List;
    if (results.isEmpty) {
      throw Exception('No sync results returned');
    }

    return results.first as Map<String, dynamic>;
  }

  /// Get dirty (modified) rows for a table
  Future<List<Map<String, dynamic>>> _getDirtyRows(
    String tableName,
    String shopId,
  ) async {
    // TODO: Implement when database.dart is active
    // The current app_database.dart doesn't have getDirtyProducts method
    return [];
  }

  /// Apply pulled data to local database
  Future<void> _applyPulledData(String tableName, List<dynamic> data) async {
    // TODO: Implement when database.dart is active
    // The current app_database.dart doesn't have upsertProducts method
    return;
  }

  /// Apply deletions (soft delete)
  Future<void> _applyDeletions(String tableName, List<dynamic> data) async {
    if (data.isEmpty) return;

    for (final item in data) {
      final id = item['id'] as String;
      final deletedAt = DateTime.parse(item['deleted_at'] as String);

      // Mark as deleted locally based on table
      // Implementation would update deleted_at column
      debugPrint('Soft deleting $tableName: $id at $deletedAt');
    }
  }

  // Commented out until database.dart is fully integrated
  // These methods require LocalProduct class from database.dart

  // /// Convert LocalProduct to JSON
  // Map<String, dynamic> _productToJson(LocalProduct product) {
  //   return {};
  // }

  // /// Convert JSON to LocalProduct
  // dynamic _jsonToProduct(Map<String, dynamic> json) {
  //   throw UnimplementedError('Requires database.dart');
  // }

  /// Get device ID
  Future<String> _getDeviceId() async {
    final deviceInfo = DeviceInfoPlugin();

    if (defaultTargetPlatform == TargetPlatform.android) {
      final androidInfo = await deviceInfo.androidInfo;
      return androidInfo.id;
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      final iosInfo = await deviceInfo.iosInfo;
      return iosInfo.identifierForVendor ?? 'unknown_ios';
    } else {
      return 'unknown_device';
    }
  }

  /// Get active shop ID (should be stored in shared preferences)
  Future<String?> _getActiveShopId() async {
    // TODO: Implement with shared_preferences or riverpod state
    return null;
  }

  /// Update sync status
  void _updateStatus(SyncStatus status) {
    _status = status;
    _statusController.add(status);
  }

  /// Dispose resources
  void dispose() {
    stopPeriodicSync();
    _statusController.close();
    _resultController.close();
  }
}
