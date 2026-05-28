#!/bin/bash

# PurelyTab Build Script
# Usage: ./build.sh [release|debug]

set -e

CONFIGURATION=${1:-release}
SCHEME="PurelyTab"
PRODUCT_NAME="PurelyTab"
BUNDLE_ID="com.purelytab.app"

echo "🔨 Building PurelyTab ($CONFIGURATION)..."

# Clean build folder
echo "Cleaning..."
rm -rf build/

# Build using Swift Package Manager
echo "Building..."
if [ "$CONFIGURATION" = "release" ]; then
    swift build -c release
    BUILD_PATH=".build/release"
else
    swift build -c debug
    BUILD_PATH=".build/debug"
fi

# Create app bundle
APP_PATH="build/$PRODUCT_NAME.app"
echo "Creating app bundle at $APP_PATH..."

mkdir -p "$APP_PATH/Contents/MacOS"
mkdir -p "$APP_PATH/Contents/Resources"

# Copy executable
cp "$BUILD_PATH/$PRODUCT_NAME" "$APP_PATH/Contents/MacOS/$PRODUCT_NAME"

# Copy Info.plist
cp Resources/Info.plist "$APP_PATH/Contents/Info.plist"

# Copy entitlements
cp Resources/Entitlements.plist "$APP_PATH/Contents/Entitlements.plist"

# Copy localization files
cp -R Resources/en.lproj "$APP_PATH/Contents/Resources/"
cp -R Resources/zh_CN.lproj "$APP_PATH/Contents/Resources/"

# Create app icon (placeholder)
echo "Creating app icon..."
# Note: In production, you'd use a real .icns file
# For now, we'll skip icon creation

# Sign the app (required for distribution)
echo "Signing app..."
codesign --force --deep --sign - "$APP_PATH"

# Calculate app size
APP_SIZE=$(du -sh "$APP_PATH" | cut -f1)

echo ""
echo "✅ Build completed successfully!"
echo "   App: $APP_PATH"
echo "   Size: $APP_SIZE"
echo ""

# Optional: Create DMG
if [ "$2" = "dmg" ]; then
    echo "📦 Creating DMG..."
    DMG_NAME="$PRODUCT_NAME.dmg"
    hdiutil create -volname "$PRODUCT_NAME" -srcfolder "$APP_PATH" -ov -format UDZO "$DMG_NAME"
    echo "   DMG: $DMG_NAME"
fi

echo "Done!"
