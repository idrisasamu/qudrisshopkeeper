import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/local/app_database.dart';
import '../app/main.dart';
import 'uuid.dart';

final deviceRegistryProvider = Provider<DeviceRegistry>((ref) {
  final db = ref.read(dbProvider);
  return DeviceRegistry(db);
});

class DeviceRegistry {
  final AppDatabase db;

  DeviceRegistry(this.db);

  Future<String> getOrCreateDeviceId() async {
    // For now, just return a fixed device ID
    return 'device-${newId()}';
  }

  Future<void> setShopId(String shopId) async {
    // Stub implementation - just print for now
    print('Setting shop ID: $shopId');
  }

  Future<void> setShopShortId(String shopShortId) async {
    // Stub implementation - just print for now
    print('Setting shop short ID: $shopShortId');
  }

  Future<void> setAdmin(bool isAdmin) async {
    // Stub implementation - just print for now
    print('Setting admin: $isAdmin');
  }

  Future<String?> get shopId async {
    // For testing, return a default shop ID
    return '01K55ZR8YCEFEBGF680E5YD6DM';
  }

  Future<String?> get shopShortId async {
    // Stub implementation - return null for now
    return null;
  }

  Future<bool> get isAdmin async {
    // Stub implementation - return true for now
    return true;
  }
}
