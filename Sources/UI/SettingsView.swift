import SwiftUI

struct SettingsView: View {
    @ObservedObject private var settings = SettingsManager.shared
    var onStatusVisibilityChange: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            // 顶部标题区域
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("PurelyTab")
                        .font(.system(size: 20, weight: .semibold))
                    Text("窗口快速切换工具")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text("v1.2.2")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(4)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Divider()

            ScrollView {
                VStack(spacing: 16) {
                    // 菜单栏
                    SettingsSection(icon: "menubar.rectangle", title: "菜单栏") {
                        Toggle("显示菜单栏图标", isOn: Binding(
                            get: { settings.showInMenuBar },
                            set: { newValue in
                                settings.showInMenuBar = newValue
                                settings.save()
                                onStatusVisibilityChange?()
                            }
                        ))
                        .toggleStyle(.switch)

                        Text("关闭后可通过重新启动应用恢复菜单栏图标")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }

                    // 面板位置
                    SettingsSection(icon: "rectangle.center.inset.filled", title: "面板位置") {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach([("center", "屏幕中央", "面板始终显示在主显示器中央"),
                                     ("mouse", "跟随鼠标", "鼠标在哪个显示器，面板就在哪里显示")],
                                    id: \.0) { value, title, desc in
                                HStack(spacing: 10) {
                                    Image(systemName: settings.panelPosition == value ? "largecircle.fill.circle" : "circle")
                                        .font(.system(size: 14))
                                        .foregroundColor(settings.panelPosition == value ? .accentColor : .secondary)
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(title)
                                            .font(.system(size: 13))
                                        Text(desc)
                                            .font(.system(size: 11))
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    settings.panelPosition = value
                                    settings.save()
                                }
                            }
                        }
                    }

                    // 快捷键
                    SettingsSection(icon: "command", title: "修饰键") {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach([("command", "⌘ Command"),
                                     ("option", "⌥ Option"),
                                     ("control", "⌃ Control")],
                                    id: \.0) { value, label in
                                HStack(spacing: 10) {
                                    Image(systemName: settings.modifierKey == value ? "largecircle.fill.circle" : "circle")
                                        .font(.system(size: 14))
                                        .foregroundColor(settings.modifierKey == value ? .accentColor : .secondary)
                                    Text(label)
                                        .font(.system(size: 13))
                                    Spacer()
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    settings.modifierKey = value
                                    settings.save()
                                }
                            }
                        }
                    }

                    // 操作说明
                    SettingsSection(icon: "keyboard", title: "快捷键说明") {
                        VStack(alignment: .leading, spacing: 6) {
                            ShortcutRow(key: "\(getModifierSymbol()) + Tab", action: "打开窗口列表")
                            ShortcutRow(key: "Tab", action: "下一个窗口")
                            ShortcutRow(key: "Shift + Tab", action: "上一个窗口")
                            ShortcutRow(key: "\(getModifierSymbol()) + `", action: "切换同应用窗口")
                            ShortcutRow(key: "松开 \(getModifierSymbol())", action: "选择当前窗口")
                            ShortcutRow(key: "Esc", action: "取消")
                        }
                    }

                    // 关于
                    SettingsSection(icon: "info.circle", title: "关于") {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(alignment: .top, spacing: 10) {
                                if let icon = NSImage(named: "AppIcon") {
                                    Image(nsImage: icon)
                                        .resizable()
                                        .frame(width: 48, height: 48)
                                        .cornerRadius(8)
                                }
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("PurelyTab")
                                        .font(.system(size: 14, weight: .semibold))
                                    Text("轻量高效的 macOS 窗口快速切换工具")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                }
                            }

                            Divider()

                            InfoRow(label: "作者", value: "dengshenkk")
                            InfoRow(label: "版本", value: "1.2.2")
                            InfoRow(label: "系统要求", value: "macOS 12.0+")

                            HStack(spacing: 6) {
                                Text("GitHub:")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                                    .frame(width: 60, alignment: .trailing)
                                Button {
                                    NSWorkspace.shared.open(URL(string: "https://github.com/dengshenkk/purelyTab")!)
                                } label: {
                                    Text("github.com/dengshenkk/purelyTab")
                                        .font(.system(size: 12))
                                        .foregroundColor(.accentColor)
                                        .underline()
                                }
                                .buttonStyle(.plain)
                                .onHover { hovering in
                                    if hovering {
                                        NSCursor.pointingHand.push()
                                    } else {
                                        NSCursor.pop()
                                    }
                                }
                                Spacer()
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
        }
        .frame(width: 420, height: 500)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func getModifierSymbol() -> String {
        switch settings.modifierKey {
        case "option":
            return "⌥"
        case "control":
            return "⌃"
        default:
            return "⌘"
        }
    }
}

// MARK: - 带图标的设置区块
struct SettingsSection<Content: View>: View {
    let icon: String
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(.accentColor)
                    .frame(width: 16)
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary)
            }

            VStack(alignment: .leading, spacing: 10) {
                content()
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
        }
    }
}

// MARK: - 快捷键行
struct ShortcutRow: View {
    let key: String
    let action: String

    var body: some View {
        HStack {
            Text(key)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(.primary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.12))
                .cornerRadius(4)
                .frame(minWidth: 100, alignment: .leading)
            Text(action)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            Spacer()
        }
    }
}

// MARK: - 信息行
struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .frame(width: 60, alignment: .trailing)
            Text(value)
                .font(.system(size: 12))
            Spacer()
        }
    }
}
