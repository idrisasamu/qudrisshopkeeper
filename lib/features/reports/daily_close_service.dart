import 'package:intl/intl.dart';
import '../../common/session.dart';
import '../../data/local/app_database.dart';
import '../../data/local/daos/report_dao.dart';
import '../sync/sync_utils.dart';
import '../sync/drive_client.dart';

class DailyCloseService {
  final AppDatabase db;
  final DriveClient dc;
  DailyCloseService(this.db, this.dc);

  Future<Map<String, dynamic>> buildZReport(DateTime day) async {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    final rep = ReportDao(db);

    final total = await rep.totalSalesBetween(start, end);
    final count = await rep.transactionsCountBetween(start, end);
    final top = await rep.topItemsBetween(start, end, limit: 10);

    final sessionManager = SessionManager();
    return {
      'shopId': await sessionManager.getString('shop_id'),
      'shopName': await sessionManager.getString('shop_name'),
      'date': DateFormat('yyyy-MM-dd').format(start),
      'total': total,
      'transactions': count,
      'topItems': top,
      'generatedAt': DateTime.now().toUtc().toIso8601String(),
    };
  }

  String _toCsv(Map<String, dynamic> report) {
    final b = StringBuffer();
    b.writeln('Shop,${report['shopName']}');
    b.writeln('Date,${report['date']}');
    b.writeln('Total,${report['total']}');
    b.writeln('Transactions,${report['transactions']}');
    b.writeln();
    b.writeln('Top Items');
    b.writeln('Item,Qty,Total');
    for (final row in (report['topItems'] as List)) {
      b.writeln('${row['item']},${row['qty']},${row['total']}');
    }
    return b.toString();
  }

  Future<void> exportZReportToDrive(DateTime day) async {
    final report = await buildZReport(day);
    final csv = _toCsv(report);

    // Encrypt CSV text with shop key, then upload to snapshots/exports
    final sessionManager = SessionManager();
    final parentSnapshots = await sessionManager.getString(
      'drive_snapshots_folder_id',
    );
    if (parentSnapshots == null) throw Exception('Snapshots folder not set');

    // ensure /snapshots/exports exists
    final exportsId = await dc.ensureFolderNamed(
      'exports',
      parentId: parentSnapshots,
    );
    final fname = SyncCodec.makeFileName(
      'zreport_${report['date']}.csv.json',
    ); // store encrypted
    final enc = await SyncCodec.encryptJson({
      'type': 'zreport',
      'format': 'csv',
      'data': csv,
      'meta': report,
    });
    await dc.uploadString(exportsId, fname, enc);
  }
}
