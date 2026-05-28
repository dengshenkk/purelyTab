import Cocoa

class SettingsManager: ObservableObject {
    static let shared = SettingsManager()

    // Window appearance
    @Published var thumbnailSize: NSSize = NSSize(width: 300, height: 200)
    @Published var maxColumns: Int = 5
    @Published var showWindowTitles: Bool = true
    @Published var backgroundColor: NSColor = NSColor.black.withAlphaComponent(0.8)
    @Published var borderColor: NSColor = NSColor.systemBlue
    @Published var cornerRadius: CGFloat = 12

    // Behavior
    @Published var hideSelfFromList: Bool = true
    @Published var showMinimizedWindows: Bool = true
    @Published var showHiddenWindows: Bool = false

    // Shortcuts
    @Published var shortcutModifier: NSEvent.ModifierFlags = .command
    @Published var shortcutKey: String = "Tab"

    // Language
    @Published var language: String = "auto" // "auto", "en", "zh"

    private let defaults = UserDefaults.standard

    private init() {
        load()
    }

    func load() {
        // Load thumbnail size
        if let width = defaults.value(forKey: "thumbnailWidth") as? CGFloat,
           let height = defaults.value(forKey: "thumbnailHeight") as? CGFloat {
            thumbnailSize = NSSize(width: width, height: height)
        }

        maxColumns = defaults.integer(forKey: "maxColumns")
        if maxColumns == 0 { maxColumns = 5 }

        showWindowTitles = defaults.object(forKey: "showWindowTitles") as? Bool ?? true

        if let bgColorData = defaults.data(forKey: "backgroundColor"),
           let bgColor = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: bgColorData) {
            backgroundColor = bgColor
        }

        if let borderColorData = defaults.data(forKey: "borderColor"),
           let borderColor = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: borderColorData) {
            self.borderColor = borderColor
        }

        cornerRadius = defaults.double(forKey: "cornerRadius")
        if cornerRadius == 0 { cornerRadius = 12 }

        hideSelfFromList = defaults.object(forKey: "hideSelfFromList") as? Bool ?? true
        showMinimizedWindows = defaults.object(forKey: "showMinimizedWindows") as? Bool ?? true
        showHiddenWindows = defaults.object(forKey: "showHiddenWindows") as? Bool ?? false

        if let lang = defaults.string(forKey: "language") {
            language = lang
        }
    }

    func save() {
        defaults.set(thumbnailSize.width, forKey: "thumbnailWidth")
        defaults.set(thumbnailSize.height, forKey: "thumbnailHeight")
        defaults.set(maxColumns, forKey: "maxColumns")
        defaults.set(showWindowTitles, forKey: "showWindowTitles")

        if let bgColorData = try? NSKeyedArchiver.archivedData(withRootObject: backgroundColor, requiringSecureCoding: false) {
            defaults.set(bgColorData, forKey: "backgroundColor")
        }

        if let borderColorData = try? NSKeyedArchiver.archivedData(withRootObject: borderColor, requiringSecureCoding: false) {
            defaults.set(borderColorData, forKey: "borderColor")
        }

        defaults.set(cornerRadius, forKey: "cornerRadius")
        defaults.set(hideSelfFromList, forKey: "hideSelfFromList")
        defaults.set(showMinimizedWindows, forKey: "showMinimizedWindows")
        defaults.set(showHiddenWindows, forKey: "showHiddenWindows")
        defaults.set(language, forKey: "language")

        defaults.synchronize()
    }

    func resetToDefaults() {
        thumbnailSize = NSSize(width: 300, height: 200)
        maxColumns = 5
        showWindowTitles = true
        backgroundColor = NSColor.black.withAlphaComponent(0.8)
        borderColor = NSColor.systemBlue
        cornerRadius = 12
        hideSelfFromList = true
        showMinimizedWindows = true
        showHiddenWindows = false
        language = "auto"
    }
}
