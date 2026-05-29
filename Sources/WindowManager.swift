import Cocoa

struct WindowInfo: Identifiable {
    let id: CGWindowID
    let ownerName: String
    let windowName: String
    let processId: pid_t
    let bundleIdentifier: String?
    let boundsX: CGFloat
    let boundsY: CGFloat

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
        var menuBarApps = Set<pid_t>()

        for app in runningApps {
            bundleIdMap[app.processIdentifier] = app.bundleIdentifier
            if app.activationPolicy == .accessory {
                menuBarApps.insert(app.processIdentifier)
            }
        }

        for windowInfo in windowList {
            guard let windowID = windowInfo[kCGWindowNumber as String] as? CGWindowID,
                  let ownerName = windowInfo[kCGWindowOwnerName as String] as? String,
                  let processID = windowInfo[kCGWindowOwnerPID as String] as? pid_t else {
                continue
            }

            if processID == getpid() { continue }
            if menuBarApps.contains(processID) { continue }
            if ownerName == "Window Server" || ownerName == "Dock" { continue }

            guard let boundsDict = windowInfo[kCGWindowBounds as String] as? [String: CGFloat] else { continue }
            let width = boundsDict["Width"] ?? 0
            let height = boundsDict["Height"] ?? 0
            if width < 50 || height < 50 { continue }

            let windowName = windowInfo[kCGWindowName as String] as? String ?? ""
            let bundleId = bundleIdMap[processID]
            let bx = boundsDict["X"] ?? 0
            let by = boundsDict["Y"] ?? 0

            let info = WindowInfo(
                id: windowID,
                ownerName: ownerName,
                windowName: windowName,
                processId: processID,
                bundleIdentifier: bundleId,
                boundsX: bx,
                boundsY: by
            )

            result.append(info)

            let appKey = bundleId ?? ownerName
            if byApp[appKey] == nil {
                byApp[appKey] = []
            }
            byApp[appKey]?.append(info)
        }

        windows = result
        windowsByApp = byApp
    }

    func activateWindow(_ window: WindowInfo) {
        let runningApps = NSWorkspace.shared.runningApplications
        for app in runningApps {
            if app.processIdentifier == window.processId {
                _ = app.activate(options: [.activateIgnoringOtherApps])
                break
            }
        }

        let appRef = AXUIElementCreateApplication(window.processId)
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appRef, kAXWindowsAttribute as CFString, &value)

        guard result == .success, let axWindows = value as? [AXUIElement] else {
            return
        }

        // 通过窗口位置匹配 AXUIElement
        for axWindow in axWindows {
            var posValue: CFTypeRef?
            AXUIElementCopyAttributeValue(axWindow, kAXPositionAttribute as CFString, &posValue)
            guard let pos = posValue else { continue }
            var point = CGPoint.zero
            AXValueGetValue(pos as! AXValue, .cgPoint, &point)

            if abs(point.x - window.boundsX) < 20 && abs(point.y - window.boundsY) < 20 {
                AXUIElementPerformAction(axWindow, kAXRaiseAction as CFString)
                AXUIElementSetAttributeValue(axWindow, kAXFocusedAttribute as CFString, kCFBooleanTrue)
                return
            }
        }

        // 位置匹配失败，尝试标题匹配
        for axWindow in axWindows {
            var titleValue: CFTypeRef?
            AXUIElementCopyAttributeValue(axWindow, kAXTitleAttribute as CFString, &titleValue)
            let title = titleValue as? String ?? ""
            if !title.isEmpty && !window.windowName.isEmpty && title.contains(window.windowName) {
                AXUIElementPerformAction(axWindow, kAXRaiseAction as CFString)
                AXUIElementSetAttributeValue(axWindow, kAXFocusedAttribute as CFString, kCFBooleanTrue)
                return
            }
        }
    }

    func getWindowsForApp(bundleId: String) -> [WindowInfo] {
        return windowsByApp[bundleId] ?? []
    }

    func getCurrentWindowIndex() -> Int? {
        guard let frontmostApp = NSWorkspace.shared.frontmostApplication else { return nil }
        let pid = frontmostApp.processIdentifier

        for (index, window) in windows.enumerated() {
            if window.processId == pid {
                return index
            }
        }
        return nil
    }
}
