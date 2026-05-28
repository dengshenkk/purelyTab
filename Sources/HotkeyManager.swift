import Cocoa

class HotkeyManager {
    private weak var windowManager: WindowManager?
    private weak var appDelegate: AppDelegate?

    private var eventMonitor: Any?
    private var flagsChangedMonitor: Any?

    private var isNavigationMode = false
    private var navigationWindows: [WindowInfo] = []
    private var selectedIndex = 0

    // Modifier tracking
    private var isCommandPressed = false
    private var isTabPressed = false
    private var wasTabPressed = false

    init(windowManager: WindowManager, appDelegate: AppDelegate) {
        self.windowManager = windowManager
        self.appDelegate = appDelegate
    }

    func setupHotkeys() {
        // Global monitor for Cmd+Tab
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            self?.handleKeyEvent(event)
        }

        // Monitor modifier flags changes
        flagsChangedMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlagsChanged(event)
        }
    }

    func cleanup() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        if let monitor = flagsChangedMonitor {
            NSEvent.removeMonitor(monitor)
            flagsChangedMonitor = nil
        }
    }

    private func handleKeyEvent(_ event: NSEvent) {
        // Check for Cmd+Tab
        if event.modifierFlags.contains(.command) && event.keyCode == 48 { // 48 is Tab
            if !isNavigationMode {
                appDelegate?.showWindowSwitcher()
            }
        }

        // Handle navigation keys
        if isNavigationMode {
            switch event.keyCode {
            case 48: // Tab
                if event.modifierFlags.contains(.shift) {
                    navigateToPrevious()
                } else {
                    navigateToNext()
                }
            case 125, 126: // Down/Up arrow
                navigateToNext()
            case 124, 123: // Right/Left arrow
                if event.keyCode == 124 {
                    navigateToNext()
                } else {
                    navigateToPrevious()
                }
            case 36: // Return
                if let window = navigationWindows[safe: selectedIndex] {
                    appDelegate?.selectWindow(window)
                }
            case 53: // Escape
                appDelegate?.hideWindowSwitcher()
            default:
                break
            }
        }
    }

    private func handleFlagsChanged(_ event: NSEvent) {
        let commandPressed = event.modifierFlags.contains(.command)

        // Detect Cmd release while in navigation mode
        if isNavigationMode && !commandPressed && isCommandPressed {
            // Cmd was released, select current window
            if let window = navigationWindows[safe: selectedIndex] {
                appDelegate?.selectWindow(window)
            }
        }

        isCommandPressed = commandPressed
    }

    func startNavigationMode(with windows: [WindowInfo]) {
        isNavigationMode = true
        navigationWindows = windows
        selectedIndex = 0
    }

    func stopNavigationMode() {
        isNavigationMode = false
        navigationWindows = []
        selectedIndex = 0
    }

    func navigateToNext() {
        guard !navigationWindows.isEmpty else { return }
        selectedIndex = (selectedIndex + 1) % navigationWindows.count
        notifySelectionChange()
    }

    func navigateToPrevious() {
        guard !navigationWindows.isEmpty else { return }
        selectedIndex = (selectedIndex - 1 + navigationWindows.count) % navigationWindows.count
        notifySelectionChange()
    }

    func navigateToIndex(_ index: Int) {
        guard index >= 0 && index < navigationWindows.count else { return }
        selectedIndex = index
        notifySelectionChange()
    }

    private func notifySelectionChange() {
        // Post notification for UI update
        NotificationCenter.default.post(
            name: .windowSelectionChanged,
            object: nil,
            userInfo: ["index": selectedIndex]
        )
    }
}

// MARK: - Notification Extension
extension Notification.Name {
    static let windowSelectionChanged = Notification.Name("windowSelectionChanged")
}

// MARK: - Array Extension
extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
