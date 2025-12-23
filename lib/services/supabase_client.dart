import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase client singleton
/// Initialize this in main.dart before runApp()
class SupabaseService {
  static SupabaseClient? _client;
  static bool _initialized = false;

  /// Initialize Supabase
  /// Call this once in main() before runApp()
  static Future<void> initialize({
    required String url,
    required String anonKey,
  }) async {
    if (_initialized) {
      debugPrint('Supabase already initialized');
      return;
    }

    try {
      await Supabase.initialize(
        url: url,
        anonKey: anonKey,
        authOptions: const FlutterAuthClientOptions(
          authFlowType: AuthFlowType.pkce,
        ),
        realtimeClientOptions: const RealtimeClientOptions(
          logLevel: RealtimeLogLevel.info,
        ),
        storageOptions: const StorageClientOptions(retryAttempts: 3),
      );

      _client = Supabase.instance.client;
      _initialized = true;

      debugPrint('Supabase initialized successfully');
      debugPrint('URL: $url');
    } catch (e, stackTrace) {
      debugPrint('Failed to initialize Supabase: $e');
      debugPrint('StackTrace: $stackTrace');
      rethrow;
    }
  }

  /// Get the Supabase client instance
  static SupabaseClient get client {
    if (_client == null || !_initialized) {
      throw Exception(
        'Supabase not initialized. Call SupabaseService.initialize() first.',
      );
    }
    return _client!;
  }

  /// Quick access to auth
  static GoTrueClient get auth => client.auth;

  /// Quick access to storage
  static SupabaseStorageClient get storage => client.storage;

  /// Quick access to database
  static PostgrestClient get db => client.from('') as PostgrestClient;

  /// Quick access to functions
  static FunctionsClient get functions => client.functions;

  /// Check if user is authenticated
  static bool get isAuthenticated => auth.currentUser != null;

  /// Get current user
  static User? get currentUser => auth.currentUser;

  /// Get current session
  static Session? get currentSession => auth.currentSession;

  /// Get current user ID
  static String? get currentUserId => currentUser?.id;

  /// Listen to auth state changes
  static Stream<AuthState> get authStateChanges => auth.onAuthStateChange;

  /// Sign out
  static Future<void> signOut() async {
    await auth.signOut();
  }

  /// Check initialization status
  static bool get isInitialized => _initialized;
}

/// Extension for easier access to Supabase
extension SupabaseExtension on Object {
  SupabaseClient get supabase => SupabaseService.client;
}
