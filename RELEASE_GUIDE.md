# Android Release Build Guide

## Prerequisites

Before building a release version, you need to create a signing keystore.

### 1. Generate Keystore

```bash
keytool -genkey -v -keystore ~/release.keystore -keyalg RSA -keysize 2048 -validity 10000 -alias qudris
```

Follow the prompts to set:
- Password for the keystore
- Your name, organization, etc.
- Password for the key alias (can be same as keystore password)

### 2. Configure Signing

Copy the sample key properties:
```bash
cp android/key.properties.sample android/key.properties
```

Edit `android/key.properties` with your actual values:
```properties
storeFile=../release.keystore
storePassword=YOUR_KEYSTORE_PASSWORD
keyAlias=qudris
keyPassword=YOUR_KEY_PASSWORD
```

**⚠️ IMPORTANT: Never commit `android/key.properties` or `*.keystore` files to git!**

## Building Release

### Option 1: Using the Build Script

```bash
./scripts/build_android_release.sh
```

### Option 2: Manual Build

```bash
# Clean previous build
flutter clean

# Get dependencies
flutter pub get

# Generate icons and splash
flutter pub run flutter_launcher_icons
flutter pub run flutter_native_splash:create

# Build AAB (recommended for Play Store)
flutter build appbundle --release

# Or build APK (for direct distribution)
flutter build apk --release
```

## Output Files

- **AAB**: `build/app/outputs/bundle/release/app-release.aab` (Upload to Play Store)
- **APK**: `build/app/outputs/flutter-apk/app-release.apk` (Direct install)

## App Configuration

- **Package Name**: `com.qudris.shopkeeper`
- **App Name**: Qudris Shopkeeper
- **Version**: Defined in `pubspec.yaml` (currently 1.0.0+1)
- **Min SDK**: 21 (Android 5.0)
- **Target SDK**: 34 (Android 14)

## Release Checklist

Before uploading to Play Store:

- [ ] Update version in `pubspec.yaml`
- [ ] Test the release build on a real device
- [ ] Verify app icon and splash screen
- [ ] Test all critical features
- [ ] Check ProGuard doesn't break functionality
- [ ] Verify Supabase connection works
- [ ] Test camera/barcode scanning
- [ ] Review permissions in AndroidManifest.xml
- [ ] Prepare store listing (screenshots, description, etc.)

## Troubleshooting

### Build Fails with Signing Error
- Verify `android/key.properties` exists and has correct paths
- Check keystore password is correct
- Ensure keystore file path is relative to `android/` directory

### App Crashes in Release
- Check ProGuard rules in `android/app/proguard-rules.pro`
- Add keep rules for any classes that use reflection
- Test with `flutter run --release` before building AAB

### R8/ProGuard Issues
- Review crash logs in Play Console
- Add specific keep rules for problematic classes
- Consider disabling minification temporarily for debugging

## Version Management

Update version in `pubspec.yaml`:
```yaml
version: 1.0.1+2  # <versionName>+<versionCode>
```

- **versionName** (1.0.1): User-visible version
- **versionCode** (2): Internal version number (must increment)

## Security Notes

1. **Never commit**:
   - `android/key.properties`
   - `*.keystore` or `*.jks` files
   - Any passwords or secrets

2. **Backup your keystore**:
   - Store in a secure location
   - If lost, you cannot update your app on Play Store

3. **Keep passwords secure**:
   - Use a password manager
   - Don't share keystore credentials

## Play Store Upload

1. Go to [Google Play Console](https://play.google.com/console)
2. Create a new app or select existing
3. Navigate to Release → Production
4. Create new release
5. Upload `app-release.aab`
6. Fill in release notes
7. Review and roll out

## Additional Resources

- [Flutter Deployment Guide](https://docs.flutter.dev/deployment/android)
- [Android App Signing](https://developer.android.com/studio/publish/app-signing)
- [Play Console Help](https://support.google.com/googleplay/android-developer)

