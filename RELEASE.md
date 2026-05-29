# PurelyTab 发布规则

## 📋 版本号规范

采用语义化版本（Semantic Versioning）：

```
主版本号.次版本号.修订版本号
  Major   Minor   Patch
```

| 类型 | 说明 | 示例 |
|------|------|------|
| **主版本 (Major)** | 重大功能变更、不兼容的 API 修改 | 1.0.0 → 2.0.0 |
| **次版本 (Minor)** | 新增功能、向后兼容 | 1.0.0 → 1.1.0 |
| **修订版本 (Patch)** | Bug 修复、小改动 | 1.0.0 → 1.0.1 |

## 🚀 发布流程（必须遵守）

### Step 1: 更新版本号
```bash
# 更新以下文件中的 VERSION：
# - package.sh
# - release.sh
VERSION="1.2.0"  # 改为新版本号
```

### Step 2: 提交版本更新
```bash
git add package.sh release.sh
git commit -m "chore: bump version to vX.Y.Z"
git push origin main
```

### Step 3: 创建 Release 分支
```bash
git checkout -b release/X.Y.Z
```

### Step 4: 在 Release 分支打包
```bash
./package.sh
```

### Step 5: 创建 Git Tag
```bash
git tag -a vX.Y.Z -m "vX.Y.Z: 简短描述主要变更"
git push origin vX.Y.Z
```

### Step 6: 创建 GitHub Release
```bash
gh release create vX.Y.Z ./build/PurelyTab-X.Y.Z.dmg \
  --title "vX.Y.Z: 标题" \
  --notes "## 更新内容
- 功能 1
- 功能 2

## 安装说明
1. 下载 DMG
2. 拖入 Applications
3. 授权权限"
```

### Step 7: 合并回 main（如果有 hotfix）
```bash
git checkout main
git merge release/X.Y.Z
git push origin main
```

### Step 8: 清理
```bash
git branch -d release/X.Y.Z
```

## ⚠️ 常见错误

### ❌ 错误做法
1. 版本号未更新就发布
2. 直接在 main 分支打包发布
3. 忘记推送到远程
4. Tag 信息不清晰

### ✅ 正确做法
1. **先更新版本号，再打包**
2. **创建 release 分支进行发布**
3. **推送 tag 后再创建 release**
4. **Tag 和 Release notes 写清楚变更内容**

## 📁 文件版本清单

发布前检查以下文件的 VERSION 是否一致：

| 文件 | 字段/位置 | 说明 | 当前版本 |
|------|-----------|------|----------|
| `package.sh` | `VERSION` | 打包脚本版本 | 1.2.0 |
| `release.sh` | `VERSION` | 发布脚本版本 | 1.2.0 |
| `SettingsView.swift` | 顶部标题 `v1.2.0` | 设置页顶部版本显示 | 1.2.0 |
| `SettingsView.swift` | 关于区域 `1.2.0` | 设置页关于版本信息 | 1.2.0 |
| `Info.plist` | `CFBundleVersion` | 应用版本（自动生成） | 1.2.0 |
| `Info.plist` | `CFBundleShortVersionString` | 显示版本（自动生成） | 1.2.0 |

## 🔍 发布前检查清单

- [ ] 版本号已更新：
  - [ ] `package.sh` - VERSION
  - [ ] `release.sh` - VERSION
  - [ ] `SettingsView.swift` - 顶部标题版本 (v1.x.x)
  - [ ] `SettingsView.swift` - 关于区域版本 (1.x.x)
- [ ] 所有功能已测试
- [ ] 代码已提交并推送
- [ ] Release 分支已创建
- [ ] DMG 打包成功
- [ ] Git Tag 已创建并推送
- [ ] GitHub Release 已创建
- [ ] Release notes 已填写

## 📝 Release Notes 模板

```markdown
## ✨ 新功能
- 功能描述

## 🐛 Bug 修复
- 修复描述

## 🔧 技术改进
- 改进描述

## 📦 安装说明
1. 下载 PurelyTab-X.Y.Z.dmg
2. 打开 DMG，将 PurelyTab 拖入 Applications
3. 首次运行需要授权辅助功能权限

## 🔗 下载链接
- [PurelyTab-X.Y.Z.dmg](link)
```

## 🎯 当前版本

**v1.2.0** - 支持最小化窗口显示和拉起

---

**最后更新**: 2026-05-29
