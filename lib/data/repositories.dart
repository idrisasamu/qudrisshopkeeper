import 'package:flutter_riverpod/flutter_riverpod.dart';

final deviceIdProvider = Provider<String>(
  (_) => 'DEVICE-${DateTime.now().millisecondsSinceEpoch}',
); // TODO: stable device id
