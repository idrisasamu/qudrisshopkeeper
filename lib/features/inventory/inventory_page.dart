import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import '../../data/repositories.dart';
import '../../common/uuid.dart';
import '../sync/sync_engine_impl.dart';

class InventoryPage extends ConsumerWidget {
  const InventoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Inventory')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            builder: (_) => const _NewItemSheet(),
          );
        },
        label: const Text('Add Item'),
        icon: const Icon(Icons.add),
      ),
      body: const Center(child: Text('Items will appear here')),
    );
  }
}

class _NewItemSheet extends ConsumerWidget {
  const _NewItemSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final minCtrl = TextEditingController(text: '0');

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: ListView(
        shrinkWrap: true,
        children: [
          const Text(
            'New Item',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: nameCtrl,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          TextField(
            controller: priceCtrl,
            decoration: const InputDecoration(labelText: 'Sale price'),
            keyboardType: TextInputType.number,
          ),
          TextField(
            controller: minCtrl,
            decoration: const InputDecoration(labelText: 'Low-stock threshold'),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () async {
              await _saveItem(context, ref, nameCtrl, priceCtrl, minCtrl);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveItem(
    BuildContext context,
    WidgetRef ref,
    TextEditingController nameCtrl,
    TextEditingController priceCtrl,
    TextEditingController minCtrl,
  ) async {
    if (nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter a name')));
      return;
    }

    try {
      final sync = ref.read(syncEngineProvider);
      final deviceId = ref.read(deviceIdProvider);
      final db = ref.read(dbProvider);

      final id = newId();
      final payload = {
        'id': id,
        'shopId': 'SHOP-LOCAL', // TODO: bind real shop id
        'name': nameCtrl.text.trim(),
        'sku': null,
        'barcode': null,
        'category': null,
        'unit': 'unit',
        'costPrice': 0.0,
        'salePrice': double.tryParse(priceCtrl.text) ?? 0.0,
        'minQty': double.tryParse(minCtrl.text) ?? 0.0,
        'isActive': true,
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
      };

      // Write locally
      await db
          .into(db.items)
          .insert(db.items.fromJson(payload), mode: InsertMode.insertOrReplace);

      // Enqueue sync op
      await sync.enqueueOp(
        makeOp(
          entity: 'items',
          op: 'create',
          payload: payload,
          deviceId: deviceId,
        ),
      );

      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Item saved successfully')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error saving item: $e')));
    }
  }
}
