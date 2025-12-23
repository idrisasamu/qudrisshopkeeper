# Platform Configuration for Supabase

This guide explains how to configure Android and iOS for Supabase authentication and deep linking.

## Android Configuration

### 1. Update `android/app/build.gradle.kts`

Add the deep link scheme to your `android` block:

```kotlin
android {
    // ... existing config ...
    
    defaultConfig {
        // ... existing config ...
        
        // Add deep link scheme for Supabase OAuth
        manifestPlaceholders["appAuthRedirectScheme"] = "qudrisshopkeeper"
    }
}
```

### 2. Update `android/app/src/main/AndroidManifest.xml`

Add intent filter for deep linking inside the `<activity>` tag with `android:name=".MainActivity"`:

```xml
<activity
    android:name=".MainActivity"
    android:exported="true"
    android:launchMode="singleTop"
    android:theme="@style/LaunchTheme"
    android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
    android:hardwareAccelerated="true"
    android:windowSoftInputMode="adjustResize">
    
    <!-- Existing meta-data and intent-filter ... -->
    
    <!-- Deep link for Supabase OAuth callback -->
    <intent-filter>
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.DEFAULT" />
        <category android:name="android.intent.category.BROWSABLE" />
        <!-- Accepts URIs that begin with "qudrisshopkeeper://auth" -->
        <data android:scheme="qudrisshopkeeper"
              android:host="auth" />
    </intent-filter>
</activity>
```

### 3. Update `android/app/build.gradle.kts` - Minimum SDK

Ensure minimum SDK is 21 or higher:

```kotlin
defaultConfig {
    minSdk = 21
    targetSdk = flutter.targetSdk
}
```

## iOS Configuration

### 1. Update `ios/Runner/Info.plist`

Add URL scheme for deep linking. Add this inside the `<dict>` tag:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>qudrisshopkeeper</string>
        </array>
        <key>CFBundleURLName</key>
        <string>com.qudris.shopkeeper</string>
    </dict>
</array>
```

### 2. Update `ios/Podfile`

Ensure platform is iOS 13 or higher:

```ruby
platform :ios, '13.0'
```

### 3. Update `ios/Runner/Info.plist` - Add OAuth Redirect

If using Google Sign-In, you may need to add Google's callback URL scheme. Check your Google Cloud Console for the exact value.

## Deep Link Testing

### Android
Test deep link from command line:

```bash
adb shell am start -W -a android.intent.action.VIEW \
  -d "qudrisshopkeeper://auth/callback?access_token=test" \
  com.qudris.shopkeeper
```

### iOS
Test from Safari by navigating to:

```
qudrisshopkeeper://auth/callback?access_token=test
```

## Supabase Dashboard Configuration

1. Go to your Supabase project dashboard
2. Navigate to **Authentication** → **URL Configuration**
3. Add the following redirect URLs:
   - `qudrisshopkeeper://auth/callback` (for mobile)
   - `http://localhost:3000/auth/callback` (for web development)

4. For Google OAuth:
   - Go to **Authentication** → **Providers** → **Google**
   - Enable Google provider
   - Add your Google Client ID and Secret from Google Cloud Console
   - Ensure redirect URI matches your Supabase project URL + `/auth/v1/callback`

## Environment Variables

Create a `.env` file in the project root (copy from `.env.example`):

```bash
SUPABASE_URL=https://your-project-ref.supabase.co
SUPABASE_ANON_KEY=your-anon-key-here
DEEP_LINK_SCHEME=qudrisshopkeeper
```

**IMPORTANT**: Add `.env` to your `.gitignore` to prevent committing secrets!

## Running with Environment Variables

### Flutter Run

```bash
flutter run --dart-define=SUPABASE_URL=https://your-project.supabase.co \
            --dart-define=SUPABASE_ANON_KEY=your-key
```

### Build Runner (Code Generation)

```bash
dart run build_runner build --delete-conflicting-outputs
```

## Troubleshooting

### Deep links not working on Android
- Check that `manifestPlaceholders` is set correctly
- Verify intent filter in AndroidManifest.xml
- Test with `adb shell am start` command

### Deep links not working on iOS
- Verify CFBundleURLSchemes in Info.plist
- Check that URL scheme matches exactly (case-sensitive)
- Test from Safari browser

### Auth callback not received
- Check Supabase dashboard redirect URLs
- Ensure deep link scheme matches between app and Supabase
- Check device logs for errors

### Google Sign-In issues
- Verify Google OAuth credentials in Google Cloud Console
- Check redirect URIs in both Google Console and Supabase
- Ensure SHA-1 fingerprint is registered (Android)

## Next Steps

After configuration:
1. Run `flutter pub get` to install dependencies
2. Run `dart run build_runner build --delete-conflicting-outputs` to generate code
3. Test authentication flows on both platforms
4. Deploy to TestFlight (iOS) or Internal Testing (Android) for real-device testing

