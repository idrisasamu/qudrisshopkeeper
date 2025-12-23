import 'dart:async';
// import 'package:workmanager/workmanager.dart';  // Temporarily disabled

const qskBackgroundTask = 'qsk.sync.task';

/// Call once in app startup.
/// Temporarily stubbed out due to workmanager namespace issues
Future<void> initBackgroundSync() async {
  // TODO: Re-enable when workmanager namespace issue is resolved
  print('Background sync temporarily disabled');
  // await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
  // await scheduleBackgroundSync();
}

Future<void> scheduleBackgroundSync() async {
  // TODO: Re-enable when workmanager namespace issue is resolved
  print('Background sync scheduling temporarily disabled');
  // await Workmanager().registerPeriodicTask(
  //   'qsk-sync-periodic',
  //   qskBackgroundTask,
  //   frequency: const Duration(minutes: 30),
  //   existingWorkPolicy: ExistingWorkPolicy.keep,
  //   constraints: Constraints(
  //     networkType: NetworkType
  //         .connected, // still runs; transports will choose SMS if needed
  //   ),
  //   initialDelay: const Duration(minutes: 5),
  //   backoffPolicy: BackoffPolicy.linear,
  // );
}

/// Top-level entry for background isolate.
/// Temporarily stubbed out due to workmanager namespace issues
void callbackDispatcher() {
  // TODO: Re-enable when workmanager namespace issue is resolved
  print('Background sync callback dispatcher temporarily disabled');
  // Workmanager().executeTask((task, inputData) async {
  //   if (task == qskBackgroundTask) {
  //     final db = AppDatabase();
  //     final engine = SyncEngineImpl(
  //       db: db,
  //       selfDeviceId: 'BG-${DateTime.now().millisecondsSinceEpoch}',
  //     );
  //     try {
  //       await engine
  //           .reconcile(); // TODO(Cursor): implement real transport orchestration
  //     } catch (_) {
  //       // swallow errors in background
  //     } finally {
  //       await db.close();
  //     }
  //     return true;
  //   }
  //   return false;
  // });
}
