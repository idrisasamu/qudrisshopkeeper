import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../common/session.dart';
import '../sync/crypto_box.dart';

class ShopQrPage extends StatefulWidget {
  const ShopQrPage({super.key});
  @override
  State<ShopQrPage> createState() => _ShopQrPageState();
}

class _ShopQrPageState extends State<ShopQrPage> {
  String? _json;

  @override
  void initState() {
    super.initState();
    _buildJson();
  }

  Future<void> _buildJson() async {
    final sessionManager = SessionManager();
    final shopId = await sessionManager.getString('shop_id') ?? '';
    final shopName = await sessionManager.getString('shop_name') ?? shopId;
    final rootId = await sessionManager.getString('drive_shop_folder_id');
    final bId = await sessionManager.getString('drive_broadcast_folder_id');
    final sId = await sessionManager.getString('drive_snapshots_folder_id');
    final iRoot = await sessionManager.getString('drive_inbox_root_id');
    final kShop = await sessionManager.getString('shop_key_b64');

    // One-time invite secret (owner shows it in QR; staff uses it to unwrap K_shop)
    final inviteSecret = CryptoBox.generateInviteSecret();
    final wrapped = await CryptoBox.wrapShopKeyForInvite(
      shopKeyB64: kShop!,
      inviteSecretB64: inviteSecret,
      shopIdSalt: shopId,
    );

    final payload = {
      'v': 2,
      'shopId': shopId,
      'shopName': shopName,
      'shopRootId': rootId,
      'broadcastId': bId,
      'snapshotsId': sId,
      'inboxRootId': iRoot,
      'wrappedK': wrapped,
      'inviteSecret': inviteSecret, // staff uses this ONCE to unwrap
      'keyVersion': await sessionManager.getInt('shop_key_version') ?? 1,
    };
    setState(() => _json = jsonEncode(payload));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Share shop via QR')),
      body: Center(
        child: _json == null
            ? const CircularProgressIndicator()
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  QrImageView(data: _json!, size: 260),
                  const SizedBox(height: 24),
                  const Text(
                    'Staff can scan this QR code to join your shop',
                    style: TextStyle(fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.withOpacity(0.3)),
                    ),
                    child: const Text(
                      'If QR scanning doesn\'t work, staff can also use the "Scan QR / Paste ID" option in the app.',
                      style: TextStyle(color: Colors.blue, fontSize: 12),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
