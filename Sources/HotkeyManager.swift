import Cocoa
import Carbon

class HotkeyManager {
    private weak var appDelegate: AppDelegate?
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var tapRunLoop: CFRunLoop?          // 专用线程的 RunLoop
    private var tapThread: Thread?             // 专用线程
    private var tapMonitorTimer: Timer?
    private var isModifierPressed = false
    private var isPanelVisible = false
    private var isSameAppMode = false
    private var lastTabTime: Date = Date.distantPast

    // macOS 会在 tap 超时或用户输入时禁用 tap
    private static let tapDisabledByTimeout   = CGEventType(rawValue: UInt32(0xFFFFFFFE))!
    private static let tapDisabledByUserInput = CGEventType(rawValue: UInt32(0xFFFFFFFF))!

    init(appDelegate: AppDelegate) {
        self.appDelegate = appDelegate
    }

    func setup() {
        let trusted = checkAndRequestAccessibility()
        if trusted {
            startTapThread()
        }
        watchAccessibilityGrant()
    }

    // MARK: - Accessibility

    @discardableResult
    private func checkAndRequestAccessibility() -> Bool {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true]
        let trusted = AXIsProcessTrustedWithOptions(options)
        if !trusted {
            print("[HotkeyManager] Accessibility not granted — system prompt shown to user")
        }
        return trusted
    }

    private func watchAccessibilityGrant() {
        guard eventTap == nil else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self else { return }
            if self.eventTap != nil { return }
            if AXIsProcessTrusted() {
                print("[HotkeyManager] Accessibility granted — setting up event tap")
                self.startTapThread()
            } else {
                self.watchAccessibilityGrant()
            }
        }
    }

    // MARK: - Tap Thread
    // 把 event tap 放到独立线程的 RunLoop，完全不依赖主线程
    // 这样即使主线程在做 AX 调用，tap 也不会超时被系统禁用

    private func startTapThread() {
        // 如果已有 tap 在运行就不重复创建
        if let tap = eventTap, CGEvent.tapIsEnabled(tap: tap) { return }

        let thread = Thread { [weak self] in
            self?.runTapThreadLoop()
        }
        thread.name = "com.purelytab.eventtap"
        thread.qualityOfService = .userInteractive
        tapThread = thread
        thread.start()
    }

    /// 在专用线程上创建 tap 并跑 RunLoop
    private func runTapThreadLoop() {
        setupEventTap()
        // setupEventTap 成功后会把 source 加入当前 RunLoop，这里直接 run
        if eventTap != nil {
            tapRunLoop = CFRunLoopGetCurrent()
            CFRunLoopRun()   // 阻塞在这个线程，直到 cleanup 调用 CFRunLoopStop
        }
    }

    // MARK: - Event Tap

    private func setupEventTap() {
        // 先清理旧的（如果有）
        if let old = eventTap {
            CGEvent.tapEnable(tap: old, enable: false)
        }
        if let src = runLoopSource, let rl = tapRunLoop {
            CFRunLoopRemoveSource(rl, src, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil

        let eventMask = (1 << CGEventType.keyDown.rawValue) |
                        (1 << CGEventType.flagsChanged.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { proxy, type, event, refcon in
                HotkeyManager.handleEvent(proxy: proxy, type: type, event: event, refcon: refcon)
            },
            userInfo: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        ) else {
            print("[HotkeyManager] CGEvent.tapCreate failed — will retry in 1s")
            // 在专用线程上延迟重试
            DispatchQueue.global(qos: .userInteractive).asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.setupEventTap()
            }
            return
        }

        eventTap = tap
        // 关键：把 source 加入「当前线程」的 RunLoop（即专用 tap 线程，不是主线程）
        let src = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = src
        CFRunLoopAddSource(CFRunLoopGetCurrent(), src, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        print("[HotkeyManager] Event tap registered on dedicated thread ✅")

        // 在主线程启动监控定时器
        DispatchQueue.main.async { [weak self] in
            self?.startTapMonitor()
        }
    }

    // MARK: - Tap Monitor（在主线程跑的保险定时器）

    private func startTapMonitor() {
        tapMonitorTimer?.invalidate()
        tapMonitorTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkAndRestartTapIfNeeded()
        }
    }

    private func checkAndRestartTapIfNeeded() {
        guard let tap = eventTap else {
            // tap 完全丢失，重启整个线程
            startTapThread()
            return
        }
        if !CGEvent.tapIsEnabled(tap: tap) {
            print("[HotkeyManager] ⚠️ Tap was disabled, re-enabling...")
            // 先尝试直接重启
            CGEvent.tapEnable(tap: tap, enable: true)
            // 如果还不行，300ms 后重建
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                guard let self, let t = self.eventTap, !CGEvent.tapIsEnabled(tap: t) else { return }
                print("[HotkeyManager] Re-enabling failed, rebuilding tap thread...")
                // 停止旧线程 RunLoop
                if let rl = self.tapRunLoop { CFRunLoopStop(rl) }
                self.tapRunLoop = nil
                self.startTapThread()
            }
        }
    }

    func cleanup() {
        tapMonitorTimer?.invalidate()
        tapMonitorTimer = nil
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let src = runLoopSource, let rl = tapRunLoop {
            CFRunLoopRemoveSource(rl, src, .commonModes)
        }
        if let rl = tapRunLoop { CFRunLoopStop(rl) }
        eventTap = nil
        runLoopSource = nil
        tapRunLoop = nil
    }

    func setPanelVisible(_ visible: Bool, sameApp: Bool = false) {
        isPanelVisible = visible
        isSameAppMode = sameApp
    }

    // MARK: - Event Handler（在 tap 线程上被调用）

    private static func handleEvent(
        proxy: CGEventTapProxy,
        type: CGEventType,
        event: CGEvent,
        refcon: UnsafeMutableRawPointer?
    ) -> Unmanaged<CGEvent>? {

        // tap 被系统禁用时立即重建
        if type == tapDisabledByTimeout || type == tapDisabledByUserInput {
            print("[HotkeyManager] ⚠️ Tap disabled by system (type=\(type.rawValue)), rebuilding...")
            if let refcon {
                let manager = Unmanaged<HotkeyManager>.fromOpaque(refcon).takeUnretainedValue()
                // 在 tap 线程本身上重建（不跳回主线程，避免主线程阻塞时重建失败）
                manager.setupEventTap()
            }
            return nil
        }

        guard let refcon else { return Unmanaged.passRetained(event) }

        let manager = Unmanaged<HotkeyManager>.fromOpaque(refcon).takeUnretainedValue()
        let settings = SettingsManager.shared
        let modifierFlags = settings.getModifierFlags()

        // ── modifier 松开 → 选中当前项 ──
        if type == .flagsChanged {
            let flags = event.flags
            let modifierPressed = flags.contains(modifierFlags)
            if manager.isModifierPressed && !modifierPressed && manager.isPanelVisible {
                DispatchQueue.main.async { manager.appDelegate?.selectCurrentWindow() }
            }
            manager.isModifierPressed = modifierPressed
            return Unmanaged.passRetained(event)
        }

        guard type == .keyDown else { return Unmanaged.passRetained(event) }

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags
        let hasCommand = flags.contains(.maskCommand)
        let hasModifier = flags.contains(modifierFlags)
        let isReverse = flags.contains(.maskShift)

        // ⌘Tab = 48
        if keyCode == 48 && hasCommand {
            let now = Date()
            if now.timeIntervalSince(manager.lastTabTime) < 0.016 { return nil }
            manager.lastTabTime = now

            if !manager.isPanelVisible {
                DispatchQueue.main.async {
                    manager.isPanelVisible = true
                    manager.isSameAppMode = false
                    manager.appDelegate?.openWindowSwitcher(reverse: isReverse)
                }
            } else if !manager.isSameAppMode {
                DispatchQueue.main.async {
                    isReverse ? manager.appDelegate?.navigatePrevious()
                              : manager.appDelegate?.navigateNext()
                }
            }
            return nil
        }

        // Same-app switcher (` = 50 by default)
        if keyCode == settings.switchSameAppKey {
            if hasModifier && !manager.isPanelVisible {
                DispatchQueue.main.async {
                    manager.isPanelVisible = true
                    manager.isSameAppMode = true
                    manager.appDelegate?.openSameAppWindowSwitcher(reverse: isReverse)
                }
                return nil
            } else if manager.isPanelVisible {
                DispatchQueue.main.async {
                    isReverse ? manager.appDelegate?.navigatePrevious()
                              : manager.appDelegate?.navigateNext()
                }
                return nil
            }
        }

        // Escape = 53
        if keyCode == 53 && manager.isPanelVisible {
            DispatchQueue.main.async {
                manager.appDelegate?.hideWindowSwitcher()
                manager.isPanelVisible = false
            }
            return nil
        }

        // Return = 36
        if keyCode == 36 && manager.isPanelVisible {
            DispatchQueue.main.async { manager.appDelegate?.selectCurrentWindow() }
            return nil
        }

        return Unmanaged.passRetained(event)
    }
}
