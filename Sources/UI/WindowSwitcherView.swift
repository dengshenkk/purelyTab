import SwiftUI

struct WindowSwitcherView: View {
    let windows: [WindowInfo]
    let isSameAppMode: Bool
    let selectedIndex: Int
    let onSelect: (WindowInfo) -> Void
    let onCancel: () -> Void

    @State private var currentSelection: Int

    init(windows: [WindowInfo], isSameAppMode: Bool, selectedIndex: Int, onSelect: @escaping (WindowInfo) -> Void, onCancel: @escaping () -> Void) {
        self.windows = windows
        self.isSameAppMode = isSameAppMode
        self.selectedIndex = selectedIndex
        self.onSelect = onSelect
        self.onCancel = onCancel
        self._currentSelection = State(initialValue: selectedIndex)
    }

    var body: some View {
        VStack(spacing: 0) {
            // 标题
            HStack {
                Text(isSameAppMode ? "切换同应用窗口" : "切换窗口")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
                Spacer()
                if !windows.isEmpty {
                    Text("⌘+Tab 下一个 | ⌘+Shift+Tab 上一个 | 松开 ⌘ 选择")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            if windows.isEmpty {
                // 空状态提示
                VStack(spacing: 8) {
                    Image(systemName: "macwindow")
                        .font(.system(size: 28))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("当前应用没有其他窗口")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 36)
            } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(Array(windows.enumerated()), id: \.element.id) { index, window in
                            WindowRowView(
                                window: window,
                                isSelected: index == currentSelection,
                                index: index + 1
                            )
                            .id(index)
                            .onTapGesture {
                                onSelect(window)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .frame(maxHeight: 400)
                .onChange(of: currentSelection) { newValue in
                    withAnimation {
                        proxy.scrollTo(newValue, anchor: .center)
                    }
                }
                .onAppear {
                    proxy.scrollTo(currentSelection, anchor: .center)
                }
            }
            } // end else
        }
        .frame(width: 400)
        .background(Color(nsColor: .windowBackgroundColor))
        .cornerRadius(10)
        .shadow(color: .black.opacity(0.3), radius: 15, x: 0, y: 5)
        .onReceive(NotificationCenter.default.publisher(for: .windowSelectionChanged)) { notification in
            if let index = notification.userInfo?["index"] as? Int {
                currentSelection = index
            }
        }
    }
}

struct WindowRowView: View {
    let window: WindowInfo
    let isSelected: Bool
    let index: Int

    var body: some View {
        HStack(spacing: 12) {
            Text("\(index)")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(isSelected ? .white : .secondary)
                .frame(width: 24)

            if let icon = getAppIcon(for: window.processId) {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 24, height: 24)
            } else {
                Image(systemName: "app.fill")
                    .font(.system(size: 16))
                    .foregroundColor(isSelected ? .white : .secondary)
                    .frame(width: 24, height: 24)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(window.ownerName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(isSelected ? .white : .primary)

                if !window.windowName.isEmpty && window.windowName != window.ownerName {
                    Text(window.windowName)
                        .font(.system(size: 11))
                        .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // 最小化状态标识
            if window.isMinimized {
                Image(systemName: "minus.circle")
                    .font(.system(size: 12))
                    .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                    .help("最小化")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isSelected ? Color.accentColor : Color.clear)
        .cornerRadius(4)
        .contentShape(Rectangle())
    }

    private func getAppIcon(for pid: pid_t) -> NSImage? {
        let runningApps = NSWorkspace.shared.runningApplications
        for app in runningApps {
            if app.processIdentifier == pid {
                return app.icon
            }
        }
        return nil
    }
}
