import SwiftUI

struct SettingsView: View {
    @ObservedObject private var settings = SettingsManager.shared
    var onStatusVisibilityChange: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("PurelyTab 设置")
                .font(.title2)
                .fontWeight(.semibold)

            Divider()

            // 菜单栏设置
            GroupBox(label: Text("菜单栏").fontWeight(.semibold)) {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("显示菜单栏图标", isOn: Binding(
                        get: { settings.showInMenuBar },
                        set: { newValue in
                            settings.showInMenuBar = newValue
                            settings.save()
                            onStatusVisibilityChange?()
                        }
                    ))

                    Text("关闭后可通过重新启动应用来恢复菜单栏图标")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
            }

            // 快捷键设置
            GroupBox(label: Text("快捷键").fontWeight(.semibold)) {
                VStack(alignment: .leading, spacing: 12) {
                    Picker("修饰键:", selection: $settings.modifierKey) {
                        Text("⌘ Command").tag("command")
                        Text("⌥ Option").tag("option")
                        Text("⌃ Control").tag("control")
                    }
                    .pickerStyle(.radioGroup)
                    .onChange(of: settings.modifierKey) { _ in
                        settings.save()
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("切换所有窗口:")
                            Spacer()
                            Text(getModifierSymbol() + "+Tab")
                                .font(.system(.body, design: .monospaced))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.secondary.opacity(0.1))
                                .cornerRadius(4)
                        }

                        HStack {
                            Text("切换同应用窗口:")
                            Spacer()
                            Text(getModifierSymbol() + "+`")
                                .font(.system(.body, design: .monospaced))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.secondary.opacity(0.1))
                                .cornerRadius(4)
                        }

                        Text("打开列表后，按 ` 可循环到下一个窗口")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
            }

            // 使用说明
            GroupBox(label: Text("操作说明").fontWeight(.semibold)) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("• \(getModifierSymbol())+Tab 打开窗口列表")
                    Text("• Tab / Shift+Tab 导航")
                    Text("• ` 循环到下一个窗口")
                    Text("• 松开 \(getModifierSymbol()) 选择当前窗口")
                    Text("• Esc 取消")
                }
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .padding()
            }

            Spacer()

            HStack {
                Spacer()
                Text("版本 1.0.0")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(20)
        .frame(width: 450, height: 500)
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
