import 'package:flutter/material.dart';

class NewSalePage extends StatefulWidget {
  const NewSalePage({super.key});

  @override
  State<NewSalePage> createState() => _NewSalePageState();
}

class _NewSalePageState extends State<NewSalePage> {
  final searchCtrl = TextEditingController();
  final qtyCtrl = TextEditingController(text: '1');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Sale')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: searchCtrl,
              decoration: const InputDecoration(
                labelText: 'Search or scan item',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Qty'),
                const SizedBox(width: 12),
                SizedBox(
                  width: 90,
                  child: TextField(
                    controller: qtyCtrl,
                    keyboardType: TextInputType.number,
                  ),
                ),
                const Spacer(),
                FilledButton.icon(
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Scan'),
                  onPressed: () {
                    // TODO(Cursor): open camera via mobile_scanner
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                children: const [
                  ListTile(
                    title: Text('Example Item'),
                    subtitle: Text('On hand: —  •  Price: —'),
                    trailing: Icon(Icons.add),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              icon: const Icon(Icons.save),
              label: const Text('Save Sale'),
              onPressed: () {
                // TODO(Cursor): create Sale + SaleLines, create StockMovement(sale:-qty), enqueue SyncOps
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}
