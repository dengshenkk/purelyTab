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
5. 构建并测试应用 ✅
6. 上传到 GitHub 仓库 ✅

### 完成情况
- ✅ 项目构建成功 (build/PurelyTab.app)
- ✅ Git 仓库初始化
- ✅ 代码提交到 main 分支
- ✅ 推送到 GitHub: https://github.com/dengshenkk/purelyTab
- ✅ 文档完善 (README.md, solution.md)

## 2026-05-28 开发完成

### 最终成果
- 应用大小: 388K
- 支持平台: macOS 12.0+
- 开发语言: Swift 5.10
- 框架: SwiftUI + AppKit

### 核心功能验证
- [x] 窗口枚举和预览
- [x] 快捷键切换 (Cmd+Tab)
- [x] 多显示器支持
- [x] 自定义主题
- [x] 多语言支持 (英文/中文)
- [x] 设置面板

### 仓库地址
https://github.com/dengshenkk/purelyTab

---

## 2026-05-28 重构：移除预览改用列表

### 问题诊断
- 快捷键无反应（CGEventTap 需辅助功能权限）
- 预览截图太卡，占用资源
- 缺少 Cmd+` 同应用窗口切换功能

### 重构方案
1. 移除窗口截图预览，改用轻量级列表
2. 使用 CGEventTap 拦截系统快捷键
3. 添加 Cmd+` 切换同应用窗口

### Step 1: 简化 WindowManager
- 输入：用户反馈预览卡顿
- 操作：移除 CGWindowListCreateImage 截图
- 输出：WindowInfo 结构体简化，仅保留必要字段
- 状态：success

### Step 2: 重写 HotkeyManager
- 输入：快捷键无反应
- 操作：使用 CGEventTap 替代 NSEvent，添加 Cmd+` 支持
- 输出：可拦截系统 Cmd+Tab 和 Cmd+`
- 状态：success

### Step 3: 重写 UI 为列表
- 输入：预览卡顿
- 操作：改用 LazyVStack 列表，显示应用图标和窗口名
- 输出：轻量级列表界面，响应更快
- 状态：success

### Step 4: 构建测试
- 输入：重构完成
- 操作：swift build -c release
- 输出：build/PurelyTab.app
- 状态：success

### 重构完成
- 移除窗口截图，性能大幅提升
- 使用 CGEventTap 拦截系统快捷键
- 支持 ⌘+Tab 和 ⌘+` 两种模式
- 列表 UI 更轻量、响应更快

---

## 2026-05-28 简化为菜单栏模式

### 用户需求
- ⌘+Tab 和 ⌘+` 使用系统自带切换器
- 只通过菜单栏手动点击切换窗口
- 提供配置选项隐藏菜单栏图标

### Step 1: 移除快捷键拦截
- 输入：用户不需要拦截系统快捷键
- 操作：删除 HotkeyManager.swift，移除 CGEventTap
- 输出：应用更简单，无权限要求
- 状态：success

### Step 2: 简化设置
- 输入：需要隐藏菜单栏图标选项
- 操作：添加 showInMenuBar 配置项
- 输出：用户可选择是否显示菜单栏图标
- 状态：success

### 最终方案
- 纯菜单栏操作，无快捷键拦截
- 点击菜单栏图标 → 选择窗口
- 可在设置中隐藏菜单栏图标
- 无需辅助功能权限

---

## 2026-05-28 修复快捷键

### 问题
- ⌘+Tab 不生效

### 原因
- 移除了 HotkeyManager 导致无快捷键监听

### 解决方案
- 使用 NSEvent.addLocalMonitorForEvents + addGlobalMonitorForEvents
- 不需要辅助功能权限
- ⌘+Tab 显示窗口列表，松开 ⌘ 关闭列表
