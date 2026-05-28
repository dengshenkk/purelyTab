import Cocoa

struct WindowInfo: Identifiable {
    let id: CGWindowID
    let ownerName: String
    let windowName: String
    let processId: pid_t
    let bundleIdentifier: String?

    var displayName: String {
        if !windowName.isEmpty && windowName != ownerName {
            return "\(ownerName) - \(windowName)"
        }
        return ownerName
    }
}

class WindowManager {
    private(set) var windows: [WindowInfo] = []
    private(set) var windowsByApp: [String: [WindowInfo]] = [:]

    func updateWindowList() {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            windows = []
            windowsByApp = [:]
            return
        }

        var result: [WindowInfo] = []
        var byApp: [String: [WindowInfo]] = [:]

        let runningApps = NSWorkspace.shared.runningApplications
        var bundleIdMap: [pid_t: String] = [:]
        for app in runningApps {
            bundleIdMap[app.processIdentifier] = app.bundleIdentifier
        }

        for windowInfo in windowList {
            guard let windowID = windowInfo[kCGWindowNumber as String] as? CGWindowID,
                  let ownerName = windowInfo[kCGWindowOwnerName as String] as? String,
                  let processID = windowInfo[kCGWindowOwnerPID as String] as? pid_t else {
                continue
            }

            // Skip our own app
            if processID == getpid() { continue }

            // Skip system UI elements
            if ownerName == "Window Server" || ownerName == "Dock" { continue }

            let windowName = windowInfo[kCGWindowName as String] as? String ?? ""
            let bundleId = bundleIdMap[processID]

            let info = WindowInfo(
                id: windowID,
                ownerName: ownerName,
                windowName: windowName,
                processId: processID,
                bundleIdentifier: bundleId
            )

            result.append(info)

            // Group by app
            let appKey = bundleId ?? ownerName
            if byApp[appKey] == nil {
                byApp[appKey] = []
            }
            byApp[appKey]?.append(info)
        }

        // Sort: most recently used first (approximate by window layer)
        windows = result
        windowsByApp = byApp
    }

    func activateWindow(_ window: WindowInfo) {
        let runningApps = NSWorkspace.shared.runningApplications
        for app in runningApps {
            if app.processIdentifier == window.processId {
                app.activate(options: [.activateIgnoringOtherApps])
                break
            }
        }
    }

    func getWindowsForApp(bundleId: String) -> [WindowInfo] {
        return windowsByApp[bundleId] ?? []
    }
}
