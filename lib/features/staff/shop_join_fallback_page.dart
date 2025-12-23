import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../common/session.dart';
import '../sync/drive_client.dart';
import '../sync/crypto_box.dart';
import '../../app/router.dart';

class ShopJoinFallbackPage extends StatefulWidget {
  final DriveClient dc;
  const ShopJoinFallbackPage({super.key, required this.dc});
  @override
  State<ShopJoinFallbackPage> createState() => _ShopJoinFallbackPageState();
}

class _ShopJoinFallbackPageState extends State<ShopJoinFallbackPage> {
  final _manualCtrl = TextEditingController();
  bool _busy = false;
  String? _error;

  Future<void> _applyJson(Map<String, dynamic> data) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final shopRootId = data['shopRootId'] as String?;
      if (shopRootId == null) throw Exception('Invalid QR: missing shopRootId');

      final dc = widget.dc;

      final broadcastId =
          (data['broadcastId'] as String?) ??
          await dc.ensureFolderNamed('broadcast', parentId: shopRootId);
      final snapshotsId =
          (data['snapshotsId'] as String?) ??
          await dc.ensureFolderNamed('snapshots', parentId: shopRootId);
      final inboxRootId =
          (data['inboxRootId'] as String?) ??
          await dc.ensureFolderNamed('inbox_sales', parentId: shopRootId);

      final me = await GoogleSignIn().signInSilently();
      if (me == null) throw Exception('Sign in with Google first.');
      final myInboxId =
          await dc.findChildFolderId(inboxRootId, me.email) ??
          (await dc.createFolder(me.email, parentId: inboxRootId)).id!;

      final sessionManager = SessionManager();
      await sessionManager.setString(
        'shop_id',
        (data['shopId'] as String?) ?? '',
      );
      await sessionManager.setString(
        'shop_name',
        (data['shopName'] as String?) ?? '',
      );
      await sessionManager.setString('drive_shop_folder_id', shopRootId);
      await sessionManager.setString('drive_broadcast_folder_id', broadcastId);
      await sessionManager.setString('drive_snapshots_folder_id', snapshotsId);
      await sessionManager.setString('drive_inbox_root_id', inboxRootId);
      await sessionManager.setString('drive_inbox_my_id', myInboxId);
      await sessionManager.setString('role', 'staff');
      await sessionManager.setString('drive_enabled', 'true');

      // Unwrap K_shop using invite secret + wrappedK if present
      final wrappedK = data['wrappedK'] as String?;
      final inviteSecret = data['inviteSecret'] as String?;
      final shopId = (data['shopId'] as String?) ?? '';

      if (wrappedK != null && inviteSecret != null && shopId.isNotEmpty) {
        final kShop = await CryptoBox.unwrapShopKeyFromInvite(
          wrappedB64: wrappedK,
          inviteSecretB64: inviteSecret,
          shopIdSalt: shopId,
        );
        await sessionManager.setString('shop_key_b64', kShop);
        await sessionManager.setInt('shop_key_version', (data['keyVersion'] as int?) ?? 1);
      }

      if (mounted) {
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil(routeStaffHome, (r) => false);
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _handleManual() async {
    if (_manualCtrl.text.trim().isEmpty) return;
    try {
      final data = jsonDecode(_manualCtrl.text.trim()) as Map<String, dynamic>;
      await _applyJson(data);
    } catch (e) {
      setState(() => _error = 'Invalid JSON: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Join shop (QR / Manual)')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (_error != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            if (_error != null) const SizedBox(height: 8),
            Expanded(
              child: Card(
                child: MobileScanner(
                  onDetect: (capture) async {
                    if (_busy) return;
                    final raw = capture.barcodes.first.rawValue;
                    if (raw == null) return;
                    try {
                      final data = jsonDecode(raw) as Map<String, dynamic>;
                      await _applyJson(data);
                    } catch (_) {
                      setState(
                        () => _error = 'Scanned QR is not valid for QSK',
                      );
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _manualCtrl,
              decoration: const InputDecoration(
                labelText: 'Paste shop JSON (from owner QR)',
                border: OutlineInputBorder(),
              ),
              minLines: 1,
              maxLines: 5,
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _busy ? null : _handleManual,
              child: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Join with pasted JSON'),
            ),
          ],
        ),
      ),
    );
  }
}
