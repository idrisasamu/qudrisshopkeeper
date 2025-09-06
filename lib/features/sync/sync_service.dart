import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/main.dart';
import '../../common/device_registry.dart';
import '../../common/key_vault.dart';
import '../../data/peers.dart';
import '../../data/repositories.dart';
import 'crypto_box.dart';
import 'email_config_store.dart';
import 'email_transport.dart';
import 'sms_transport.dart';
import 'sync_engine.dart';
import 'sync_orchestrator.dart';

final deviceRegistryProvider = Provider<DeviceRegistry>((ref) => DeviceRegistry(ref.read(dbProvider)));
final shopShortIdProvider = FutureProvider<String>((ref) async {
  final reg = ref.read(deviceRegistryProvider);
  return (await reg.shopShortId()) ?? 'SHOP01';
});

final syncServiceProvider = Provider<SyncService>((ref) {
  final engine = ref.read(syncEngineProvider);
  final reg = ref.read(deviceRegistryProvider);
  return SyncService(engine: engine, registry: reg);
});

class SyncService {
  final SyncEngine engine;
  final DeviceRegistry registry;

  SyncService({required this.engine, required this.registry});

  Future<void> syncNowEmail({
    required EmailConfig cfg,
    required List<Peer> peers,
  }) async {
    final deviceId = await registry.getOrCreateDeviceId();
    final shopShort = (await registry.shopShortId()) ?? 'SHOP01';

    final orchestrator = SyncOrchestrator(
      engine: engine,
      selfDeviceId: deviceId,
      shopShortId: shopShort,
      email: EmailTransportImpl(),
      sms: SmsTransportImpl(),
      keyVault: KeyVault(),
      crypto: CryptoBox(),
    );

    // Send out deltas to all peers
    for (final p in peers) {
      await orchestrator.sendEmailDelta(cfg: cfg, peer: p);
    }

    // Poll and apply
    await orchestrator.pollEmailApply(cfg: cfg, knownPeers: peers);
  }
}
