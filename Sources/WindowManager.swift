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
        if !windowName.isEmpty && windowName != ownerName { return windowName }
        return ownerName
    }

    func displayTitle(appWindowCount: Int) -> String {
        if !windowName.isEmpty && windowName != ownerName { return windowName }
        return ownerName
    }
}

/// 后台缓存中存储的窗口属性值（真实数据，非 AX 引用句柄）
/// 主线程 updateWindowList 纯内存读取，零 IPC
struct CachedWindowData {
    let title: String
    let position: CGPoint
    let isMinimized: Bool
}

class WindowManager {
    private(set) var windows: [WindowInfo] = []
    private(set) var windowsByApp: [String: [WindowInfo]] = [:]
    private var lastUpdateTime: Date = Date.distantPast
    private let cacheTimeout: TimeInterval = 1.5

    private var iconCache: [pid_t: NSImage] = [:]
    private var bundleIdCache: [pid_t: String] = [:]

    // AX 数据缓存：由后台定时器持续刷新属性值（非引用），主线程纯内存读取，零 IPC
    private var cachedWindowData: [pid_t: [CachedWindowData]] = [:]
    private var cachedMenuBarPids: Set<pid_t> = []
    private var axCacheQueue = DispatchQueue(label: "com.purelytab.axcache", qos: .userInteractive)
    private var axRefreshTimer: Timer?
    private let perAppAXTimeout: DispatchTimeInterval = .milliseconds(50)

    private let preloadQueue = DispatchQueue(label: "com.purelytab.preload", qos: .utility)
    private var isPreloading = false

    // MARK: - Init / Cache Warmup

    func preloadCache() {
        guard !isPreloading else { return }
        isPreloading = true
        preloadQueue.async { [weak self] in
            self?.buildIconAndBundleCache()
            DispatchQueue.main.async { self?.isPreloading = false }
        }

        if axRefreshTimer == nil {
            axRefreshTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                self?.refreshAXCacheInBackground()
            }
            axRefreshTimer?.fire()
        }
    }

    private func refreshAXCacheInBackground() {
        axCacheQueue.async { [weak self] in
            guard let self else { return }
            let t0 = CACurrentMediaTime()

            let allApps = NSWorkspace.shared.runningApplications
            let regularApps = allApps.filter {
                $0.activationPolicy == .regular && $0.processIdentifier != ProcessInfo.processInfo.processIdentifier
            }

            // 收集 menuBar pids（与 regular 同步缓存）
            var menuBarPids = Set<pid_t>()
            for app in allApps {
                if app.activationPolicy == .accessory {
                    menuBarPids.insert(app.processIdentifier)
                }
            }

            var newCache: [pid_t: [CachedWindowData]] = [:]
            for app in regularApps {
                let pid = app.processIdentifier
                let appRef = AXUIElementCreateApplication(pid)
                var val: CFTypeRef?
                guard AXUIElementCopyAttributeValue(appRef, kAXWindowsAttribute as CFString, &val) == .success,
                      let axWindows = val as? [AXUIElement] else { continue }

                // per-app timeout：单个 app 的 AX 读取最多 50ms
                var windowDataList: [CachedWindowData] = []
                let workItem = DispatchWorkItem {
                    for axWindow in axWindows {
                        var titleVal: CFTypeRef?, posVal: CFTypeRef?, minVal: CFTypeRef?
                        AXUIElementCopyAttributeValue(axWindow, kAXTitleAttribute as CFString, &titleVal)
                        AXUIElementCopyAttributeValue(axWindow, kAXPositionAttribute as CFString, &posVal)
                        AXUIElementCopyAttributeValue(axWindow, kAXMinimizedAttribute as CFString, &minVal)

                        let title = titleVal as? String ?? ""
                        var point = CGPoint.zero
                        if let pos = posVal { AXValueGetValue(pos as! AXValue, .cgPoint, &point) }
                        let isMinimized = minVal as? Bool ?? false

                        windowDataList.append(CachedWindowData(title: title, position: point, isMinimized: isMinimized))
                    }
                }
                workItem.perform()
                if workItem.wait(timeout: .now() + perAppAXTimeout) == .timedOut {
                    workItem.cancel()
                    // 超时时仍保留已读取的部分数据
                }

                newCache[pid] = windowDataList
            }

            let elapsed = (CACurrentMediaTime() - t0) * 1000
            print(String(format: "[AXCache] background refresh: %.1f ms  (%d apps, %d menuBar)", elapsed, newCache.count, menuBarPids.count))

            DispatchQueue.main.async { [weak self] in
                self?.cachedWindowData = newCache
                self?.cachedMenuBarPids = menuBarPids
            }
        }
    }

    private func buildIconAndBundleCache() {
        let runningApps = NSWorkspace.shared.runningApplications
        var newIconCache: [pid_t: NSImage] = [:]
        var newBundleIdCache: [pid_t: String] = [:]
        for app in runningApps {
            let pid = app.processIdentifier
            if let icon = app.icon { newIconCache[pid] = icon }
            if let bundleId = app.bundleIdentifier { newBundleIdCache[pid] = bundleId }
        }
        DispatchQueue.main.async { [weak self] in
            self?.iconCache = newIconCache
            self?.bundleIdCache = newBundleIdCache
        }
    }

    // MARK: - On-Demand Refresh

    func refreshAXCacheForApp(pid: pid_t) {
        print("[OnDemand] Starting AX refresh for pid=\(pid)")
        let t0 = CACurrentMediaTime()

        let appRef = AXUIElementCreateApplication(pid)
        var val: CFTypeRef?

        guard AXUIElementCopyAttributeValue(appRef, kAXWindowsAttribute as CFString, &val) == .success,
              let axWindows = val as? [AXUIElement] else {
            print("[OnDemand] Failed to get windows for pid=\(pid)")
            return
        }

        print("[OnDemand] Found \(axWindows.count) windows for pid=\(pid)")

        var windowDataList: [CachedWindowData] = []
        var minimizedCount = 0
        for (idx, axWindow) in axWindows.enumerated() {
            var titleVal: CFTypeRef?, posVal: CFTypeRef?, minVal: CFTypeRef?
            AXUIElementCopyAttributeValue(axWindow, kAXTitleAttribute as CFString, &titleVal)
            AXUIElementCopyAttributeValue(axWindow, kAXPositionAttribute as CFString, &posVal)
            AXUIElementCopyAttributeValue(axWindow, kAXMinimizedAttribute as CFString, &minVal)

            let title = titleVal as? String ?? ""
            var point = CGPoint.zero
            if let pos = posVal { AXValueGetValue(pos as! AXValue, .cgPoint, &point) }
            let isMinimized = minVal as? Bool ?? false

            if isMinimized {
                minimizedCount += 1
                print("[OnDemand]   Window[\(idx)] MINIMIZED: '\(title)'")
            }

            windowDataList.append(CachedWindowData(title: title, position: point, isMinimized: isMinimized))
        }

        let elapsed = (CACurrentMediaTime() - t0) * 1000
        print("[OnDemand] AX refresh completed: \(elapsed)ms, \(windowDataList.count) windows, \(minimizedCount) minimized")

        DispatchQueue.main.async { [weak self] in
            self?.cachedWindowData[pid] = windowDataList
            print("[OnDemand] Cache updated for pid=\(pid)")
        }
    }

    // MARK: - Icon

    func getAppIcon(for pid: pid_t) -> NSImage? {
        if let icon = iconCache[pid] { return icon }
        if let app = NSRunningApplication(processIdentifier: pid), let icon = app.icon {
            iconCache[pid] = icon
            if let bundleId = app.bundleIdentifier { bundleIdCache[pid] = bundleId }
            return icon
        }
        return nil
    }

    func getAppIcon(for window: WindowInfo) -> NSImage? {
        if let icon = getAppIcon(for: window.processId) { return icon }
        if let bid = window.bundleIdentifier,
           let icon = getAppIcon(forBundleIdentifier: bid, pid: window.processId) { return icon }
        if let icon = getRunningAppIcon(named: window.ownerName, pid: window.processId) { return icon }
        if let icon = getInstalledAppIcon(named: window.ownerName, pid: window.processId) { return icon }
        return nil
    }

    private func getAppIcon(forBundleIdentifier bundleIdentifier: String, pid: pid_t) -> NSImage? {
        if let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == bundleIdentifier }),
           let icon = app.icon {
            iconCache[pid] = icon; bundleIdCache[pid] = bundleIdentifier; return icon
        }
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) {
            let icon = NSWorkspace.shared.icon(forFile: url.path)
            iconCache[pid] = icon; bundleIdCache[pid] = bundleIdentifier; return icon
        }
        return nil
    }

    private func getRunningAppIcon(named ownerName: String, pid: pid_t) -> NSImage? {
        for app in NSWorkspace.shared.runningApplications where app.localizedName == ownerName {
            if let icon = app.icon {
                iconCache[pid] = icon
                if let bundleId = app.bundleIdentifier { bundleIdCache[pid] = bundleId }
                return icon
            }
        }
        return nil
    }

    private func getInstalledAppIcon(named ownerName: String, pid: pid_t) -> NSImage? {
        if let path = installedApplicationPath(named: ownerName) {
            let icon = NSWorkspace.shared.icon(forFile: path)
            iconCache[pid] = icon; return icon
        }
        if let bid = NSWorkspace.shared.runningApplications
            .first(where: { $0.localizedName == ownerName })?.bundleIdentifier,
           let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bid) {
            let icon = NSWorkspace.shared.icon(forFile: url.path)
            iconCache[pid] = icon; bundleIdCache[pid] = bid; return icon
        }
        return nil
    }

    private func installedApplicationPath(named ownerName: String) -> String? {
        let name = ownerName.hasSuffix(".app") ? ownerName : "\(ownerName).app"
        let home = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Applications").path
        return ["/Applications/\(name)", "/System/Applications/\(name)",
                "/Applications/Utilities/\(name)", "\(home)/\(name)"]
            .first { FileManager.default.fileExists(atPath: $0) }
    }

    // MARK: - Window List

    func updateWindowList(frontmostPid: pid_t? = nil, forceRefresh: Bool = false) {
        let u0 = CACurrentMediaTime()
        let now = Date()

        // 缓存命中时仍需按最新 frontmostPid 重排
        if !forceRefresh && now.timeIntervalSince(lastUpdateTime) < cacheTimeout && !windows.isEmpty {
            reSortWindows(&windows, frontmostPid: frontmostPid)
            print(String(format: "[TIMING]   updateWindowList: cache hit (re-sorted) %.1f ms", (CACurrentMediaTime()-u0)*1000))
            return
        }

        // ── Step A: CGWindowList ──
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            windows = []; windowsByApp = [:]; return
        }
        let u1 = CACurrentMediaTime()
        print(String(format: "[TIMING]   A) CGWindowListCopyWindowInfo: %.1f ms  (%d raw entries)", (u1-u0)*1000, windowList.count))

        // ── Step A2: 获取所有 Space 的窗口（用于补充前台应用的其他 Space 窗口） ──
        let allSpacesOptions: CGWindowListOption = [.excludeDesktopElements]
        let allSpacesWindowList = CGWindowListCopyWindowInfo(allSpacesOptions, kCGNullWindowID) as? [[String: Any]] ?? []
        let u1b = CACurrentMediaTime()
        print(String(format: "[TIMING]   A2) all spaces window list:      %.1f ms  (%d entries)", (u1b-u1)*1000, allSpacesWindowList.count))

        // ── Step B: menuBar pids from cache (纯内存) ──
        let menuBarApps = cachedMenuBarPids
        let u2 = CACurrentMediaTime()
        print(String(format: "[TIMING]   B) menuBarApps from cache:    %.1f ms  (%d pids)", (u2-u1)*1000, menuBarApps.count))

        // ── Step C: AX data cache snapshot (纯内存) ──
        let currentWindowData = cachedWindowData
        let u3 = CACurrentMediaTime()
        print(String(format: "[TIMING]   C) AX data cache snapshot:     %.1f ms  (%d pids)", (u3-u2)*1000, currentWindowData.count))

        // ── Step C2: 构建当前 Space 可见窗口位置列表 ──
        var visibleWindowPositions: [CGPoint] = []
        for info in windowList {
            guard let boundsDict = info[kCGWindowBounds as String] as? [String: CGFloat] else { continue }
            let x = boundsDict["X"] ?? 0, y = boundsDict["Y"] ?? 0
            visibleWindowPositions.append(CGPoint(x: x, y: y))
        }
        let u3b = CACurrentMediaTime()
        print(String(format: "[TIMING]   C2) visible positions list:      %.1f ms  (%d positions)", (u3b-u3)*1000, visibleWindowPositions.count))

        // ── Step D: visible windows loop (纯内存匹配) ──
        var result: [WindowInfo] = []
        var byApp: [String: [WindowInfo]] = [:]
        var appIndexMap: [pid_t: Int] = [:]
        var sameAppZOrder: [pid_t: Int] = [:]  // 跟踪同应用窗口的 z-order 索引
        var seenSemanticKeys = Set<String>()

        for info in windowList {
            guard let ownerName = info[kCGWindowOwnerName as String] as? String,
                  let pid = info[kCGWindowOwnerPID as String] as? pid_t,
                  let windowID = info[kCGWindowNumber as String] as? CGWindowID else { continue }

            if pid == getpid() { continue }
            if menuBarApps.contains(pid) { continue }
            if ownerName == "Window Server" || ownerName == "Dock" { continue }

            let layer = info[kCGWindowLayer as String] as? Int ?? 0
            if layer != 0 { continue }

            let alpha = info[kCGWindowAlpha as String] as? CGFloat ?? 1
            if alpha <= 0 { continue }

            guard let boundsDict = info[kCGWindowBounds as String] as? [String: CGFloat] else { continue }
            let w = boundsDict["Width"] ?? 0, h = boundsDict["Height"] ?? 0
            if w < 50 || h < 50 { continue }

            let bx = boundsDict["X"] ?? 0, by = boundsDict["Y"] ?? 0
            let cgName = info[kCGWindowName as String] as? String ?? ""

            // 计算当前窗口在同应用中的 z-order 索引（CG 和 AX 都按 z-order 排列，用于位置冲突时按索引匹配）
            let zIndex = sameAppZOrder[pid, default: 0]
            sameAppZOrder[pid] = zIndex + 1

            let resolvedName = resolveWindowNameFromCache(
                cgWindowName: cgName, ownerName: ownerName,
                processId: pid, boundsX: bx, boundsY: by,
                windowDataCache: currentWindowData,
                visibleWindowPositions: visibleWindowPositions,
                windowZOrderIndex: zIndex
            )

            let semanticKey = windowSemanticKey(processId: pid, title: resolvedName, ownerName: ownerName)
            // 使用 CGWindowID + semanticKey 组合去重，避免相同标题的不同窗口被错误去重
            let uniqueKey = "\(windowID):\(semanticKey)"
            if seenSemanticKeys.contains(uniqueKey) { continue }
            seenSemanticKeys.insert(uniqueKey)

            let idx = appIndexMap[pid, default: 0] + 1
            appIndexMap[pid] = idx
            let bundleId = bundleIdentifier(for: pid)

            let item = WindowInfo(
                id: windowID, ownerName: ownerName, windowName: resolvedName,
                processId: pid, bundleIdentifier: bundleId,
                boundsX: bx, boundsY: by, indexInApp: idx, isMinimized: false
            )
            result.append(item)
            let appKey = bundleId ?? ownerName
            byApp[appKey, default: []].append(item)
        }
        let u4 = CACurrentMediaTime()
        print(String(format: "[TIMING]   D) visible windows loop:       %.1f ms  (%d windows)", (u4-u3)*1000, result.count))

        // ── Step E: minimized windows from cache (纯内存 filter) ──
        for (pid, windowDataList) in currentWindowData {
            if pid == getpid() || menuBarApps.contains(pid) { continue }

            let appName = NSRunningApplication(processIdentifier: pid)?.localizedName ?? "Unknown"
            let bundleId = bundleIdentifier(for: pid)

            var minimizedIdx = 0
            for windowData in windowDataList where windowData.isMinimized {
                let title = windowData.title
                let semanticKey = windowSemanticKey(processId: pid, title: title, ownerName: appName)
                if seenSemanticKeys.contains(semanticKey) { continue }
                seenSemanticKeys.insert(semanticKey)

                minimizedIdx += 1
                let idx = appIndexMap[pid, default: 0] + 1
                appIndexMap[pid] = idx

                let titleHash = UInt32(truncatingIfNeeded: UInt(bitPattern: title.hashValue) & 0xFFFFF)
                let pseudoID = CGWindowID(0xF0000000) | (CGWindowID(pid & 0xFFF) << 20)
                    | CGWindowID(minimizedIdx & 0xFF) | titleHash

                let item = WindowInfo(
                    id: pseudoID, ownerName: appName,
                    windowName: title, processId: pid, bundleIdentifier: bundleId,
                    boundsX: 0, boundsY: 0, indexInApp: idx, isMinimized: true
                )
                result.append(item)
                let appKey = bundleId ?? appName
                byApp[appKey, default: []].append(item)
            }
        }
        let u5 = CACurrentMediaTime()
        print(String(format: "[TIMING]   E) minimized scan:             %.1f ms  (total=%d)", (u5-u4)*1000, result.count))

        // ── Step E2: 补充前台应用的其他 Space 窗口（AX 有但 CG 未捕获的） ──
        var e2Added = 0
        if let fpid = frontmostPid,
           let windowDataList = currentWindowData[fpid] {
            let appName = NSRunningApplication(processIdentifier: fpid)?.localizedName ?? "Unknown"
            let bundleId = bundleIdentifier(for: fpid)

            // 收集 Step D 已有的 CGWindowID，用于去重
            let existingWindowIDs = Set(result.map { $0.id })

            var extraIdx = 0
            for windowData in windowDataList where !windowData.isMinimized {
                let axTitle = windowData.title
                if axTitle.isEmpty { continue }

                // 从 allSpacesWindowList 中查找真实的 CGWindowID
                let matchedWindowID: CGWindowID? = {
                    for info in allSpacesWindowList {
                        guard let pid = info[kCGWindowOwnerPID as String] as? pid_t,
                              pid == fpid,
                              let wID = info[kCGWindowNumber as String] as? CGWindowID else { continue }
                        // 匹配标题
                        let cgName = info[kCGWindowName as String] as? String ?? ""
                        if cgName == axTitle {
                            return wID
                        }
                        // 匹配位置
                        guard let boundsDict = info[kCGWindowBounds as String] as? [String: CGFloat] else { continue }
                        let bx = boundsDict["X"] ?? 0, by = boundsDict["Y"] ?? 0
                        if abs(bx - windowData.position.x) < 20 && abs(by - windowData.position.y) < 20 {
                            return wID
                        }
                    }
                    return nil
                }()

                guard let realWindowID = matchedWindowID else { continue }

                // 如果这个 CGWindowID 已经在 Step D 中添加过，跳过
                if existingWindowIDs.contains(realWindowID) { continue }

                extraIdx += 1
                let idx = appIndexMap[fpid, default: 0] + 1
                appIndexMap[fpid] = idx

                let item = WindowInfo(
                    id: realWindowID, ownerName: appName,
                    windowName: axTitle, processId: fpid, bundleIdentifier: bundleId,
                    boundsX: windowData.position.x, boundsY: windowData.position.y,
                    indexInApp: idx, isMinimized: false
                )
                result.append(item)
                let appKey = bundleId ?? appName
                byApp[appKey, default: []].append(item)
            }
            e2Added = extraIdx
        }
        let u5b = CACurrentMediaTime()
        print(String(format: "[TIMING]   E2) extra visible from AX:      %.1f ms  (added=%d, total=%d)", (u5b-u5)*1000, e2Added, result.count))

        // ── Step F: 按历史排序 + 清理 ──
        reSortWindows(&result, frontmostPid: frontmostPid)
        let u6 = CACurrentMediaTime()
        print(String(format: "[TIMING]   F) history sort:              %.1f ms", (u6-u5b)*1000))
        print(String(format: "[TIMING]   updateWindowList TOTAL:        %.1f ms", (u6-u0)*1000))

        windows = result
        windowsByApp = byApp
        lastUpdateTime = now
    }

    /// 重排窗口：当前最前应用优先，然后按历史
    private func reSortWindows(_ arr: inout [WindowInfo], frontmostPid: pid_t?) {
        WindowHistoryManager.shared.cleanupClosedWindows(activeWindows: arr)
        arr.sort { w1, w2 in
            if let fpid = frontmostPid {
                if w1.processId == fpid && w2.processId != fpid { return true }
                if w2.processId == fpid && w1.processId != fpid { return false }
            }
            let w1h = WindowHistoryManager.shared.historyWeight(for: w1.id, processId: w1.processId)
            let w2h = WindowHistoryManager.shared.historyWeight(for: w2.id, processId: w2.processId)
            return w1h < w2h
        }
    }

    private func windowSemanticKey(processId: pid_t, title: String, ownerName: String) -> String {
        "\(processId):\(title.isEmpty ? ownerName : title)"
    }

    // MARK: - Activate

    func activateWindow(_ window: WindowInfo) {
        let runningApp = NSRunningApplication(processIdentifier: window.processId)
        runningApp?.unhide()

        if window.isMinimized {
            let pid = window.processId
            DispatchQueue.global(qos: .userInteractive).async {
                let appRef = AXUIElementCreateApplication(pid)
                var val: CFTypeRef?
                guard AXUIElementCopyAttributeValue(appRef, kAXWindowsAttribute as CFString, &val) == .success,
                      let axWindows = val as? [AXUIElement] else { return }

                if let target = self.bestMatchingAXWindow(for: window, in: axWindows) ?? axWindows.first {
                    var minVal: CFTypeRef?
                    if AXUIElementCopyAttributeValue(target, kAXMinimizedAttribute as CFString, &minVal) == .success,
                       (minVal as? Bool) == true {
                        AXUIElementSetAttributeValue(target, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
                    }
                    self.focusAXWindow(target)
                    DispatchQueue.main.async { _ = runningApp?.activate(options: [.activateIgnoringOtherApps]) }
                }
            }
            _ = runningApp?.activate(options: [.activateIgnoringOtherApps])
            return
        }

        // 非最小化窗口：按需获取 AX 元素激活（不在热路径，可接受少量 IPC）
        DispatchQueue.global(qos: .userInteractive).async {
            let appRef = AXUIElementCreateApplication(window.processId)
            var val: CFTypeRef?
            guard AXUIElementCopyAttributeValue(appRef, kAXWindowsAttribute as CFString, &val) == .success,
                  let axWindows = val as? [AXUIElement] else {
                DispatchQueue.main.async { _ = runningApp?.activate(options: [.activateIgnoringOtherApps]) }
                return
            }
            // 获取 CGWindowList 用于精确匹配 CGWindowID（解决最大化窗口位置相同的问题）
            let cgWindows = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] ?? []
            if let target = self.bestMatchingAXWindow(for: window, in: axWindows, cgWindows: cgWindows) ?? axWindows.first {
                self.focusAXWindow(target)
            }
            DispatchQueue.main.async { _ = runningApp?.activate(options: [.activateIgnoringOtherApps]) }
        }
    }

    // MARK: - Helpers

    private func bundleIdentifier(for pid: pid_t) -> String? {
        if let bid = bundleIdCache[pid] { return bid }
        if let app = NSRunningApplication(processIdentifier: pid), let bid = app.bundleIdentifier {
            bundleIdCache[pid] = bid; return bid
        }
        return nil
    }

    private func resolveWindowNameFromCache(
        cgWindowName: String, ownerName: String,
        processId: pid_t, boundsX: CGFloat, boundsY: CGFloat,
        windowDataCache: [pid_t: [CachedWindowData]],
        visibleWindowPositions: [CGPoint],
        windowZOrderIndex: Int = 0
    ) -> String {
        // 如果 CGWindow 已提供名称，直接使用
        if !cgWindowName.isEmpty && cgWindowName != ownerName { return cgWindowName }

        // 从缓存中按 position 匹配窗口标题（纯内存操作）
        // 只匹配当前 Space 可见的窗口（通过 visibleWindowPositions 过滤）
        // 当位置有多个匹配时，使用 z-order 索引选择正确的窗口
        if let windowDataList = windowDataCache[processId] {
            if let title = matchTitleByPosition(
                in: windowDataList,
                boundsX: boundsX, boundsY: boundsY,
                visiblePositions: visibleWindowPositions,
                windowZOrderIndex: windowZOrderIndex
            ), !title.isEmpty, title != ownerName {
                return title
            }
        }

        return ownerName
    }

    /// 纯内存 position 匹配（±20px 容差），只匹配当前 Space 可见的窗口
    /// 当位置有多个匹配时（如多个最大化窗口），使用 z-order 索引选择正确的窗口
    /// CGWindowList 和 AXUIElement 都按 z-order 返回窗口，所以索引是对齐的
    private func matchTitleByPosition(
        in windowDataList: [CachedWindowData],
        boundsX: CGFloat, boundsY: CGFloat,
        visiblePositions: [CGPoint],
        windowZOrderIndex: Int = 0
    ) -> String? {
        // 收集所有位置匹配的窗口，且该位置在当前 Space 可见（±20px 范围内）
        var matches: [String] = []

        for windowData in windowDataList {
            let pos = windowData.position
            // 1. 检查这个 AX 窗口是否与目标位置匹配（±20px）
            if abs(pos.x - boundsX) < 20 && abs(pos.y - boundsY) < 20 {
                // 2. 检查这个位置是否在当前 Space 的任何可见窗口附近（±20px）
                let isVisible = visiblePositions.contains(where: { visiblePos in
                    abs(visiblePos.x - pos.x) < 20 && abs(visiblePos.y - pos.y) < 20
                })

                if isVisible || windowData.isMinimized {
                    matches.append(windowData.title)
                }
            }
        }

        if matches.isEmpty { return nil }
        if matches.count == 1 { return matches[0] }

        // 多个匹配（位置相同，如多个最大化窗口）：使用 z-order 索引选择
        // CGWindowList 和 AXUIElement 都按 z-order 排列，索引是对齐的
        if windowZOrderIndex < matches.count {
            return matches[windowZOrderIndex]
        }

        return nil
    }

    private func bestMatchingAXWindow(for window: WindowInfo, in axWindows: [AXUIElement], cgWindows: [[String: Any]] = []) -> AXUIElement? {
        // 策略0：通过 CGWindowID + z-order 索引精确匹配（解决最大化窗口位置相同的问题）
        // CGWindowList 和 AXWindows 都按 z-order 返回窗口，顺序一致
        // 找到目标窗口在 CGWindowList 中的位置，然后取 AX 列表中同索引的元素
        if window.id != kCGNullWindowID && !cgWindows.isEmpty && !axWindows.isEmpty {
            // 过滤出同 pid 的 CGWindow，保持 z-order
            let samePidCGWindows = cgWindows.filter {
                guard let pid = $0[kCGWindowOwnerPID as String] as? pid_t else { return false }
                return pid == window.processId
            }
            // 找到目标窗口在过滤后的 CGWindowList 中的索引
            if let cgIndex = samePidCGWindows.firstIndex(where: {
                guard let wID = $0[kCGWindowNumber as String] as? CGWindowID else { return false }
                return wID == window.id
            }), cgIndex < axWindows.count {
                // 验证：确保取到的 AX 窗口标题与目标窗口标题一致
                let candidate = axWindows[cgIndex]
                if window.windowName.isEmpty {
                    // 目标窗口标题为空，直接返回索引匹配结果
                    return candidate
                } else if let title = axWindowTitle(candidate), title == window.windowName {
                    // 标题匹配，确认是目标窗口
                    return candidate
                }
                // 标题不匹配，说明 z-order 不一致，继续尝试其他策略
                // 但这种情况极少发生，直接返回 candidate 作为 fallback
                return candidate
            }
        }
        // 策略1：同时匹配位置和标题（解决最大化窗口位置相同的问题）
        if !window.windowName.isEmpty {
            for axWin in axWindows {
                if axWindowMatchesPosition(axWin, x: window.boundsX, y: window.boundsY),
                   let title = axWindowTitle(axWin), title == window.windowName {
                    return axWin
                }
            }
        }

        // 策略2：仅匹配位置（标题为空或策略1未命中）
        if let match = axWindows.first(where: { axWindowMatchesPosition($0, x: window.boundsX, y: window.boundsY) }) {
            return match
        }

        // 策略3：仅匹配标题
        if !window.windowName.isEmpty,
           let match = axWindows.first(where: { axWindowTitle($0) == window.windowName }) {
            return match
        }

        return nil
    }

    private func axWindowMatchesPosition(_ axWindow: AXUIElement, x: CGFloat, y: CGFloat) -> Bool {
        var posVal: CFTypeRef?
        AXUIElementCopyAttributeValue(axWindow, kAXPositionAttribute as CFString, &posVal)
        guard let pos = posVal else { return false }
        var point = CGPoint.zero
        guard AXValueGetValue(pos as! AXValue, .cgPoint, &point) else { return false }
        return abs(point.x - x) < 20 && abs(point.y - y) < 20
    }

    private func axWindowTitle(_ axWindow: AXUIElement) -> String? {
        var val: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axWindow, kAXTitleAttribute as CFString, &val) == .success else { return nil }
        return val as? String
    }

    private func focusAXWindow(_ axWindow: AXUIElement) {
        AXUIElementPerformAction(axWindow, kAXRaiseAction as CFString)
        AXUIElementSetAttributeValue(axWindow, kAXMainAttribute as CFString, kCFBooleanTrue)
        AXUIElementSetAttributeValue(axWindow, kAXFocusedAttribute as CFString, kCFBooleanTrue)
    }

    func getWindowsForApp(bundleId: String) -> [WindowInfo] {
        windowsByApp[bundleId] ?? []
    }

    func getCurrentWindowIndex() -> Int? {
        guard let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier else { return nil }
        return windows.firstIndex { $0.processId == pid }
    }
}
