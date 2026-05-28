import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var windowSwitcherPanel: NSPanel?
    private var windowManager: WindowManager!
    private var hotkeyManager: HotkeyManager!
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon, show only in menu bar
        NSApp.setActivationPolicy(.accessory)

        // Initialize managers
        windowManager = WindowManager()
        hotkeyManager = HotkeyManager(windowManager: windowManager, appDelegate: self)

        // Setup status bar item
        setupStatusBarItem()

        // Setup hotkeys
        hotkeyManager.setupHotkeys()

        // Load saved settings
        loadSettings()

        print("PurelyTab launched successfully")
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotkeyManager?.cleanup()
        saveSettings()
    }

    private func setupStatusBarItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "rectangle.3.group", accessibilityDescription: "PurelyTab")
            button.image?.isTemplate = true
        }

        let menu = NSMenu()

        menu.addItem(NSMenuItem(title: NSLocalizedString("Show All Windows", comment: ""), action: #selector(showWindowSwitcher), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: NSLocalizedString("Settings...", comment: ""), action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: NSLocalizedString("Check for Updates...", comment: ""), action: #selector(checkForUpdates), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: NSLocalizedString("Quit PurelyTab", comment: ""), action: #selector(quitApp), keyEquivalent: "q"))

        statusItem?.menu = menu
    }

    @objc func showWindowSwitcher() {
        windowManager.updateWindowList()
        createAndShowWindowSwitcherPanel()
    }

    @objc private func openSettings() {
        if settingsWindow == nil {
            let settingsView = SettingsView()
            let hostingController = NSHostingController(rootView: settingsView)

            settingsWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            settingsWindow?.title = NSLocalizedString("PurelyTab Settings", comment: "")
            settingsWindow?.contentViewController = hostingController
            settingsWindow?.center()
        }

        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func checkForUpdates() {
        // Auto-update placeholder - will be implemented with Sparkle in production
        let alert = NSAlert()
        alert.messageText = NSLocalizedString("Check for Updates", comment: "")
        alert.informativeText = NSLocalizedString("Auto-update will be available in a future version.", comment: "")
        alert.alertStyle = .informational
        alert.addButton(withTitle: NSLocalizedString("OK", comment: ""))
        alert.runModal()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    private func loadSettings() {
        // Load user preferences from UserDefaults
        _ = SettingsManager.shared
    }

    private func saveSettings() {
        SettingsManager.shared.save()
    }

    private func createAndShowWindowSwitcherPanel() {
        // Close existing panel if any
        windowSwitcherPanel?.close()

        let windows = windowManager.windows
        guard !windows.isEmpty else { return }

        // Calculate panel size based on window count
        let (columns, rows) = calculateGridDimensions(for: windows.count)
        let cellSize = SettingsManager.shared.thumbnailSize
        let spacing: CGFloat = 20
        let padding: CGFloat = 40

        let totalWidth = CGFloat(columns) * cellSize.width + CGFloat(columns - 1) * spacing + padding * 2
        let totalHeight = CGFloat(rows) * cellSize.height + CGFloat(rows - 1) * spacing + padding * 2

        // Get screen for display
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let screenFrame = screen.visibleFrame

        let panelRect = NSRect(
            x: screenFrame.midX - totalWidth / 2,
            y: screenFrame.midY - totalHeight / 2,
            width: totalWidth,
            height: totalHeight
        )

        // Create panel
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

        // Create SwiftUI content
        let switcherView = WindowSwitcherView(
            windows: windows,
            columns: columns,
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

        // Start keyboard navigation
        hotkeyManager.startNavigationMode(with: windows)
    }

    private func calculateGridDimensions(for count: Int) -> (columns: Int, rows: Int) {
        let maxColumns = SettingsManager.shared.maxColumns

        if count <= maxColumns {
            return (count, 1)
        }

        let columns = maxColumns
        let rows = (count + columns - 1) / columns
        return (columns, rows)
    }

    func selectWindow(_ window: WindowInfo) {
        hideWindowSwitcher()
        windowManager.activateWindow(window)
    }

    func hideWindowSwitcher() {
        windowSwitcherPanel?.close()
        windowSwitcherPanel = nil
        hotkeyManager.stopNavigationMode()
    }

    func navigateToNextWindow() {
        hotkeyManager.navigateToNext()
    }

    func navigateToPreviousWindow() {
        hotkeyManager.navigateToPrevious()
    }
}
