# PurelyTab 任务清单

## 新任务

- [x] 1. 排除菜单栏上的应用以及没有窗口的应用
- [x] 2. cmd+tab(cmd+`)打开列表时默认选中当前窗口项
- [x] 3. cmd+tab(cmd+`)打开窗口后按`可以切换到下一个窗口直到循环到第一个窗口
- [x] 4. 选定窗口后快速打开该窗口, 不要有卡顿或者性能问题
- [x] 5. 提供配置选项来配置快捷键, 默认是cmd+tab(cmd+`)
- [x] 6. 提供配置选项来隐藏菜单栏图标

## 最小化窗口支持

- [x] 1. 在 WindowInfo 结构体中添加 isMinimized 属性
- [x] 2. 修改 updateWindowList 获取最小化窗口（修改 CGWindowListOption）
- [x] 3. 使用 Accessibility API 获取最小化窗口信息
- [x] 4. 修改 activateWindow 方法支持拉起最小化窗口
- [x] 5. 在 UI 中显示最小化状态标识

## 状态：已完成 ✅

---

**完成时间**: 2026-05-29
