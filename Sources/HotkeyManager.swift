import Cocoa

class HotkeyManager {
    private weak var appDelegate: AppDelegate?
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var isModifierPressed = false
    private var isPanelVisible = false
    private var isSameAppMode = false

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

        // Tab = 48
        if keyCode == settings.switchAllKey && hasModifier {
            print("Tab with modifier detected")
            if !manager.isPanelVisible {
                DispatchQueue.main.async {
                    manager.appDelegate?.showWindowSwitcher()
                    manager.isPanelVisible = true
                    manager.isSameAppMode = false
                }
            } else if !manager.isSameAppMode {
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
            return nil
        }

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
