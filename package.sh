#!/bin/bash

VERSION="1.2.2"
APP_NAME="PurelyTab"
DMG_NAME="${APP_NAME}-${VERSION}.dmg"

echo "📦 正在打包 ${APP_NAME} v${VERSION}"

# 构建
swift build -c release 2>&1

# 创建完整的应用包
rm -rf build/${APP_NAME}.app
mkdir -p build/${APP_NAME}.app/Contents/MacOS
mkdir -p build/${APP_NAME}.app/Contents/Resources

# 复制可执行文件
cp .build/release/${APP_NAME} build/${APP_NAME}.app/Contents/MacOS/

# 复制图标
if [ -f PurelyTab.icns ]; then
    cp PurelyTab.icns build/${APP_NAME}.app/Contents/Resources/
fi

# 创建 Info.plist
cat > build/${APP_NAME}.app/Contents/Info.plist << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>com.purelytab.app</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleVersion</key>
    <string>${VERSION}</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>LSMinimumSystemVersion</key>
    <string>12.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>CFBundleIconFile</key>
    <string>PurelyTab</string>
    <key>NSHighResolutionProcessCapable</key>
    <true/>
</dict>
</plist>
PLIST

# 创建 Entitlements
cat > build/${APP_NAME}.app/Contents/Entitlements.plist << ENT
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <false/>
    <key>com.apple.security.automation.apple-events</key>
    <true/>
    <key>com.apple.security.cs.allow-unsigned-executable-memory</key>
    <true/>
    <key>com.apple.security.cs.disable-library-validation</key>
    <true/>
</dict>
</plist>
ENT

# 复制本地化文件
cp -R Resources/en.lproj build/${APP_NAME}.app/Contents/Resources/ 2>/dev/null || true
cp -R Resources/zh_CN.lproj build/${APP_NAME}.app/Contents/Resources/ 2>/dev/null || true

echo "✅ 应用包创建完成: build/${APP_NAME}.app"

# 创建 DMG
echo "📦 创建 DMG..."
rm -f build/${DMG_NAME}

# 创建临时目录
rm -rf /tmp/${APP_NAME}_dmg
mkdir -p /tmp/${APP_NAME}_dmg
cp -R build/${APP_NAME}.app /tmp/${APP_NAME}_dmg/

# 创建符号链接到 Applications
ln -s /Applications /tmp/${APP_NAME}_dmg/Applications

# 创建 DMG
hdiutil create -volname "${APP_NAME}" \
    -srcfolder /tmp/${APP_NAME}_dmg \
    -ov -format UDZO \
    "build/${DMG_NAME}"

# 清理
rm -rf /tmp/${APP_NAME}_dmg

echo "✅ DMG 创建完成: build/${DMG_NAME}"
echo ""
echo "文件大小:"
ls -lh build/${DMG_NAME}
