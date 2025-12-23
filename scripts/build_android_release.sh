#!/usr/bin/env bash
set -e

echo "🧹 Cleaning previous build..."
flutter clean

echo "📦 Getting dependencies..."
flutter pub get

echo "🎨 Generating launcher icons..."
flutter pub run flutter_launcher_icons

echo "🚀 Generating splash screen..."
flutter pub run flutter_native_splash:create

echo "🏗️  Building release AAB..."
flutter build appbundle --release

echo "✅ Build complete!"
echo "📱 Output: build/app/outputs/bundle/release/app-release.aab"

