import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../common/session.dart';
import 'sync_service.dart';

class SyncScheduler {
  Timer? _timer;
  final SyncService service;
  SyncScheduler(this.service);

  Future<void> start() async {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(minutes: 15), (_) async {
      final sessionManager = SessionManager();
      final enabled = await sessionManager.getString('drive_enabled') == 'true';
      if (!enabled) return;
      
      final conn = await Connectivity().checkConnectivity();
      if (conn == ConnectivityResult.none) return;
      
      try { 
        await service.syncNow(); 
      } catch (e) {
        print('Background sync failed: $e');
      }
    });
  }

  void stop() { 
    _timer?.cancel(); 
    _timer = null; 
  }
}
