import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'router.dart';
import 'theme.dart';
import '../data/db_holder.dart';
import '../data/local/app_database.dart';
import '../common/session.dart';
import '../services/supabase_client.dart';
import '../config/env.dart';

final dbHolderProvider = ChangeNotifierProvider<DbHolder>((ref) {
  return DbHolder();
});

// Legacy provider for backward compatibility - will be removed
final dbProvider = Provider((ref) {
  final holder = ref.watch(dbHolderProvider);
  if (!holder.isOpen) {
    throw StateError('Database not opened yet');
  }
  return holder.db;
});

/// Safety wrapper for database operations that auto-reopens if closed
Future<T> withDb<T>(
  WidgetRef ref,
  Future<T> Function(AppDatabase db) run,
) async {
  final holder = ref.read(dbHolderProvider);
  try {
    return await run(holder.db);
  } catch (e) {
    if (e.toString().contains('database_closed')) {
      final sessionManager = SessionManager();
      final shopId = await sessionManager.getString('shop_id');
      if (shopId != null) {
        await holder.openForShop(shopId);
        return await run(holder.db);
      }
    }
    rethrow;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Initialize Supabase FIRST
  await SupabaseService.initialize(
    url: Env.supabaseUrl,
    anonKey: Env.supabaseAnonKey,
  );

  // ✅ Google Drive sync disabled - using Supabase sync instead
  // await initBackgroundSync(); // DISABLED: No more Google Drive

  // Initialize database on startup
  final container = ProviderContainer();
  final dbHolder = container.read(dbHolderProvider);

  // Try to get shop ID from session, fallback to default
  final sessionManager = SessionManager();
  final shopId = await sessionManager.getString('shop_id') ?? 'SHOP-LOCAL';

  // Open database for the shop
  await dbHolder.openForShop(shopId);

  runApp(
    UncontrolledProviderScope(container: container, child: const QskApp()),
  );
}

class QskApp extends ConsumerWidget {
  const QskApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ✅ Listen to Supabase auth state changes
    final router = buildRouter();

    // Listen to auth state and refresh router when it changes
    SupabaseService.authStateChanges.listen((authState) {
      print(
        'DEBUG: Auth state changed - User: ${authState.session?.user?.email}',
      );
      router.refresh();
    });

    return MaterialApp.router(
      title: 'Qudris ShopKeeper',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme(),
      routerConfig: router,
    );
  }
}
