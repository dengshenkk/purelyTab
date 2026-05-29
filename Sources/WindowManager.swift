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
    let isMinimized: Bool

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
    private var minimizedWindowsCache: [WindowInfo] = []
    private var lastUpdateTime: Date = Date.distantPast
    private let cacheTimeout: TimeInterval = 2.0 // 2秒缓存

    func updateWindowList() {
        let now = Date()
        // 如果距离上次更新不超过2秒，使用缓存
        if now.timeIntervalSince(lastUpdateTime) < cacheTimeout && !windows.isEmpty {
            return
        }

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
        var rawWindows: [(info: [String: Any], pid: pid_t, bx: CGFloat, by: CGFloat, isMinimized: Bool)] = []

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

            rawWindows.append((info: windowInfo, pid: processID, bx: bx, by: by, isMinimized: false))
        }

        // 获取最小化窗口（使用缓存）
        if now.timeIntervalSince(lastUpdateTime) >= cacheTimeout {
            minimizedWindowsCache = getMinimizedWindows(runningApps: runningApps, menuBarApps: menuBarApps)
        }
        rawWindows.append(contentsOf: minimizedWindowsCache.map { window in
            // 将 WindowInfo 转换为 rawWindows 需要的格式
            return (info: [
                kCGWindowNumber as String: window.id,
                kCGWindowOwnerName as String: window.ownerName,
                kCGWindowName as String: window.windowName,
                kCGWindowOwnerPID as String: window.processId,
                kCGWindowBounds as String: [
                    "X": window.boundsX,
                    "Y": window.boundsY,
                    "Width": 0.0,
                    "Height": 0.0
                ]
            ] as [String: Any], pid: window.processId, bx: window.boundsX, by: window.boundsY, isMinimized: true)
        })

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
                indexInApp: idx + 1,
                isMinimized: raw.isMinimized
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
                for (i, window) in result.enumerated() {
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
                                indexInApp: window.indexInApp,
                                isMinimized: window.isMinimized
                            )
                        }
                    }
                }
            }
        }

        windows = result
        windowsByApp = byApp
        lastUpdateTime = now
    }

    func refreshMinimizedWindows() {
        let runningApps = NSWorkspace.shared.runningApplications
        var menuBarApps = Set<pid_t>()

        for app in runningApps {
            if app.activationPolicy == .accessory {
                menuBarApps.insert(app.processIdentifier)
            }
        }

        minimizedWindowsCache = getMinimizedWindows(runningApps: runningApps, menuBarApps: menuBarApps)
        lastUpdateTime = Date.distantPast // 强制下次更新
    }

    private func getMinimizedWindows(runningApps: [NSRunningApplication], menuBarApps: Set<pid_t>) -> [WindowInfo] {
        var minimized: [WindowInfo] = []

        // 只检查前台应用和最近使用的应用，避免遍历所有应用
        let recentApps = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .prefix(10) // 只检查前10个应用

        var processedPids = Set<pid_t>()

        for app in recentApps {
            let pid = app.processIdentifier

            if pid == getpid() { continue }
            if menuBarApps.contains(pid) { continue }
            if processedPids.contains(pid) { continue }
            processedPids.insert(pid)

            let appRef = AXUIElementCreateApplication(pid)
            var value: CFTypeRef?

            guard AXUIElementCopyAttributeValue(appRef, kAXWindowsAttribute as CFString, &value) == .success,
                  let axWindows = value as? [AXUIElement] else {
                continue
            }

            for axWindow in axWindows {
                // 检查是否最小化
                var minimizedValue: CFTypeRef?
                let minimizedResult = AXUIElementCopyAttributeValue(axWindow, kAXMinimizedAttribute as CFString, &minimizedValue)

                guard minimizedResult == .success,
                      let isMinimized = minimizedValue as? Bool,
                      isMinimized else {
                    continue
                }

                // 获取窗口标题
                var titleValue: CFTypeRef?
                AXUIElementCopyAttributeValue(axWindow, kAXTitleAttribute as CFString, &titleValue)
                let title = titleValue as? String ?? ""

                // 创建一个伪窗口 ID
                let pseudoWindowID = CGWindowID(pid) * 1000 + CGWindowID(minimized.count)

                let info = WindowInfo(
                    id: pseudoWindowID,
                    ownerName: app.localizedName ?? "Unknown",
                    windowName: title,
                    processId: pid,
                    bundleIdentifier: app.bundleIdentifier,
                    boundsX: 0,
                    boundsY: 0,
                    indexInApp: 1,
                    isMinimized: true
                )

                minimized.append(info)
            }
        }

        return minimized
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
            // 如果窗口是最小化，先取消最小化
            if window.isMinimized {
                AXUIElementSetAttributeValue(axWindow, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
                // 等待窗口恢复
                usleep(100000) // 100ms
            }

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

        // 如果是通过伪 ID 标识的最小化窗口，可能无法通过位置匹配
        // 此时直接尝试取消最小化并激活应用
        if window.isMinimized {
            // 找到第一个最小化窗口并恢复
            for axWindow in axWindows {
                var minimizedValue: CFTypeRef?
                let minimizedResult = AXUIElementCopyAttributeValue(axWindow, kAXMinimizedAttribute as CFString, &minimizedValue)

                if minimizedResult == .success,
                   let isMinimized = minimizedValue as? Bool,
                   isMinimized {
                    AXUIElementSetAttributeValue(axWindow, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
                    usleep(100000)
                    AXUIElementPerformAction(axWindow, kAXRaiseAction as CFString)
                    AXUIElementSetAttributeValue(axWindow, kAXFocusedAttribute as CFString, kCFBooleanTrue)
                    return
                }
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
