import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_client.dart';

/// Authentication service for Supabase
class AuthService {
  final SupabaseClient _client = SupabaseService.client;

  /// Sign in with email and password
  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user != null) {
        await _ensureProfile(response.user!);
      }

      return response;
    } catch (e) {
      debugPrint('Sign in error: $e');
      rethrow;
    }
  }

  /// Sign up with email and password
  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    String? fullName,
    String? emailRedirectTo,
  }) async {
    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
        data: {if (fullName != null) 'full_name': fullName},
        emailRedirectTo: emailRedirectTo ?? _getEmailRedirectUrl(),
      );

      return response;
    } catch (e) {
      debugPrint('Sign up error: $e');
      rethrow;
    }
  }

  /// Get email redirect URL for email confirmation links
  String _getEmailRedirectUrl() {
    // For web, use the Vercel deployment URL or localhost for dev
    if (kIsWeb) {
      const productionUrl = 'https://qudrisshopkeeper.vercel.app';
      const isProduction = bool.fromEnvironment('dart.vm.product');
      if (isProduction) {
        return productionUrl;
      } else {
        return '${Uri.base.origin}/auth/callback';
      }
    } else {
      // For mobile, use deep link
      return 'qudrisshopkeeper://auth/callback';
    }
  }

  /// Sign in with Google OAuth
  Future<bool> signInWithGoogle() async {
    try {
      final response = await _client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: _getRedirectUrl(),
      );

      return response;
    } catch (e) {
      debugPrint('Google sign in error: $e');
      rethrow;
    }
  }

  /// Send magic link to email
  Future<void> signInWithMagicLink({required String email}) async {
    try {
      await _client.auth.signInWithOtp(
        email: email,
        emailRedirectTo: _getRedirectUrl(),
      );
    } catch (e) {
      debugPrint('Magic link error: $e');
      rethrow;
    }
  }

  /// Verify OTP
  Future<AuthResponse> verifyOtp({
    required String email,
    required String token,
  }) async {
    try {
      final response = await _client.auth.verifyOTP(
        type: OtpType.email,
        email: email,
        token: token,
      );

      if (response.user != null) {
        await _ensureProfile(response.user!);
      }

      return response;
    } catch (e) {
      debugPrint('OTP verification error: $e');
      rethrow;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } catch (e) {
      debugPrint('Sign out error: $e');
      rethrow;
    }
  }

  /// Reset password
  Future<void> resetPassword({required String email}) async {
    try {
      await _client.auth.resetPasswordForEmail(
        email,
        redirectTo: _getRedirectUrl(),
      );
    } catch (e) {
      debugPrint('Reset password error: $e');
      rethrow;
    }
  }

  /// Update password
  Future<UserResponse> updatePassword({required String newPassword}) async {
    try {
      final response = await _client.auth.updateUser(
        UserAttributes(password: newPassword),
      );
      return response;
    } catch (e) {
      debugPrint('Update password error: $e');
      rethrow;
    }
  }

  /// Get current user
  User? get currentUser => _client.auth.currentUser;

  /// Get current session
  Session? get currentSession => _client.auth.currentSession;

  /// Check if user is authenticated
  bool get isAuthenticated => currentUser != null;

  /// Stream of auth state changes
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  /// Refresh session
  Future<AuthResponse> refreshSession() async {
    try {
      final response = await _client.auth.refreshSession();
      return response;
    } catch (e) {
      debugPrint('Refresh session error: $e');
      rethrow;
    }
  }

  /// Ensure user profile exists
  Future<void> _ensureProfile(User user) async {
    try {
      // Check if profile exists
      final response = await _client
          .from('profiles')
          .select('id')
          .eq('id', user.id)
          .maybeSingle();

      if (response == null) {
        // Profile doesn't exist, create it
        await _client.from('profiles').insert({
          'id': user.id,
          'email': user.email,
          'full_name':
              user.userMetadata?['full_name'] ?? user.userMetadata?['name'],
          'avatar_url': user.userMetadata?['avatar_url'],
        });

        debugPrint('Created profile for user ${user.id}');
      }
    } catch (e) {
      debugPrint('Error ensuring profile: $e');
      // Don't rethrow - profile creation is not critical
    }
  }

  /// Get redirect URL for OAuth and magic links
  String _getRedirectUrl() {
    // For production, use your app's deep link scheme
    // For development, you can use localhost
    if (kIsWeb) {
      return '${Uri.base.origin}/auth/callback';
    } else {
      // Deep link format: qudrisshopkeeper://auth/callback
      return 'qudrisshopkeeper://auth/callback';
    }
  }

  /// Handle deep link callback (for OAuth/Magic Link)
  Future<void> handleDeepLink(Uri uri) async {
    try {
      // Extract token from URI
      final params = uri.queryParameters;

      if (params.containsKey('access_token')) {
        // This is handled automatically by Supabase
        debugPrint('Deep link auth successful');
      } else if (params.containsKey('error')) {
        throw Exception(params['error_description'] ?? 'Auth error');
      }
    } catch (e) {
      debugPrint('Deep link error: $e');
      rethrow;
    }
  }
}
