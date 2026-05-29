import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var windowSwitcherPanel: NSPanel?
    private var windowManager: WindowManager!
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
        lastFrontmostApp = NSWorkspace.shared.frontmostApplication
        windowManager.updateWindowList()
        windows = windowManager.windows

        if let currentIndex = windowManager.getCurrentWindowIndex() {
            selectedIndex = currentIndex
        } else {
            selectedIndex = 0
        }

        createAndShowWindowSwitcher(sameAppMode: false)
        hotkeyManager.setPanelVisible(true, sameApp: false)
    }

    @objc func showSameAppWindowSwitcher() {
        lastFrontmostApp = NSWorkspace.shared.frontmostApplication
        windowManager.updateWindowList()

        if let frontmostApp = lastFrontmostApp {
            let bundleId = frontmostApp.bundleIdentifier ?? ""
            windows = windowManager.getWindowsForApp(bundleId: bundleId)
        } else {
            windows = []
        }

        selectedIndex = 0

        createAndShowWindowSwitcher(sameAppMode: true)
        hotkeyManager.setPanelVisible(true, sameApp: true)
    }

    func navigateNext() {
        guard !windows.isEmpty else { return }
        selectedIndex = (selectedIndex + 1) % windows.count
        updateSelection()
    }

    func navigatePrevious() {
        guard !windows.isEmpty else { return }
        selectedIndex = (selectedIndex - 1 + windows.count) % windows.count
        updateSelection()
    }

    private func updateSelection() {
        NotificationCenter.default.post(
            name: .windowSelectionChanged,
            object: nil,
            userInfo: ["index": selectedIndex]
        )
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
        windowSwitcherPanel?.close()

        if !sameAppMode && windows.isEmpty { return }

        let panelWidth: CGFloat = 400
        let panelHeight: CGFloat = windows.isEmpty ? 160 : min(CGFloat(windows.count * 44 + 80), 500)

        let panelRect: NSRect
        let settings = SettingsManager.shared

        if settings.panelPosition == "mouse" {
            // 跟随鼠标位置，显示在鼠标所在显示器
            let mouseLocation = NSEvent.mouseLocation
            var mouseScreen: NSScreen?
            for screen in NSScreen.screens {
                if screen.frame.contains(mouseLocation) {
                    mouseScreen = screen
                    break
                }
            }
            let screen = mouseScreen ?? NSScreen.main ?? NSScreen.screens[0]
            let screenFrame = screen.visibleFrame

            panelRect = NSRect(
                x: screenFrame.midX - panelWidth / 2,
                y: screenFrame.midY - panelHeight / 2,
                width: panelWidth,
                height: panelHeight
            )
        } else {
            // 屏幕中央（主显示器）
            let screen = NSScreen.main ?? NSScreen.screens[0]
            let screenFrame = screen.visibleFrame

            panelRect = NSRect(
                x: screenFrame.midX - panelWidth / 2,
                y: screenFrame.midY - panelHeight / 2,
                width: panelWidth,
                height: panelHeight
            )
        }

        windowSwitcherPanel = NSPanel(
            contentRect: panelRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        windowSwitcherPanel?.level = .floating
        windowSwitcherPanel?.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        windowSwitcherPanel?.backgroundColor = .clear
        windowSwitcherPanel?.isOpaque = false
        windowSwitcherPanel?.hasShadow = true

        let switcherView = WindowSwitcherView(
            windows: windows,
            isSameAppMode: sameAppMode,
            selectedIndex: selectedIndex,
            onSelect: { [weak self] window in
                self?.selectWindow(window)
            },
            onCancel: { [weak self] in
                self?.hideWindowSwitcher()
            }
        )

        let hostingView = NSHostingView(rootView: switcherView)
        windowSwitcherPanel?.contentView = hostingView

        windowSwitcherPanel?.makeKeyAndOrderFront(nil)
    }

    func selectWindow(_ window: WindowInfo) {
        hideWindowSwitcher()
        windowManager.activateWindow(window)
    }

    func hideWindowSwitcher() {
        windowSwitcherPanel?.close()
        windowSwitcherPanel = nil
        hotkeyManager.setPanelVisible(false)
    }
}

extension Notification.Name {
    static let windowSelectionChanged = Notification.Name("windowSelectionChanged")
}
