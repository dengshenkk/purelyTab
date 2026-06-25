#!/bin/bash

# PurelyTab Build Script
# Usage: ./build.sh [release|debug] [dmg]

set -e

CONFIGURATION=${1:-release}
PRODUCT_NAME="PurelyTab"

echo "🔨 Building PurelyTab ($CONFIGURATION)..."

# Clean
echo "Cleaning..."
rm -rf build/

# Build
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

cp "$BUILD_PATH/$PRODUCT_NAME"      "$APP_PATH/Contents/MacOS/$PRODUCT_NAME"
cp Resources/Info.plist              "$APP_PATH/Contents/Info.plist"
cp -R Resources/en.lproj             "$APP_PATH/Contents/Resources/"
cp -R Resources/zh_CN.lproj          "$APP_PATH/Contents/Resources/"

# App icon
if [ -f "PurelyTab.icns" ]; then
    cp PurelyTab.icns "$APP_PATH/Contents/Resources/AppIcon.icns"
fi

# ── 签名（带 entitlements，这是 CGEventTap / AX 权限生效的关键） ──
echo "Signing app with entitlements..."
codesign --force --deep \
    --sign - \
    --entitlements Resources/Entitlements.plist \
    --options runtime \
    "$APP_PATH"

# 验证签名
echo "Verifying signature..."
codesign --verify --verbose "$APP_PATH" && echo "✅ Signature OK"

APP_SIZE=$(du -sh "$APP_PATH" | cut -f1)
echo ""
echo "✅ Build completed!"
echo "   App:  $APP_PATH  ($APP_SIZE)"
echo ""

# DMG
if [ "$2" = "dmg" ] || [ "$1" = "dmg" ]; then
    DMG_NAME="${PRODUCT_NAME}.dmg"
    echo "📦 Creating DMG: $DMG_NAME ..."

    # 创建临时目录，加 Applications 软链接，方便用户拖入安装
    TMP_DIR="build/dmg_tmp"
    rm -rf "$TMP_DIR"
    mkdir -p "$TMP_DIR"
    cp -R "$APP_PATH" "$TMP_DIR/"
    ln -s /Applications "$TMP_DIR/Applications"

    hdiutil create \
        -volname "$PRODUCT_NAME" \
        -srcfolder "$TMP_DIR" \
        -ov \
        -format UDZO \
        "$DMG_NAME"

    rm -rf "$TMP_DIR"
    DMG_SIZE=$(du -sh "$DMG_NAME" | cut -f1)
    echo "   DMG: $DMG_NAME  ($DMG_SIZE)"
fi

echo "Done!"
