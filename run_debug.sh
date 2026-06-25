#!/bin/bash
# 开发用：编译 debug 版，签名后运行，自动退出旧实例
set -e

cd "$(dirname "$0")"

echo "🔨 Building debug..."
swift build -c debug 2>&1

echo "✍️  Signing..."
codesign --force --deep \
  --sign - \
  --entitlements Resources/Entitlements.plist \
  --options runtime \
  .build/debug/PurelyTab

echo "🔄 Killing existing instances..."
# 用二进制路径精确 kill，而不是进程名（进程名可能匹配到 DMG 版）
pkill -f "PurelyTab" 2>/dev/null || true
sleep 0.5

# 确认签名和权限
echo "📋 Signature:"
codesign -dvv .build/debug/PurelyTab 2>&1 | grep -E "Identifier|TeamIdentifier|Flags"

echo ""
echo "🚀 Launching PurelyTab (debug)"
echo "--- 按 Ctrl+C 退出 ---"
echo ""
.build/debug/PurelyTab
