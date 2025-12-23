/// OAuth Client IDs for Google Sign-In
///
/// DEVELOPER SETUP REQUIRED:
/// 1. Android: Generate SHA-1 fingerprint using: ./gradlew signingReport (module: app)
/// 2. Go to Google Cloud Console -> APIs & Services -> Credentials
/// 3. Create OAuth 2.0 Client IDs for Android and iOS
/// 4. Replace the placeholder values below with your actual client IDs

class OAuthIds {
  // iOS OAuth Client ID (from Google Cloud Console)
  // Replace with your actual iOS client ID
  static const String iosClientId =
      'YOUR_IOS_CLIENT_ID_HERE.apps.googleusercontent.com';

  // Optional: Server client ID (if you need it for backend verification later)
  // static const String serverClientId = 'YOUR_SERVER_CLIENT_ID_HERE.apps.googleusercontent.com';

  // Android uses the default client ID from google-services.json (when we add Firebase later)
  // For now, we'll use the package name-based discovery
}
