import Cocoa

class SettingsManager: ObservableObject {
    static let shared = SettingsManager()

    // 显示设置
    @Published var showInMenuBar: Bool = true

    private let defaults = UserDefaults.standard

    private init() {
        load()
    }

    func load() {
        showInMenuBar = defaults.object(forKey: "showInMenuBar") as? Bool ?? true
    }

    func save() {
        defaults.set(showInMenuBar, forKey: "showInMenuBar")
        defaults.synchronize()
    }
}
