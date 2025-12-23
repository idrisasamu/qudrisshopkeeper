# Google Sign-In Setup Instructions

## Android Setup

1. **Generate SHA-1 fingerprint:**
   ```bash
   ./gradlew signingReport
   ```
   Copy the SHA1 value from the "debug" variant.

2. **Google Cloud Console Setup:**
   - Go to [Google Cloud Console](https://console.cloud.google.com/)
   - Create a new project or select existing one
   - Enable the Google Sign-In API
   - Go to "APIs & Services" → "Credentials"
   - Create "OAuth 2.0 Client IDs"
   - Select "Android" as application type
   - Package name: `com.example.qudris_shopkeeper` (replace with your actual package name)
   - SHA-1: Paste the SHA1 from step 1

3. **Update android/app/build.gradle:**
   Ensure `minSdkVersion` is at least 21:
   ```gradle
   android {
       compileSdkVersion 34
       defaultConfig {
           minSdkVersion 21  // Ensure this is >= 21
           // ... other config
       }
   }
   ```

## iOS Setup

1. **Set Bundle Identifier:**
   - In Xcode, set Bundle Identifier (e.g., `com.example.qudris_shopkeeper`)

2. **Google Cloud Console Setup:**
   - In the same project, create another OAuth 2.0 Client ID
   - Select "iOS" as application type
   - Bundle ID: Use the same bundle identifier from step 1

3. **Update OAuth Client IDs:**
   - Copy the iOS Client ID from Google Cloud Console
   - Open `lib/common/oauth_ids.dart`
   - Replace `YOUR_IOS_CLIENT_ID_HERE.apps.googleusercontent.com` with your actual iOS Client ID

## Testing

1. **Fresh Install Test:**
   - Uninstall app from device/emulator
   - Install and run app
   - Should show Sign-In page with "Continue with Google" button

2. **Sign-In Flow Test:**
   - Tap "Continue with Google"
   - Google account chooser should appear
   - Select account → should navigate to Admin Dashboard

3. **Session Persistence Test:**
   - Close and reopen app
   - Should go directly to Admin Dashboard (no sign-in required)

4. **Sign-Out Test:**
   - Tap menu (three dots) in Admin Dashboard
   - Select "Sign out"
   - Should return to Sign-In page

## Troubleshooting

- **"Sign-in failed"**: Check SHA-1 fingerprint matches Google Cloud Console
- **"Couldn't sign in"**: Verify package name matches in Google Cloud Console
- **App crashes on sign-in**: Ensure minSdkVersion >= 21 in build.gradle

## Next Phase

This implementation is Phase 1 only. Future phases will add:
- Google Drive integration
- Sales user authentication
- Shop setup with Drive file storage
