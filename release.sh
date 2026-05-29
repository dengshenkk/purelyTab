#!/bin/bash

# PurelyTab Release Script
# Creates a signed and notarized release build

set -e

VERSION="1.2.0"
APP_NAME="PurelyTab"
DMG_NAME="${APP_NAME}-${VERSION}.dmg"

echo "🚀 Preparing release build for $APP_NAME v$VERSION"

# Build the app
./build.sh release

# Create DMG for distribution
echo "📦 Creating DMG..."
hdiutil create -volname "$APP_NAME" -srcfolder "build/$APP_NAME.app" -ov -format UDZO "build/$DMG_NAME"

echo ""
echo "✅ Release build ready!"
echo "   DMG: build/$DMG_NAME"
echo ""
echo "Next steps:"
echo "1. Sign the DMG with your developer certificate"
echo "2. Submit for notarization"
echo "3. Upload to GitHub Releases"
