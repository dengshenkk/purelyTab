import Cocoa

class HotkeyManager {
    private weak var appDelegate: AppDelegate?
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var isCommandPressed = false
    private var isPanelVisible = false

    init(appDelegate: AppDelegate) {
        self.appDelegate = appDelegate
    }

    func setup() {
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
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
    }

    func setPanelVisible(_ visible: Bool) {
        isPanelVisible = visible
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

        if type == .flagsChanged {
            let flags = event.flags
            let commandPressed = flags.contains(.maskCommand)

            // Command 释放时选择当前窗口
            if manager.isCommandPressed && !commandPressed && manager.isPanelVisible {
                DispatchQueue.main.async {
                    manager.appDelegate?.selectCurrentWindow()
                }
            }

            manager.isCommandPressed = commandPressed
            return Unmanaged.passRetained(event)
        }

        guard type == .keyDown else {
            return Unmanaged.passRetained(event)
        }

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags
        let hasCommand = flags.contains(.maskCommand)

        // Tab = 48 - 只有按住 Command 时才处理
        if keyCode == 48 && hasCommand {
            if !manager.isPanelVisible {
                // 面板未显示，打开它
                DispatchQueue.main.async {
                    manager.appDelegate?.showWindowSwitcher()
                    manager.isPanelVisible = true
                }
            } else {
                // 面板已显示，导航
                if flags.contains(.maskShift) {
                    DispatchQueue.main.async {
                        manager.appDelegate?.navigatePrevious()
                    }
                } else {
                    DispatchQueue.main.async {
                        manager.appDelegate?.navigateNext()
                    }
                }
            }
            return nil // 拦截事件
        }

        // ` = 50 - 切换同应用窗口
        if keyCode == 50 && hasCommand {
            if !manager.isPanelVisible {
                DispatchQueue.main.async {
                    manager.appDelegate?.showSameAppWindowSwitcher()
                    manager.isPanelVisible = true
                }
            }
            return nil
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
