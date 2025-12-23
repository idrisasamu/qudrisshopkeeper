import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/migration_service.dart';
import '../../data/local/app_database.dart';
import '../../services/storage_service.dart';
import 'package:dio/dio.dart';

class MigrationPage extends ConsumerStatefulWidget {
  final String shopId;
  final String userId;

  const MigrationPage({super.key, required this.shopId, required this.userId});

  @override
  ConsumerState<MigrationPage> createState() => _MigrationPageState();
}

class _MigrationPageState extends ConsumerState<MigrationPage> {
  late final MigrationService _migrationService;
  bool _isMigrating = false;
  double _progress = 0.0;
  String _currentStep = '';
  MigrationResult? _result;

  @override
  void initState() {
    super.initState();
    final db = AppDatabase();
    final storageService = StorageService(Dio());
    _migrationService = MigrationService(db, storageService);
  }

  Future<void> _startMigration() async {
    setState(() {
      _isMigrating = true;
      _progress = 0.0;
      _currentStep = 'Preparing migration...';
      _result = null;
    });

    try {
      final result = await _migrationService.migrate(
        shopId: widget.shopId,
        userId: widget.userId,
        onProgress: (step) {
          setState(() {
            _currentStep = step;
          });
        },
        onProgressPercent: (percent) {
          setState(() {
            _progress = percent;
          });
        },
      );

      setState(() {
        _result = result;
        _isMigrating = false;
      });

      if (result.success && mounted) {
        // Show success dialog
        _showSuccessDialog(result);
      }
    } catch (e) {
      setState(() {
        _isMigrating = false;
        _result = MigrationResult()
          ..success = false
          ..error = e.toString();
      });

      if (mounted) {
        _showErrorDialog(e.toString());
      }
    }
  }

  void _showSuccessDialog(MigrationResult result) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.check_circle, color: Colors.green, size: 64),
        title: const Text('Migration Complete!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Successfully migrated ${result.totalMigrated} items'),
            const SizedBox(height: 16),
            const Text(
              'Summary:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...result.summary.entries.map(
              (e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(e.key),
                    Text(
                      e.value.toString(),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text('Duration: ${result.duration.inSeconds} seconds'),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pop(); // Go back to main app
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.error, color: Colors.red, size: 64),
        title: const Text('Migration Failed'),
        content: Text(error),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _startMigration();
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Migrate to Supabase'),
        automaticallyImplyLeading: !_isMigrating,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Icon(
                _result?.success == true
                    ? Icons.cloud_done
                    : Icons.cloud_upload,
                size: 80,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(height: 24),

              Text(
                'Migrate Your Data',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),

              Text(
                'This will move all your local data to Supabase cloud storage for sync across devices.',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // What will be migrated
              if (!_isMigrating && _result == null) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'What will be migrated:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        _buildMigrationItem(
                          Icons.category,
                          'Product categories',
                        ),
                        _buildMigrationItem(
                          Icons.inventory,
                          'Products & inventory',
                        ),
                        _buildMigrationItem(Icons.image, 'Product images'),
                        _buildMigrationItem(Icons.people, 'Customers'),
                        _buildMigrationItem(
                          Icons.shopping_cart,
                          'Orders & sales',
                        ),
                        _buildMigrationItem(
                          Icons.payment,
                          'Payments & receipts',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                Card(
                  color: Colors.blue[50],
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue[700]),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Your local data will remain safe. This is a one-time operation.',
                            style: TextStyle(color: Colors.blue[900]),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              // Progress indicator
              if (_isMigrating) ...[
                const Spacer(),
                LinearProgressIndicator(value: _progress),
                const SizedBox(height: 16),
                Text(
                  _currentStep,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  '${(_progress * 100).toInt()}%',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
              ],

              // Result summary
              if (_result != null && !_result!.success) ...[
                const Spacer(),
                Card(
                  color: Colors.red[50],
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.error, color: Colors.red[700]),
                            const SizedBox(width: 12),
                            Text(
                              'Migration Failed',
                              style: TextStyle(
                                color: Colors.red[900],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _result!.error ?? 'Unknown error',
                          style: TextStyle(color: Colors.red[900]),
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
              ],

              const Spacer(),

              // Action button
              if (!_isMigrating) ...[
                FilledButton(
                  onPressed: _result?.success == true ? null : _startMigration,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(
                    _result?.success == true
                        ? 'Migration Complete'
                        : _result != null
                        ? 'Retry Migration'
                        : 'Start Migration',
                  ),
                ),
                if (_result == null) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Skip for Now'),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMigrationItem(IconData icon, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Text(label),
        ],
      ),
    );
  }
}
