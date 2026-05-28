import SwiftUI

struct WindowSwitcherView: View {
    let windows: [WindowInfo]
    let columns: Int
    let onSelect: (WindowInfo) -> Void
    let onCancel: () -> Void

    @State private var selectedIndex: Int = 0
    @ObservedObject private var settings = SettingsManager.shared

    var body: some View {
        VStack(spacing: 20) {
            // Window grid
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(settings.thumbnailSize.width), spacing: 20), count: columns), spacing: 20) {
                ForEach(Array(windows.enumerated()), id: \.element.id) { index, window in
                    WindowThumbnailView(
                        window: window,
                        isSelected: index == selectedIndex,
                        showTitle: settings.showWindowTitles
                    )
                    .onTapGesture {
                        onSelect(window)
                    }
                    .onHover { isHovered in
                        if isHovered {
                            selectedIndex = index
                        }
                    }
                }
            }
        }
        .padding(40)
        .background(
            RoundedRectangle(cornerRadius: settings.cornerRadius)
                .fill(Color(nsColor: settings.backgroundColor))
                .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
        )
        .onReceive(NotificationCenter.default.publisher(for: .windowSelectionChanged)) { notification in
            if let index = notification.userInfo?["index"] as? Int {
                selectedIndex = index
            }
        }
    }
}

struct WindowThumbnailView: View {
    let window: WindowInfo
    let isSelected: Bool
    let showTitle: Bool

    @ObservedObject private var settings = SettingsManager.shared

    var body: some View {
        VStack(spacing: 8) {
            // Window thumbnail
            ZStack {
                if let thumbnail = window.thumbnail {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: settings.thumbnailSize.width, height: settings.thumbnailSize.height)
                } else {
                    // Placeholder when no thumbnail
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: settings.thumbnailSize.width, height: settings.thumbnailSize.height)
                        .overlay(
                            Image(systemName: "app.fill")
                                .font(.largeTitle)
                                .foregroundColor(.gray)
                        )
                }

                // Selection indicator
                if isSelected {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(nsColor: settings.borderColor), lineWidth: 3)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // Window title
            if showTitle {
                Text(window.displayName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .frame(width: settings.thumbnailSize.width)
            }
        }
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}