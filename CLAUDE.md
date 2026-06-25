# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

PurelyTab 是一个 macOS 窗口切换工具，替代系统原生的 ⌘+Tab，支持显示所有应用窗口、同应用多窗口切换、最小化窗口识别等功能。

## 构建命令

```bash
# 开发构建
swift build

# Release 构建
swift build -c release

# 完整打包（生成 .app 和 .dmg）
./package.sh

# 简单构建（仅生成 .app）
./build.sh release
```

## 核心架构

### 数据流
```
用户按下 ⌘+Tab
    ↓
HotkeyManager (Carbon HotKey API 拦截)
    ↓
AppDelegate.showWindowSwitcher()
    ↓
WindowManager.updateWindowList() (获取窗口列表)
    ↓
创建 SwiftUI View → 显示 NSPanel
    ↓
用户松开 ⌘ → WindowManager.activateWindow()
```

### 关键组件

| 文件 | 职责 |
|------|------|
| `AppDelegate.swift` | 应用生命周期、状态栏、面板创建/销毁、窗口选择逻辑 |
| `WindowManager.swift` | 窗口枚举（CGWindowListCopyWindowInfo）、AXUIElement 获取窗口标题、窗口激活 |
| `HotkeyManager.swift` | Carbon HotKey 注册 ⌘+Tab、CGEventTap 处理其他按键（`、Escape、Return） |
| `SettingsManager.swift` | UserDefaults 持久化用户设置 |
| `WindowSwitcherView.swift` | SwiftUI 列表视图，接收选择通知更新 UI |

### 性能关键点

- `WindowManager.updateWindowList()` 有 2 秒缓存，避免频繁调用 CGWindowListCopyWindowInfo
- `buildAXTitleCache()` 遍历所有应用的 AXUIElement，是性能瓶颈
- `getMinimizedWindows()` 只检查前 10 个应用，避免遍历全部

### 权限要求

- **辅助功能权限**：用于 CGEventTap 拦截全局键盘事件、AXUIElement 获取窗口信息
- Entitlements 中 `com.apple.security.automation.apple-events = true`

## 调试

```bash
# 运行并查看日志
swift build && .build/debug/PurelyTab

# 日志会输出到控制台（print 语句）
# 关键日志点：
# - "Carbon hotkey registered successfully" - 快捷键注册成功
# - "Event tap created successfully" - 事件拦截创建成功
# - "Key pressed: keyCode=..." - 按键事件
```

## 发布流程

参考 `RELEASE.md`，主要步骤：
1. 更新 `package.sh` 中的 VERSION
2. 运行 `./package.sh` 生成 DMG
3. 创建 GitHub Release
