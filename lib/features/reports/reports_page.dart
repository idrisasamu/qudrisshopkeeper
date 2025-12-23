import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/local/app_database.dart';
import '../../data/local/daos/report_dao.dart';
import 'package:collection/collection.dart';

class ReportsPage extends StatefulWidget {
  final AppDatabase db;
  final bool readOnly;
  const ReportsPage({super.key, required this.db, this.readOnly = false});
  @override 
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  DateTimeRange _range = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 6)),
    end: DateTime.now().add(const Duration(days: 1)),
  );
  double _total = 0;
  int _count = 0;
  List<Map<String,dynamic>> _top = [];
  bool _loading = true;

  @override 
  void initState() { 
    super.initState(); 
    _load(); 
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final rep = ReportDao(widget.db);
    final total = await rep.totalSalesBetween(_range.start, _range.end);
    final count = await rep.transactionsCountBetween(_range.start, _range.end);
    final top = await rep.topItemsBetween(_range.start, _range.end);
    setState(() { 
      _total = total; 
      _count = count; 
      _top = top; 
      _loading = false; 
    });
  }

  @override
  Widget build(BuildContext context) {
    final f = NumberFormat.currency(symbol: '');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) async {
              final today = DateTime.now();
              if (v=='today') {
                final s = DateTime(today.year,today.month,today.day);
                setState(()=>_range = DateTimeRange(start: s, end: s.add(const Duration(days:1))));
              } else if (v=='7') {
                final e = DateTime(today.year,today.month,today.day).add(const Duration(days:1));
                setState(()=>_range = DateTimeRange(start: e.subtract(const Duration(days:7)), end: e));
              } else if (v=='custom') {
                final picked = await showDateRangePicker(
                  context: context, 
                  firstDate: DateTime(2020), 
                  lastDate: DateTime.now().add(const Duration(days:365)), 
                  initialDateRange: _range
                );
                if (picked!=null) setState(()=>_range=picked);
              }
              await _load();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'today', child: Text('Today')),
              PopupMenuItem(value: '7', child: Text('Last 7 days')),
              PopupMenuItem(value: 'custom', child: Text('Custom...')),
            ],
          ),
        ],
      ),
      body: _loading ? const Center(child: CircularProgressIndicator()) : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('From ${DateFormat('yyyy-MM-dd').format(_range.start)} to ${DateFormat('yyyy-MM-dd').format(_range.end.subtract(const Duration(days:1)))}'),
          const SizedBox(height: 12),
          Card(child: ListTile(title: const Text('Total sales'), trailing: Text(f.format(_total)))),
          Card(child: ListTile(title: const Text('Transactions'), trailing: Text('$_count'))),
          const SizedBox(height: 12),
          const Text('Top items'),
          const SizedBox(height: 8),
          ..._top.mapIndexed((i,row)=> Card(
            child: ListTile(
              leading: CircleAvatar(child: Text('${i+1}')),
              title: Text(row['item']?.toString() ?? '—'),
              subtitle: Text('Qty: ${row['qty']}'),
              trailing: Text(f.format(row['total'])),
            ),
          )),
        ],
      ),
    );
  }
}
