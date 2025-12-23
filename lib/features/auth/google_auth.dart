import 'package:google_sign_in/google_sign_in.dart';

/// Google User model for our app
class GoogleUser {
  final String id;
  final String email;
  final String? displayName;
  final String? photoUrl;

  const GoogleUser({
    required this.id,
    required this.email,
    this.displayName,
    this.photoUrl,
  });

  factory GoogleUser.fromGoogleSignInAccount(GoogleSignInAccount account) {
    return GoogleUser(
      id: account.id,
      email: account.email,
      displayName: account.displayName,
      photoUrl: account.photoUrl,
    );
  }
}

/// Google Authentication Service
class GoogleAuthService {
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    // Drive scope for file access - using drive.file for app-specific files
    scopes: const [
      'email',
      'profile',
      'https://www.googleapis.com/auth/drive.file',
    ],
  );

  /// Get the shared GoogleSignIn instance
  static GoogleSignIn get googleSignIn => _googleSignIn;

  /// Sign in with Google
  /// Returns null if user cancels or sign-in fails
  Future<GoogleUser?> signIn() async {
    try {
      final GoogleSignInAccount? account = await _googleSignIn.signIn();
      if (account == null) {
        return null; // User cancelled
      }

      return GoogleUser.fromGoogleSignInAccount(account);
    } catch (e) {
      print('Google Sign-In error: $e');
      return null;
    }
  }

  /// Sign out from Google
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (e) {
      print('Google Sign-Out error: $e');
    }
  }

  /// Get current signed-in user (cached)
  Future<GoogleUser?> currentUser() async {
    try {
      final GoogleSignInAccount? account = await _googleSignIn.signInSilently();
      if (account == null) {
        return null;
      }

      return GoogleUser.fromGoogleSignInAccount(account);
    } catch (e) {
      print('Get current user error: $e');
      return null;
    }
  }

  /// Check if user is currently signed in
  Future<bool> isSignedIn() async {
    try {
      return await _googleSignIn.isSignedIn();
    } catch (e) {
      print('Check sign-in status error: $e');
      return false;
    }
  }

  /// Ensure Drive scope is available, requesting it incrementally if needed
  Future<GoogleUser?> ensureDriveScope() async {
    try {
      print(
        'DEBUG: GoogleAuthService.ensureDriveScope() - checking current scopes',
      );

      // First try silent sign-in to get current user
      var account = await _googleSignIn.signInSilently();
      print('DEBUG: Silent sign-in result: ${account?.email ?? "null"}');

      // If not signed in at all, do a normal sign-in (will prompt including Drive)
      if (account == null) {
        print(
          'DEBUG: No silent sign-in, requesting full sign-in with Drive scope',
        );
        account = await _googleSignIn.signIn();
        if (account == null) {
          print('DEBUG: User cancelled sign-in');
          return null;
        }
      }

      // Check if we have the Drive scope by trying to get auth headers
      // If we don't have Drive scope, the API calls will fail
      try {
        final authHeaders = await account.authHeaders;
        if (authHeaders == null) {
          print('DEBUG: No auth headers available');
          return null;
        }
        print('DEBUG: Auth headers available, Drive scope should be present');
      } catch (e) {
        print('DEBUG: Auth headers failed, requesting Drive scope: $e');
        final granted = await _googleSignIn.requestScopes([
          'https://www.googleapis.com/auth/drive.file',
        ]);

        if (!granted) {
          print('DEBUG: User denied Drive scope request');
          return null;
        }

        print('DEBUG: Drive scope granted successfully');
      }

      return GoogleUser.fromGoogleSignInAccount(account);
    } catch (e) {
      print('DEBUG: GoogleAuthService.ensureDriveScope() - error: $e');
      return null;
    }
  }
}
