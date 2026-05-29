# 一个纯粹切换窗口的应用
1. 模仿 https://github.com/lwouis/alt-tab-macos 功能
2. 优化界面，使用户更方便地切换窗口
3. 支持多显示器环境
4. 提供快捷键切换窗口
5. 支持自定义快捷键和界面主题
6. 提供窗口预览功能，方便用户选择目标窗口


# 要求
1. 支持macos11及以上版本
2. 使用swift语言开发
3. 遵循macOS应用开发的最佳实践
4. 提供良好的用户体验和界面设计
5. 代码结构清晰，易于维护和扩展
6. 提供详细的文档和使用说明
7. 支持多语言界面，至少包括英语和中文
8. 提供自动更新功能，确保用户能够及时获得最新版本
9. 确保应用的性能和稳定性，避免占用过多系统资源
10. 提供用户反馈渠道，收集用户意见和建议以持续改进
11. 提供极致的性能, 不占用过多系统资源

# 任务
## 完成编码/测试/打包, 并上传到github仓库
## 代码提交指南
```
echo "# purelyTab" >> README.md
git init
git add README.md
git commit -m "first commit"
git branch -M main
git remote add origin git@github.com:dengshenkk/purelyTab.git
git push -u origin main
```

1. 排除菜单栏上的应用以及没有窗口的应用
2. cmd+tab(cmd+`)打开列表时默认选中当前窗口项
3. cmd+tab(cmd+`)打开窗口后按`可以切换到下一个窗口直到循环到第一个窗口
4. 选定窗口后快速打开该窗口, 不要有卡顿或者性能问题
5. 提供配置选项来配置快捷键, 默认是cmd+tab(cmd+`)
6. 提供配置选项来隐藏菜单栏图标