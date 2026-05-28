import Cocoa
import CoreImage

struct WindowInfo: Identifiable {
    let id: CGWindowID
    let ownerName: String
    let windowName: String
    let bounds: CGRect
    let thumbnail: NSImage?
    let processId: pid_t
    let isOnScreen: Bool

    var displayName: String {
        if !windowName.isEmpty && windowName != ownerName {
            return "\(ownerName) - \(windowName)"
        }
        return ownerName
    }
}

class WindowManager {
    private(set) var windows: [WindowInfo] = []

    func updateWindowList() {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            windows = []
            return
        }

        var result: [WindowInfo] = []

        for windowInfo in windowList {
            guard let windowID = windowInfo[kCGWindowNumber as String] as? CGWindowID,
                  let ownerName = windowInfo[kCGWindowOwnerName as String] as? String,
                  let boundsDict = windowInfo[kCGWindowBounds as String] as? [String: CGFloat],
                  let processID = windowInfo[kCGWindowOwnerPID as String] as? pid_t else {
                continue
            }

            // Skip windows without proper bounds
            let bounds = CGRect(
                x: boundsDict["X"] ?? 0,
                y: boundsDict["Y"] ?? 0,
                width: boundsDict["Width"] ?? 0,
                height: boundsDict["Height"] ?? 0
            )

            guard bounds.width > 100 && bounds.height > 100 else { continue }

            // Skip our own app
            if processID == getpid() { continue }

            // Skip system UI elements
            if ownerName == "Window Server" || ownerName == "Dock" { continue }

            let windowName = windowInfo[kCGWindowName as String] as? String ?? ""
            let isOnScreen = windowInfo[kCGWindowIsOnscreen as String] as? Bool ?? false

            // Get window thumbnail
            let thumbnail = captureWindowThumbnail(windowID: windowID, bounds: bounds)

            let info = WindowInfo(
                id: windowID,
                ownerName: ownerName,
                windowName: windowName,
                bounds: bounds,
                thumbnail: thumbnail,
                processId: processID,
                isOnScreen: isOnScreen
            )

            result.append(info)
        }

        // Sort windows: frontmost first
        result.sort { $0.bounds.origin.y > $1.bounds.origin.y }

        windows = result
    }

    private func captureWindowThumbnail(windowID: CGWindowID, bounds: CGRect) -> NSImage? {
        let windowRect = CGRect(
            x: bounds.origin.x,
            y: bounds.origin.y,
            width: bounds.width,
            height: bounds.height
        )

        guard let cgImage = CGWindowListCreateImage(
            windowRect,
            .optionIncludingWindow,
            windowID,
            [.boundsIgnoreFraming, .nominalResolution]
        ) else {
            return nil
        }

        let thumbnailSize = SettingsManager.shared.thumbnailSize
        let targetWidth = thumbnailSize.width
        let targetHeight = thumbnailSize.height

        // Calculate aspect ratio
        let aspectRatio = CGFloat(cgImage.width) / CGFloat(cgImage.height)
        let targetAspect = targetWidth / targetHeight

        var newWidth: CGFloat
        var newHeight: CGFloat

        if aspectRatio > targetAspect {
            newWidth = targetWidth
            newHeight = targetWidth / aspectRatio
        } else {
            newHeight = targetHeight
            newWidth = targetHeight * aspectRatio
        }

        // Create thumbnail using CIImage for better quality
        let ciImage = CIImage(cgImage: cgImage)
        let scaleTransform = CGAffineTransform(scaleX: newWidth / CGFloat(cgImage.width), y: newHeight / CGFloat(cgImage.height))
        let scaledCIImage = ciImage.transformed(by: scaleTransform)

        let context = CIContext(options: nil)
        guard let thumbnailCGImage = context.createCGImage(scaledCIImage, from: scaledCIImage.extent) else {
            return nil
        }

        return NSImage(cgImage: thumbnailCGImage, size: NSSize(width: newWidth, height: newHeight))
    }

    func activateWindow(_ window: WindowInfo) {
        // Use NSWorkspace to activate the application
        let runningApps = NSWorkspace.shared.runningApplications
        for app in runningApps {
            if app.processIdentifier == window.processId {
                app.activate(options: [.activateIgnoringOtherApps])
                break
            }
        }
    }

    func getWindow(at index: Int) -> WindowInfo? {
        guard index >= 0 && index < windows.count else { return nil }
        return windows[index]
    }
}