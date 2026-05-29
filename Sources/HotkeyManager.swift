import Cocoa
import Carbon

class HotkeyManager {
    private weak var appDelegate: AppDelegate?
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var isModifierPressed = false
    private var isPanelVisible = false
    private var isSameAppMode = false

    // Carbon 热键引用
    private var hotKeyRef: EventHotKeyRef?
    private var hotKeyID = EventHotKeyID(signature: OSType(0x5054), id: 1) // PT

    init(appDelegate: AppDelegate) {
        self.appDelegate = appDelegate
    }

    func setup() {
        // 注册 Carbon 热键拦截系统 ⌘+Tab
        registerCarbonHotKey()

        // 保留 CGEventTap 处理其他按键（`、Escape、Return 等）
        setupEventTap()
    }

    private func registerCarbonHotKey() {
        // 安装事件处理器
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        // 注册回调
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, event, _) -> OSStatus in
                // 在回调中处理热键
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .carbonHotKeyPressed, object: nil)
                }
                return noErr
            },
            1,
            &eventType,
            nil,
            nil
        )

        guard status == noErr else {
            print("Failed to install Carbon event handler: \(status)")
            return
        }

        // 注册 ⌘+Tab 热键
        let modifiers = UInt32(cmdKey)
        let keyCode: UInt32 = 48 // Tab key

        hotKeyID.signature = OSType(0x5054) // 'PT'
        hotKeyID.id = 1

        let regStatus = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        if regStatus == noErr {
            print("Carbon hotkey registered successfully")
        } else {
            print("Failed to register Carbon hotkey: \(regStatus)")
        }

        // 监听热键通知
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleCarbonHotKey),
            name: .carbonHotKeyPressed,
            object: nil
        )
    }

    @objc private func handleCarbonHotKey() {
        print("Carbon hotkey triggered")
        if !isPanelVisible {
            appDelegate?.showWindowSwitcher()
            isPanelVisible = true
            isSameAppMode = false
        } else if !isSameAppMode {
            appDelegate?.navigateNext()
        }
    }

    private func setupEventTap() {
        let eventMask = (1 << CGEventType.keyDown.rawValue) |
                        (1 << CGEventType.flagsChanged.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { proxy, type, event, refcon in
                return HotkeyManager.handleEvent(proxy: proxy, type: type, event: event, refcon: refcon)
            },
            userInfo: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        ) else {
            print("Failed to create event tap - need Accessibility permission")
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        print("Event tap created successfully")
    }

    func cleanup() {
        // 注销 Carbon 热键
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
        }

        // 清理事件处理器
        NotificationCenter.default.removeObserver(self)

        // 清理 CGEventTap
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
    }

    func setPanelVisible(_ visible: Bool, sameApp: Bool = false) {
        isPanelVisible = visible
        isSameAppMode = sameApp
    }

    private static func handleEvent(
        proxy: CGEventTapProxy,
        type: CGEventType,
        event: CGEvent,
        refcon: UnsafeMutableRawPointer?
    ) -> Unmanaged<CGEvent>? {
        guard let refcon = refcon else {
            return Unmanaged.passRetained(event)
        }

        let manager = Unmanaged<HotkeyManager>.fromOpaque(refcon).takeUnretainedValue()
        let settings = SettingsManager.shared
        let modifierFlags = settings.getModifierFlags()

        if type == .flagsChanged {
            let flags = event.flags
            let modifierPressed = flags.contains(modifierFlags)

            if manager.isModifierPressed && !modifierPressed && manager.isPanelVisible {
                DispatchQueue.main.async {
                    manager.appDelegate?.selectCurrentWindow()
                }
            }

            manager.isModifierPressed = modifierPressed
            return Unmanaged.passRetained(event)
        }

        guard type == .keyDown else {
            return Unmanaged.passRetained(event)
        }

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags
        let hasModifier = flags.contains(modifierFlags)

        print("Key pressed: keyCode=\(keyCode), hasModifier=\(hasModifier), isPanelVisible=\(manager.isPanelVisible)")

        // ` = 50
        if keyCode == settings.switchSameAppKey {
            print("` key detected, hasModifier=\(hasModifier), isPanelVisible=\(manager.isPanelVisible)")
            if hasModifier && !manager.isPanelVisible {
                print("Opening same app window switcher")
                DispatchQueue.main.async {
                    manager.appDelegate?.showSameAppWindowSwitcher()
                    manager.isPanelVisible = true
                    manager.isSameAppMode = true
                }
                return nil
            } else if manager.isPanelVisible {
                print("Navigating next in panel")
                DispatchQueue.main.async {
                    manager.appDelegate?.navigateNext()
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
            DispatchQueue.main.async {
                manager.appDelegate?.selectCurrentWindow()
            }
            return nil
        }

        return Unmanaged.passRetained(event)
    }
}

extension Notification.Name {
    static let carbonHotKeyPressed = Notification.Name("carbonHotKeyPressed")
}
