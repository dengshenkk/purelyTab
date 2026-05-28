# PurelyTab 开发过程记录

## 2026-05-28 开发启动

### 项目概述
开发一个类似 AltTab 的 macOS 窗口切换应用，主要功能：
- 窗口枚举和预览
- 快捷键切换
- 多显示器支持
- 自定义主题和多语言

### 技术方案
基于 macOS 开发最佳实践，使用以下技术：
- Swift 5.5+
- SwiftUI + AppKit 混合开发
- CGWindow API 进行窗口枚举
- NSEvent 全局快捷键监听
- Sparkle 框架实现自动更新

### 开始实施
1. 创建项目基础结构 ✅
2. 实现核心窗口管理功能 ✅
3. 构建 UI 界面 ✅
4. 添加配置和辅助功能 ✅

### 已完成模块
- ✅ 项目基础结构（Package.swift, Info.plist, Entitlements）
- ✅ WindowManager - 窗口枚举和缩略图捕获
- ✅ HotkeyManager - 全局快捷键监听
- ✅ SettingsManager - 用户偏好设置
- ✅ WindowSwitcherView - 主界面 SwiftUI 视图
- ✅ SettingsView - 设置界面
- ✅ 多语言支持（英文/中文）
- ✅ 构建脚本（build.sh, release.sh）
- ✅ 项目文档（README, LICENSE, .gitignore）

### 下一步
5. 构建并测试应用
6. 上传到 GitHub 仓库
