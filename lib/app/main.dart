import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'router.dart';
import '../data/local/app_database.dart';
import '../features/sync/background_sync.dart';

final dbProvider = Provider<AppDatabase>((ref) => AppDatabase());

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initBackgroundSync();
  runApp(const ProviderScope(child: QskApp()));
}

class QskApp extends StatelessWidget {
  const QskApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Qudris ShopKeeper',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff0ea5e9)),
        useMaterial3: true,
      ),
      routerConfig: buildRouter(),
    );
  }
}
