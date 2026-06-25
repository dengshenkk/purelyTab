import Cocoa

class WindowSwitcherPanel: NSPanel {
    private var windows: [WindowInfo] = []
    private var selectedIndex: Int = 0
    private var onSelect: ((WindowInfo) -> Void)?
    private var iconProvider: ((WindowInfo) -> NSImage?)?
    private var rows: [WindowRow] = []
    private let rowHeight: CGFloat = 44
    private var scrollView: NSScrollView?
    private var appWindowCounts: [String: Int] = [:]

    init(
        windows: [WindowInfo],
        selectedIndex: Int,
        isSameAppMode: Bool,
        iconProvider: @escaping (WindowInfo) -> NSImage?,
        onSelect: @escaping (WindowInfo) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.windows = windows
        self.selectedIndex = selectedIndex
        self.iconProvider = iconProvider
        self.onSelect = onSelect
        self.appWindowCounts = Dictionary(grouping: windows, by: { $0.appKey }).mapValues(\.count)

        let titleHeight: CGFloat = 56
        let footerHeight: CGFloat = 38
        let panelWidth: CGFloat = 748
        let listPaddingV: CGFloat = 6
        let visibleRows = max(1, min(windows.count, 10))

        let listHeight = CGFloat(visibleRows) * 44 + listPaddingV * 2
        let panelHeight = titleHeight + listHeight + footerHeight

        super.init(
            contentRect: NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        backgroundColor = .clear
        isOpaque = false
        ignoresMouseEvents = false
        hasShadow = true

        setupUI(
            isSameAppMode: isSameAppMode,
            panelWidth: panelWidth,
            panelHeight: panelHeight,
            titleHeight: titleHeight,
            listHeight: listHeight,
            listPaddingV: listPaddingV,
            footerHeight: footerHeight
        )
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
    override var acceptsFirstResponder: Bool { true }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .leftMouseDown, !isKeyWindow { makeKey() }
        super.sendEvent(event)
    }

    private func setupUI(
        isSameAppMode: Bool,
        panelWidth: CGFloat,
        panelHeight: CGFloat,
        titleHeight: CGFloat,
        listHeight: CGFloat,
        listPaddingV: CGFloat,
        footerHeight: CGFloat
    ) {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight))
        container.wantsLayer = true
        container.layer?.cornerRadius = 12
        container.layer?.masksToBounds = true
        container.layer?.backgroundColor = Theme.panelBackground.cgColor
        container.layer?.borderColor = Theme.panelBorder.cgColor
        container.layer?.borderWidth = 1

        let titleLabel = NSTextField(frame: NSRect(x: 18, y: panelHeight - titleHeight + 15, width: 420, height: 24))
        titleLabel.stringValue = "PurelyTab"
        titleLabel.font = NSFont.systemFont(ofSize: 18, weight: .bold)
        titleLabel.textColor = Theme.primaryText
        titleLabel.isBezeled = false; titleLabel.isEditable = false; titleLabel.drawsBackground = false
        container.addSubview(titleLabel)

        let countLabel = NSTextField(frame: NSRect(x: panelWidth - 168, y: panelHeight - titleHeight + 18, width: 148, height: 20))
        countLabel.stringValue = "\(windows.count) 个窗口"
        countLabel.font = NSFont.systemFont(ofSize: 12.5, weight: .medium)
        countLabel.textColor = Theme.secondaryText; countLabel.alignment = .right
        countLabel.isBezeled = false; countLabel.isEditable = false; countLabel.drawsBackground = false
        container.addSubview(countLabel)

        let listX: CGFloat = 8
        let listY: CGFloat = footerHeight
        let listWidth = panelWidth - listX * 2
        let contentHeight = CGFloat(windows.count) * rowHeight + listPaddingV * 2
        let listView = NSView(frame: NSRect(x: 0, y: 0, width: listWidth, height: contentHeight))
        listView.wantsLayer = true

        for (index, window) in windows.enumerated() {
            let y = contentHeight - listPaddingV - CGFloat(index + 1) * rowHeight
            let row = WindowRow(
                frame: NSRect(x: 0, y: y, width: listWidth, height: rowHeight),
                windowInfo: window,
                appWindowCount: appWindowCounts[window.appKey] ?? 1,
                appIcon: iconProvider?(window),
                isSelected: index == selectedIndex
            )
            row.onTap = { [weak self] in self?.selectRow(at: index) }
            rows.append(row)
            listView.addSubview(row)
        }

        let scrollView = NSScrollView(frame: NSRect(x: listX, y: listY, width: listWidth, height: listHeight))
        scrollView.drawsBackground = false; scrollView.backgroundColor = .clear
        scrollView.hasVerticalScroller = CGFloat(windows.count) * rowHeight + listPaddingV * 2 > listHeight
        scrollView.autohidesScrollers = true
        scrollView.wantsLayer = true
        scrollView.layer?.cornerRadius = 9; scrollView.layer?.masksToBounds = true
        scrollView.layer?.backgroundColor = Theme.listBackground.cgColor
        scrollView.documentView = listView
        self.scrollView = scrollView
        container.addSubview(scrollView)

        let footerBorder = NSView(frame: NSRect(x: 0, y: footerHeight - 1, width: panelWidth, height: 1))
        footerBorder.wantsLayer = true
        footerBorder.layer?.backgroundColor = Theme.panelBorder.cgColor
        container.addSubview(footerBorder)

        let footerLabel = NSTextField(frame: NSRect(x: 16, y: 10, width: 240, height: 18))
        footerLabel.stringValue = isSameAppMode ? "Same App Windows" : "Switch Windows"
        footerLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        footerLabel.textColor = Theme.secondaryText
        footerLabel.isBezeled = false; footerLabel.isEditable = false; footerLabel.drawsBackground = false
        container.addSubview(footerLabel)

        self.contentView = container
        scrollSelectionToVisible(selectedIndex)
    }

    func updateSelection(_ newIndex: Int) {
        guard newIndex >= 0 && newIndex < windows.count, newIndex != selectedIndex else { return }
        if selectedIndex < rows.count { rows[selectedIndex].setSelected(false) }
        rows[newIndex].setSelected(true)
        selectedIndex = newIndex
        scrollSelectionToVisible(newIndex)
    }

    func updateWindows(_ newWindows: [WindowInfo], selectedIndex newSelectedIndex: Int) {
        print("[Panel] updateWindows called: \(newWindows.count) windows, selected=\(newSelectedIndex)")
        guard newWindows.count > 0 else {
            print("[Panel] No windows to update")
            return
        }

        windows = newWindows
        selectedIndex = newSelectedIndex
        appWindowCounts = Dictionary(grouping: windows, by: { $0.appKey }).mapValues(\.count)

        // 重建行视图
        guard let scrollView = scrollView,
              let documentView = scrollView.documentView else {
            print("[Panel] No scrollView or documentView")
            return
        }

        print("[Panel] Rebuilding \(newWindows.count) rows")

        // 移除旧行
        for row in rows {
            row.removeFromSuperview()
        }
        rows.removeAll()

        // 创建新行
        let listPaddingV: CGFloat = 6
        let contentHeight = CGFloat(windows.count) * rowHeight + listPaddingV * 2
        documentView.setFrameSize(NSSize(width: documentView.bounds.width, height: contentHeight))

        let listWidth = documentView.bounds.width
        for (index, window) in windows.enumerated() {
            let y = contentHeight - listPaddingV - CGFloat(index + 1) * rowHeight
            let row = WindowRow(
                frame: NSRect(x: 0, y: y, width: listWidth, height: rowHeight),
                windowInfo: window,
                appWindowCount: appWindowCounts[window.appKey] ?? 1,
                appIcon: iconProvider?(window),
                isSelected: index == selectedIndex
            )
            row.onTap = { [weak self] in self?.selectRow(at: index) }
            rows.append(row)
            documentView.addSubview(row)
        }

        print("[Panel] Rows rebuilt, scrolling to \(selectedIndex)")
        scrollSelectionToVisible(selectedIndex)
    }

    private func selectRow(at index: Int) {
        guard index >= 0 && index < windows.count else { return }
        onSelect?(windows[index])
    }

    private func scrollSelectionToVisible(_ index: Int) {
        guard index >= 0 && index < rows.count,
              let documentView = scrollView?.documentView,
              let clipView = scrollView?.contentView else { return }
        let rowFrame = rows[index].frame
        if !clipView.documentVisibleRect.contains(rowFrame) {
            documentView.scrollToVisible(rowFrame.insetBy(dx: 0, dy: -2))
        }
    }
}

private extension WindowInfo {
    var appKey: String { bundleIdentifier ?? ownerName }
}

private enum Theme {
    static let panelBackground         = NSColor(calibratedWhite: 0.955, alpha: 0.98)
    static let listBackground          = NSColor(calibratedWhite: 0.925, alpha: 1.0)
    static let panelBorder             = NSColor(calibratedWhite: 0.82,  alpha: 0.9)
    static let selectedRow             = NSColor(calibratedWhite: 0.845, alpha: 1.0)
    static let hoveredRow              = NSColor(calibratedWhite: 0.885, alpha: 1.0)
    static let selectedRowBorder       = NSColor(calibratedWhite: 0.78,  alpha: 1.0)
    static let primaryText             = NSColor(calibratedWhite: 0.08,  alpha: 1.0)
    static let secondaryText           = NSColor(calibratedWhite: 0.42,  alpha: 1.0)
    static let tertiaryText            = NSColor(calibratedWhite: 0.55,  alpha: 1.0)
    static let badgeBackground         = NSColor(calibratedWhite: 0.86,  alpha: 1.0)
    static let selectedBadgeBackground = NSColor(calibratedWhite: 0.78,  alpha: 1.0)
    static let badgeText               = NSColor(calibratedWhite: 0.42,  alpha: 1.0)
    static let selectedBadgeText       = NSColor(calibratedWhite: 0.08,  alpha: 1.0)
}

// MARK: - WindowRow

class WindowRow: NSView {
    private let windowInfo: WindowInfo
    private let appWindowCount: Int
    private let appIcon: NSImage?
    private var isSelected: Bool
    private var isHovered = false

    private var iconView: NSImageView!
    private var titleLabel: NSTextField!
    private var appLabel: NSTextField!
    // badge 容器 + CATextLayer（彻底绕开 NSTextField 的内置 inset）
    private var minimizedBadgeLayer: CALayer?
    private var minimizedTextLayer: CATextLayer?

    var onTap: (() -> Void)?

    init(frame frameRect: NSRect, windowInfo: WindowInfo, appWindowCount: Int, appIcon: NSImage?, isSelected: Bool) {
        self.windowInfo = windowInfo
        self.appWindowCount = appWindowCount
        self.appIcon = appIcon
        self.isSelected = isSelected
        super.init(frame: frameRect)
        setupUI()
        updateAppearance()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupUI() {
        wantsLayer = true
        layer?.cornerRadius = 7
        layer?.borderWidth = 1

        let iconSize: CGFloat = 26
        let iconX: CGFloat = 11
        let iconY: CGFloat = (frame.height - iconSize) / 2

        iconView = NSImageView(frame: NSRect(x: iconX, y: iconY, width: iconSize, height: iconSize))
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.wantsLayer = true
        iconView.layer?.cornerRadius = 6
        iconView.layer?.masksToBounds = true
        iconView.image = appIcon ?? Self.makeFallbackIcon(for: windowInfo.ownerName)
        addSubview(iconView)

        // ── Minimized badge ──
        let badgeW: CGFloat = 52
        let badgeH: CGFloat = 18
        let trailingPadding: CGFloat = 12

        if windowInfo.isMinimized {
            let badgeX = frame.width - badgeW - trailingPadding
            let badgeY = (frame.height - badgeH) / 2   // 容器本身垂直居中

            // 背景用纯 CALayer，完全可控
            let bgLayer = CALayer()
            bgLayer.frame = CGRect(x: badgeX, y: badgeY, width: badgeW, height: badgeH)
            bgLayer.cornerRadius = 5
            bgLayer.backgroundColor = Theme.badgeBackground.cgColor
            layer?.addSublayer(bgLayer)
            minimizedBadgeLayer = bgLayer

            // 文字用 CATextLayer，verticallyResizesToFit 不管用，
            // 改为手动把 frame 撑满容器并设 alignmentMode = center，
            // 再用 contentsScale 避免模糊。
            let font = NSFont.systemFont(ofSize: 10, weight: .regular)
            let textLayer = CATextLayer()
            textLayer.string = "最小化"
            textLayer.font = font
            textLayer.fontSize = 10
            textLayer.foregroundColor = Theme.badgeText.cgColor
            textLayer.alignmentMode = .center
            textLayer.contentsScale = NSScreen.main?.backingScaleFactor ?? 2.0
            textLayer.truncationMode = .none
            textLayer.isWrapped = false

            // 精确计算文字实际高度，把 frame 垂直居中放在 bgLayer 内
            let textH: CGFloat = 12   // 10pt 字体实际行高约 12pt
            let textY = (badgeH - textH) / 2
            textLayer.frame = CGRect(x: 0, y: textY, width: badgeW, height: textH)
            bgLayer.addSublayer(textLayer)
            minimizedTextLayer = textLayer
        }

        // ── 文字 ──
        let textX: CGFloat = iconX + iconSize + 10
        let badgeReserve: CGFloat = windowInfo.isMinimized ? (badgeW + trailingPadding + 6) : 0
        let appWidth: CGFloat = 160
        let appX = frame.width - appWidth - trailingPadding - badgeReserve
        let titleWidth = max(100, appX - textX - 12)
        let textY: CGFloat = (frame.height - 18) / 2

        titleLabel = NSTextField(frame: NSRect(x: textX, y: textY, width: titleWidth, height: 18))
        titleLabel.stringValue = windowInfo.displayTitle(appWindowCount: appWindowCount)
        titleLabel.font = NSFont.systemFont(ofSize: 13, weight: .regular)
        titleLabel.isBezeled = false; titleLabel.isEditable = false
        titleLabel.lineBreakMode = .byTruncatingTail; titleLabel.drawsBackground = false
        addSubview(titleLabel)

        appLabel = NSTextField(frame: NSRect(x: appX, y: textY, width: appWidth, height: 18))
        appLabel.stringValue = windowInfo.ownerName
        appLabel.font = NSFont.systemFont(ofSize: 13, weight: .regular)
        appLabel.alignment = .right
        appLabel.isBezeled = false; appLabel.isEditable = false
        appLabel.lineBreakMode = .byTruncatingTail; appLabel.drawsBackground = false
        addSubview(appLabel)

        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self, userInfo: nil
        ))
    }

    override func mouseDown(with event: NSEvent) { onTap?() }
    override func mouseUp(with event: NSEvent) {}
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func mouseEntered(with event: NSEvent) { isHovered = true;  updateAppearance() }
    override func mouseExited(with event: NSEvent)  { isHovered = false; updateAppearance() }

    func setSelected(_ selected: Bool) { isSelected = selected; updateAppearance() }

    private func updateAppearance() {
        let highlighted = isSelected || isHovered
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer?.backgroundColor = isHovered
            ? Theme.hoveredRow.cgColor
            : (isSelected ? Theme.selectedRow.cgColor : NSColor.clear.cgColor)
        layer?.borderColor = isSelected ? Theme.selectedRowBorder.cgColor : NSColor.clear.cgColor
        titleLabel?.textColor = Theme.primaryText
        appLabel?.textColor   = highlighted ? Theme.secondaryText : Theme.tertiaryText
        minimizedBadgeLayer?.backgroundColor = (highlighted ? Theme.selectedBadgeBackground : Theme.badgeBackground).cgColor
        minimizedTextLayer?.foregroundColor  = (highlighted ? Theme.selectedBadgeText : Theme.badgeText).cgColor
        CATransaction.commit()
    }

    private static func makeFallbackIcon(for appName: String) -> NSImage {
        let size = NSSize(width: 26, height: 26)
        let image = NSImage(size: size)
        let initial = appName.trimmingCharacters(in: .whitespacesAndNewlines).prefix(1).uppercased()
        image.lockFocus()
        NSColor(calibratedWhite: 0.78, alpha: 1.0).setFill()
        NSBezierPath(roundedRect: NSRect(origin: .zero, size: size), xRadius: 6, yRadius: 6).fill()
        let para = NSMutableParagraphStyle(); para.alignment = .center
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: .medium),
            .foregroundColor: NSColor(calibratedWhite: 0.08, alpha: 1.0),
            .paragraphStyle: para
        ]
        (initial.isEmpty ? "?" : initial).draw(in: NSRect(x: 0, y: 5, width: size.width, height: 16), withAttributes: attrs)
        image.unlockFocus()
        return image
    }
}
