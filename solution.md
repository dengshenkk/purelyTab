# PurelyTab 开发方案

## 项目概述

PurelyTab 是一款轻量的 macOS 窗口切换辅助工具，通过菜单栏提供窗口列表切换功能。

## 使用方式

### 系统快捷键（原生）
- **⌘ + Tab**：使用系统自带的窗口切换
- **⌘ + `**：使用系统自带的同应用窗口切换

### PurelyTab 功能
- 点击菜单栏图标 → 选择窗口进行切换
- 支持切换所有窗口或同应用窗口

## 技术架构

### 开发环境
- **语言**: Swift 5.10
- **最低版本**: macOS 12.0+
- **框架**: SwiftUI + AppKit

### 核心模块

#### 1. WindowManager（窗口管理器）
- 使用 CGWindowListCopyWindowInfo 枚举窗口
- 不使用截图，仅获取窗口基本信息
- 按应用分组窗口

#### 2. UI 组件
- **WindowSwitcherView**: 列表式窗口切换界面
- **SettingsView**: 设置面板（隐藏菜单栏图标）

## 配置选项

| 选项 | 说明 |
|------|------|
| 显示菜单栏图标 | 关闭后菜单栏不显示图标，需重启应用恢复 |

## 项目结构

```
purelyTab/
├── Sources/
│   ├── PurelyTabApp.swift      # 应用入口
│   ├── AppDelegate.swift       # 应用代理
│   ├── WindowManager.swift     # 窗口管理
│   ├── SettingsManager.swift   # 设置管理
│   └── UI/
│       ├── WindowSwitcherView.swift
│       └── SettingsView.swift
├── Resources/
│   ├── Info.plist
│   └── Entitlements.plist
├── Package.swift
├── build.sh
├── process.md
├── state.json
├── checklist.md
└── solution.md
```

## 构建命令

```bash
swift build -c release
open build/PurelyTab.app
```

## 特点

1. **轻量** - 无截图、无快捷键拦截，资源占用极低
2. **无权限** - 不需要辅助功能权限
3. **简洁** - 纯菜单栏操作，不打扰系统快捷键

## GitHub 仓库

https://github.com/dengshenkk/purelyTab

---

**最后更新**: 2026-05-28

---

## 最小化窗口支持功能 (2026-05-29)

### 功能说明
支持在窗口列表中显示最小化窗口，切换时自动拉起并激活该窗口。

### 实现要点

#### 1. 数据结构
在 `WindowInfo` 中添加 `isMinimized: Bool` 属性标识最小化状态。

#### 2. 获取最小化窗口
使用 Accessibility API 获取最小化窗口：
- `AXUIElementCreateApplication(pid)` 获取应用
- `kAXWindowsAttribute` 获取所有窗口
- `kAXMinimizedAttribute` 判断是否最小化

#### 3. 拉起最小化窗口
```swift
// 取消最小化
AXUIElementSetAttributeValue(axWindow, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
usleep(100000) // 等待恢复

// 激活窗口
AXUIElementPerformAction(axWindow, kAXRaiseAction as CFString)
```

#### 4. UI 显示
最小化窗口右侧显示 `minus.circle` 图标标识。

### 权限要求
- 需要辅助功能（Accessibility）权限
- 用户首次使用时可能需要授权

### 测试方法
1. 最小化一个窗口
2. 点击菜单栏 PurelyTab 图标
3. 确认最小化窗口显示在列表中（带 minus 图标）
4. 点击该窗口，确认自动拉起并激活