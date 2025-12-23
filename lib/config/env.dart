/// Environment configuration
///
/// In production, load these from environment variables or a secure .env file
/// For development, you can hardcode values here (but NEVER commit secrets!)
class Env {
  /// Supabase project URL
  /// Get this from your Supabase project settings
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://erikfxagpbaxiabwzfmo.supabase.co',
  );

  /// Supabase anon/public key
  /// Get this from your Supabase project settings → API → anon public key
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVyaWtmeGFncGJheGlhYnd6Zm1vIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTk5NDM3MzksImV4cCI6MjA3NTUxOTczOX0._Yx8pCYOr2v7ntoytboLGECfPLGf4_3AgzBwnMH-3Xc',
  );

  /// Deep link scheme for OAuth callbacks
  static const String deepLinkScheme = String.fromEnvironment(
    'DEEP_LINK_SCHEME',
    defaultValue: 'qudrisshopkeeper',
  );

  /// OAuth redirect URL
  static String get redirectUrl => '$deepLinkScheme://auth/callback';

  /// Validate configuration
  static bool get isConfigured {
    return supabaseUrl.contains('supabase.co') &&
        supabaseAnonKey != 'your-anon-key-here' &&
        supabaseAnonKey.isNotEmpty;
  }

  /// Get environment name
  static String get environment {
    if (const bool.fromEnvironment('dart.vm.product')) {
      return 'production';
    }
    return 'development';
  }
}
