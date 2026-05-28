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

            GroupBox(label: Text("使用说明").fontWeight(.semibold)) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "command")
                        Text("+ Tab")
                        Spacer()
                        Text("系统窗口切换")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Image(systemName: "command")
                        Text("+ `")
                        Spacer()
                        Text("系统同应用切换")
                            .foregroundColor(.secondary)
                    }

                    Divider()

                    Text("点击菜单栏图标可手动切换窗口")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
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
        .frame(width: 450, height: 380)
    }
}
