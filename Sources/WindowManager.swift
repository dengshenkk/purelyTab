import Cocoa

struct WindowInfo: Identifiable {
    let id: CGWindowID
    let ownerName: String
    let windowName: String
    let processId: pid_t
    let bundleIdentifier: String?
    let boundsX: CGFloat
    let boundsY: CGFloat
    let indexInApp: Int

    var displayName: String {
        if !windowName.isEmpty && windowName != ownerName {
            return windowName
        }
        return "\(ownerName) - \(indexInApp)"
    }
}

class WindowManager {
    private(set) var windows: [WindowInfo] = []
    private(set) var windowsByApp: [String: [WindowInfo]] = [:]
    private var axWindowTitleCache: [pid_t: [(title: String, x: CGFloat, y: CGFloat)]] = [:]

    func updateWindowList() {
        buildAXTitleCache()

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

        // 先按应用收集原始窗口，再分配 index
        var rawWindows: [(info: [String: Any], pid: pid_t, bx: CGFloat, by: CGFloat)] = []

        for windowInfo in windowList {
            guard let ownerName = windowInfo[kCGWindowOwnerName as String] as? String,
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

            let bx = boundsDict["X"] ?? 0
            let by = boundsDict["Y"] ?? 0

            rawWindows.append((info: windowInfo, pid: processID, bx: bx, by: by))
        }

        // 按应用分配 index
        var appIndexMap: [pid_t: Int] = [:]

        for raw in rawWindows {
            let pid = raw.pid
            let idx = appIndexMap[pid, default: 0]
            appIndexMap[pid] = idx + 1

            guard let windowID = raw.info[kCGWindowNumber as String] as? CGWindowID,
                  let ownerName = raw.info[kCGWindowOwnerName as String] as? String else {
                continue
            }

            let cgWindowName = raw.info[kCGWindowName as String] as? String ?? ""
            let bundleId = bundleIdMap[pid]

            // 从 AXUI 缓存获取真实窗口标题
            var resolvedName = cgWindowName
            if resolvedName.isEmpty || resolvedName == ownerName {
                if let cache = axWindowTitleCache[pid] {
                    for entry in cache {
                        if abs(entry.x - raw.bx) < 20 && abs(entry.y - raw.by) < 20 {
                            resolvedName = entry.title
                            break
                        }
                    }
                }
            }

            let info = WindowInfo(
                id: windowID,
                ownerName: ownerName,
                windowName: resolvedName,
                processId: pid,
                bundleIdentifier: bundleId,
                boundsX: raw.bx,
                boundsY: raw.by,
                indexInApp: idx + 1
            )

            result.append(info)

            let appKey = bundleId ?? ownerName
            if byApp[appKey] == nil {
                byApp[appKey] = []
            }
            byApp[appKey]?.append(info)
        }

        // 检查重复标题，添加序号
        for (appKey, appWindows) in byApp {
            let titles = appWindows.map { $0.displayName }
            let titleCounts = Dictionary(grouping: titles, by: { $0 })
            let duplicates = titleCounts.filter { $0.value.count > 1 }.map { $0.key }

            if !duplicates.isEmpty {
                // 有重复标题，需要给这些窗口添加序号
                var titleIndexMap: [String: Int] = [:]
                for (i, var window) in result.enumerated() {
                    let key = window.bundleIdentifier ?? window.ownerName
                    if key == appKey {
                        let title = window.displayName
                        if duplicates.contains(title) {
                            let idx = titleIndexMap[title, default: 0]
                            titleIndexMap[title] = idx + 1
                            // 创建新的 WindowInfo 带序号
                            result[i] = WindowInfo(
                                id: window.id,
                                ownerName: window.ownerName,
                                windowName: "\(title) (\(idx + 1))",
                                processId: window.processId,
                                bundleIdentifier: window.bundleIdentifier,
                                boundsX: window.boundsX,
                                boundsY: window.boundsY,
                                indexInApp: window.indexInApp
                            )
                        }
                    }
                }
            }
        }

        windows = result
        windowsByApp = byApp
    }

    private func buildAXTitleCache() {
        axWindowTitleCache.removeAll()

        let runningApps = NSWorkspace.shared.runningApplications
        for app in runningApps {
            guard app.activationPolicy != .accessory else { continue }
            let pid = app.processIdentifier
            if pid == getpid() { continue }

            let appRef = AXUIElementCreateApplication(pid)
            var value: CFTypeRef?
            guard AXUIElementCopyAttributeValue(appRef, kAXWindowsAttribute as CFString, &value) == .success,
                  let axWindows = value as? [AXUIElement] else { continue }

            var entries: [(title: String, x: CGFloat, y: CGFloat)] = []

            for axWindow in axWindows {
                var titleValue: CFTypeRef?
                AXUIElementCopyAttributeValue(axWindow, kAXTitleAttribute as CFString, &titleValue)
                let title = titleValue as? String ?? ""

                var posValue: CFTypeRef?
                AXUIElementCopyAttributeValue(axWindow, kAXPositionAttribute as CFString, &posValue)
                guard let pos = posValue else { continue }
                var point = CGPoint.zero
                AXValueGetValue(pos as! AXValue, .cgPoint, &point)

                entries.append((title: title, x: point.x, y: point.y))
            }

            if !entries.isEmpty {
                axWindowTitleCache[pid] = entries
            }
        }
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
