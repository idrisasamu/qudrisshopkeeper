import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../common/session.dart';

/// Sync status widget showing last sync time
class SyncStatusWidget extends ConsumerStatefulWidget {
  const SyncStatusWidget({super.key});

  @override
  ConsumerState<SyncStatusWidget> createState() => _SyncStatusWidgetState();
}

class _SyncStatusWidgetState extends ConsumerState<SyncStatusWidget> {
  final SessionManager _sessionManager = SessionManager();
  bool _isDriveEnabled = false;
  DateTime? _lastSyncTime;

  @override
  void initState() {
    super.initState();
    _checkSyncStatus();
  }

  Future<void> _checkSyncStatus() async {
    final isEnabled = await _sessionManager.isDriveEnabled();
    setState(() {
      _isDriveEnabled = isEnabled;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isDriveEnabled) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green[300]!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.sync, size: 16, color: Colors.green[700]),
          const SizedBox(width: 4),
          Text(
            _lastSyncTime != null
                ? 'Synced • ${_formatLastSync(_lastSyncTime!)}'
                : 'Sync enabled',
            style: TextStyle(
              fontSize: 12,
              color: Colors.green[700],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _formatLastSync(DateTime lastSync) {
    final now = DateTime.now();
    final difference = now.difference(lastSync);

    if (difference.inMinutes < 1) {
      return 'now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}

/// Enable Drive Sync button
class EnableDriveSyncButton extends ConsumerStatefulWidget {
  const EnableDriveSyncButton({super.key});

  @override
  ConsumerState<EnableDriveSyncButton> createState() =>
      _EnableDriveSyncButtonState();
}

class _EnableDriveSyncButtonState extends ConsumerState<EnableDriveSyncButton> {
  final SessionManager _sessionManager = SessionManager();
  bool _isLoading = false;

  Future<void> _enableDriveSync() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // TODO: Implement Drive folder creation and permission setup
      // This would involve:
      // 1. Requesting Drive scope
      // 2. Creating folder structure
      // 3. Storing folder IDs
      // 4. Setting drive_enabled=true

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Drive sync setup coming soon!'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error enabling Drive sync: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: _isLoading ? null : _enableDriveSync,
      icon: _isLoading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.cloud_upload),
      label: Text(_isLoading ? 'Setting up...' : 'Enable Drive Sync'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
    );
  }
}
