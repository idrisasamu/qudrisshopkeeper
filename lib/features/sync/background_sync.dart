import 'dart:async';
import 'package:workmanager/workmanager.dart';
import '../../data/local/app_database.dart';
import 'sync_engine_impl.dart';
import 'sync_engine.dart';

const qskBackgroundTask = 'qsk.sync.task';

/// Call once in app startup.
Future<void> initBackgroundSync() async {
  await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
  await scheduleBackgroundSync();
}

Future<void> scheduleBackgroundSync() async {
  await Workmanager().registerPeriodicTask(
    'qsk-sync-periodic',
    qskBackgroundTask,
    frequency: const Duration(minutes: 30),
    existingWorkPolicy: ExistingWorkPolicy.keep,
    constraints: Constraints(
      networkType: NetworkType
          .connected, // still runs; transports will choose SMS if needed
    ),
    initialDelay: const Duration(minutes: 5),
    backoffPolicy: BackoffPolicy.linear,
  );
}

/// Top-level entry for background isolate.
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task == qskBackgroundTask) {
      final db = AppDatabase();
      final engine = SyncEngineImpl(
        db: db,
        selfDeviceId: 'BG-${DateTime.now().millisecondsSinceEpoch}',
      );
      try {
        await engine
            .reconcile(); // TODO(Cursor): implement real transport orchestration
      } catch (_) {
        // swallow errors in background
      } finally {
        await db.close();
      }
      return true;
    }
    return false;
  });
}
