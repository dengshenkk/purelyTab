import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var windowSwitcherPanel: WindowSwitcherPanel?
    var windowManager: WindowManager!
    private var hotkeyManager: HotkeyManager!
    private var settingsWindow: NSWindow?
    private var windows: [WindowInfo] = []
    private var selectedIndex: Int = 0
    private var lastFrontmostApp: NSRunningApplication?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusBarItem()

        windowManager = WindowManager()
        hotkeyManager = HotkeyManager(appDelegate: self)
        hotkeyManager.setup()

        windowManager.preloadCache()

        Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.windowManager.preloadCache()
        }

        // 同步开机启动设置
        LaunchAgentManager.shared.setEnabled(SettingsManager.shared.launchAtLogin)

        NSApp.setActivationPolicy(.accessory)
        print("PurelyTab launched")
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotkeyManager?.cleanup()
    }

    private func setupStatusBarItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        guard let button = statusItem?.button else { return }
        button.image = NSImage(systemSymbolName: "rectangle.3.group", accessibilityDescription: "PurelyTab")
        button.image?.isTemplate = true

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "切换窗口", action: #selector(showWindowSwitcher), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "切换同应用窗口", action: #selector(showSameAppWindowSwitcher), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "设置", action: #selector(openSettings), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "退出", action: #selector(quitApp), keyEquivalent: "q"))
        statusItem?.menu = menu
        updateStatusBarVisibility()
    }

    func updateStatusBarVisibility() {
        statusItem?.isVisible = SettingsManager.shared.showInMenuBar
    }

    @objc func showWindowSwitcher() {
        openWindowSwitcher(reverse: false)
    }

    func openWindowSwitcher(reverse: Bool) {
        let t0 = CACurrentMediaTime()

        lastFrontmostApp = NSWorkspace.shared.frontmostApplication
        let t1 = CACurrentMediaTime()
        print(String(format: "[TIMING] frontmostApp:      %.1f ms", (t1-t0)*1000))

        windowManager.updateWindowList(frontmostPid: lastFrontmostApp?.processIdentifier)
        let t2 = CACurrentMediaTime()
        print(String(format: "[TIMING] updateWindowList:  %.1f ms  (windows=%d)", (t2-t1)*1000, windowManager.windows.count))

        windows = windowManager.windows

        // 当前最前应用已排第一，默认选中第一项
        selectedIndex = 0
        if reverse { selectedIndex = previousIndex(from: selectedIndex) }
        let t3 = CACurrentMediaTime()
        print(String(format: "[TIMING] index resolution:  %.1f ms", (t3-t2)*1000))

        createAndShowWindowSwitcher(sameAppMode: false)
        let t4 = CACurrentMediaTime()
        print(String(format: "[TIMING] createAndShow:     %.1f ms", (t4-t3)*1000))
        print(String(format: "[TIMING] ── TOTAL ──        %.1f ms", (t4-t0)*1000))

        hotkeyManager.setPanelVisible(true, sameApp: false)
    }

    @objc func showSameAppWindowSwitcher() {
        openSameAppWindowSwitcher(reverse: false)
    }

    func openSameAppWindowSwitcher(reverse: Bool) {
        let t0 = CACurrentMediaTime()

        lastFrontmostApp = NSWorkspace.shared.frontmostApplication
        let pid = lastFrontmostApp?.processIdentifier
        print("[SameApp] Opening for pid=\(pid ?? 0)")

        // 强制刷新 CGWindowList（绕过 1.5s 缓存）
        windowManager.updateWindowList(frontmostPid: lastFrontmostApp?.processIdentifier, forceRefresh: true)
        let t1 = CACurrentMediaTime()
        print(String(format: "[TIMING] sameApp updateWindowList: %.1f ms", (t1-t0)*1000))

        // 异步刷新 AX 数据
        if let pid = pid {
            print("[SameApp] Starting async AX refresh for pid=\(pid)")
            DispatchQueue.global(qos: .userInteractive).async { [weak self] in
                self?.windowManager.refreshAXCacheForApp(pid: pid)
                DispatchQueue.main.async {
                    print("[SameApp] AX refresh callback, panel=\(self?.windowSwitcherPanel != nil)")
                    if self?.windowSwitcherPanel != nil {
                        print("[SameApp] Calling updateSameAppWindowList")
                        self?.updateSameAppWindowList()
                    } else {
                        print("[SameApp] Panel already closed, skipping update")
                    }
                }
            }
        }

        if let frontmostApp = lastFrontmostApp {
            let bundleId = frontmostApp.bundleIdentifier ?? ""
            windows = windowManager.getWindowsForApp(bundleId: bundleId)
            print("[SameApp] Initial windows count: \(windows.count), bundleId=\(bundleId)")
            for (idx, win) in windows.enumerated() {
                print("[SameApp]   Window[\(idx)]: '\(win.windowName)' minimized=\(win.isMinimized)")
            }
        } else {
            windows = []
        }

        selectedIndex = sameAppCurrentWindowIndex() ?? 0
        if reverse { selectedIndex = previousIndex(from: selectedIndex) }

        createAndShowWindowSwitcher(sameAppMode: true)
        let t2 = CACurrentMediaTime()
        print(String(format: "[TIMING] sameApp TOTAL: %.1f ms", (t2-t0)*1000))

        hotkeyManager.setPanelVisible(true, sameApp: true)
    }

    private func updateSameAppWindowList() {
        guard let frontmostApp = lastFrontmostApp else {
            print("[SameApp] updateSameAppWindowList: no frontmostApp")
            return
        }

        print("[SameApp] updateSameAppWindowList: refreshing for pid=\(frontmostApp.processIdentifier)")
        windowManager.updateWindowList(frontmostPid: frontmostApp.processIdentifier, forceRefresh: true)
        let bundleId = frontmostApp.bundleIdentifier ?? ""
        windows = windowManager.getWindowsForApp(bundleId: bundleId)
        print("[SameApp] Updated windows count: \(windows.count)")
        for (idx, win) in windows.enumerated() {
            print("[SameApp]   Updated[\(idx)]: '\(win.windowName)' minimized=\(win.isMinimized)")
        }

        windowSwitcherPanel?.updateWindows(windows, selectedIndex: selectedIndex)
        print("[SameApp] Panel updated")
    }

    func navigateNext() {
        guard !windows.isEmpty else { return }
        selectedIndex = (selectedIndex + 1) % windows.count
        windowSwitcherPanel?.updateSelection(selectedIndex)
    }

    func navigatePrevious() {
        guard !windows.isEmpty else { return }
        selectedIndex = (selectedIndex - 1 + windows.count) % windows.count
        windowSwitcherPanel?.updateSelection(selectedIndex)
    }

    func selectCurrentWindow() {
        guard selectedIndex >= 0 && selectedIndex < windows.count else {
            hideWindowSwitcher()
            return
        }
        selectWindow(windows[selectedIndex])
    }

    @objc private func openSettings() {
        if settingsWindow == nil {
            let settingsView = SettingsView(onStatusVisibilityChange: { [weak self] in
                self?.updateStatusBarVisibility()
            })
            let hostingController = NSHostingController(rootView: settingsView)
            settingsWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 450, height: 450),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            settingsWindow?.title = "设置"
            settingsWindow?.contentViewController = hostingController
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    private func createAndShowWindowSwitcher(sameAppMode: Bool) {
        let t0 = CACurrentMediaTime()

        windowSwitcherPanel?.close()
        if !sameAppMode && windows.isEmpty { return }

        let t1 = CACurrentMediaTime()
        let settings = SettingsManager.shared
        let panel = WindowSwitcherPanel(
            windows: windows,
            selectedIndex: selectedIndex,
            isSameAppMode: sameAppMode,
            iconProvider: { [weak self] window in
                self?.windowManager.getAppIcon(for: window)
            },
            onSelect: { [weak self] window in self?.selectWindow(window) },
            onCancel: { [weak self] in self?.hideWindowSwitcher() }
        )
        let t2 = CACurrentMediaTime()
        print(String(format: "[TIMING]   WindowSwitcherPanel init: %.1f ms", (t2-t1)*1000))

        let panelSize = panel.frame.size
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let screenFrame: NSRect
        if settings.panelPosition == "mouse" {
            let mouseLocation = NSEvent.mouseLocation
            screenFrame = (NSScreen.screens.first { $0.frame.contains(mouseLocation) } ?? screen).visibleFrame
        } else {
            screenFrame = screen.visibleFrame
        }
        let panelRect = NSRect(
            x: screenFrame.midX - panelSize.width / 2,
            y: screenFrame.midY - panelSize.height / 2,
            width: panelSize.width,
            height: panelSize.height
        )

        windowSwitcherPanel = panel
        panel.setFrame(panelRect, display: true)
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        let t3 = CACurrentMediaTime()

        panel.makeKeyAndOrderFront(nil)
        let t4 = CACurrentMediaTime()
        print(String(format: "[TIMING]   makeKeyAndOrderFront:     %.1f ms", (t4-t3)*1000))
        print(String(format: "[TIMING]   createAndShow total:      %.1f ms", (t4-t0)*1000))
    }

    func selectWindow(_ window: WindowInfo) {
        // 记录切换历史
        WindowHistoryManager.shared.recordSwitch(
            windowID: window.id,
            processId: window.processId,
            ownerName: window.ownerName,
            windowName: window.windowName
        )

        hideWindowSwitcher()
        DispatchQueue.main.async { [weak self] in
            self?.windowManager.activateWindow(window)
        }
    }

    func hideWindowSwitcher() {
        windowSwitcherPanel?.close()
        windowSwitcherPanel = nil
        hotkeyManager.setPanelVisible(false)
    }

    private func previousIndex(from index: Int) -> Int {
        guard !windows.isEmpty else { return 0 }
        return (index - 1 + windows.count) % windows.count
    }

    private func sameAppCurrentWindowIndex() -> Int? {
        guard let currentIndex = windowManager.getCurrentWindowIndex(),
              currentIndex < windowManager.windows.count else { return nil }
        let currentWindow = windowManager.windows[currentIndex]
        return windows.firstIndex { $0.id == currentWindow.id }
    }
}
