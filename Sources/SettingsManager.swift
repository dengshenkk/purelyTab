import Cocoa

class SettingsManager: ObservableObject {
    static let shared = SettingsManager()

    // 显示设置
    @Published var showInMenuBar: Bool = true
    @Published var panelPosition: String = "center"  // center, mouse

    // 快捷键设置
    @Published var modifierKey: String = "command"
    @Published var switchAllKey: Int = 48
    @Published var switchSameAppKey: Int = 50

    private let defaults = UserDefaults.standard

    private init() {
        load()
    }

    func load() {
        showInMenuBar = defaults.object(forKey: "showInMenuBar") as? Bool ?? true
        panelPosition = defaults.string(forKey: "panelPosition") ?? "center"
        modifierKey = defaults.string(forKey: "modifierKey") ?? "command"
        switchAllKey = defaults.integer(forKey: "switchAllKey")
        if switchAllKey == 0 { switchAllKey = 48 }
        switchSameAppKey = defaults.integer(forKey: "switchSameAppKey")
        if switchSameAppKey == 0 { switchSameAppKey = 50 }
    }

    func save() {
        defaults.set(showInMenuBar, forKey: "showInMenuBar")
        defaults.set(panelPosition, forKey: "panelPosition")
        defaults.set(modifierKey, forKey: "modifierKey")
        defaults.set(switchAllKey, forKey: "switchAllKey")
        defaults.set(switchSameAppKey, forKey: "switchSameAppKey")
        defaults.synchronize()
    }

    func getModifierFlags() -> CGEventFlags {
        switch modifierKey {
        case "option":
            return .maskAlternate
        case "control":
            return .maskControl
        default:
            return .maskCommand
        }
    }
}
