import Foundation

/// 管理开机自动启动
class LaunchAgentManager {
    static let shared = LaunchAgentManager()

    private let bundleIdentifier = "com.purelytab.app"
    private let launchAgentFileName: String

    private init() {
        launchAgentFileName = "\(bundleIdentifier).plist"
    }

    /// LaunchAgents plist 文件路径
    private var launchAgentPath: String {
        let libraryDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library")
            .appendingPathComponent("LaunchAgents")
        return libraryDir.appendingPathComponent(launchAgentFileName).path
    }

    /// 应用可执行文件路径
    private var appExecutablePath: String {
        guard let appPath = Bundle.main.bundlePath as NSString? else {
            return ""
        }
        return appPath.appendingPathComponent("Contents/MacOS/PurelyTab")
    }

    /// 当前是否已启用开机启动
    var isEnabled: Bool {
        FileManager.default.fileExists(atPath: launchAgentPath)
    }

    /// 设置是否开机启动
    func setEnabled(_ enabled: Bool) {
        if enabled {
            enable()
        } else {
            disable()
        }
    }

    /// 启用开机启动
    private func enable() {
        // 如果已经存在，先删除旧的
        if FileManager.default.fileExists(atPath: launchAgentPath) {
            disable()
        }

        // 确保 LaunchAgents 目录存在
        let launchAgentsDir = (launchAgentPath as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(
            atPath: launchAgentsDir,
            withIntermediateDirectories: true,
            attributes: nil
        )

        // 创建 plist 内容
        let plistContent = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>\(bundleIdentifier)</string>
            <key>ProgramArguments</key>
            <array>
                <string>\(appExecutablePath)</string>
            </array>
            <key>RunAtLoad</key>
            <true/>
            <key>KeepAlive</key>
            <false/>
            <key>StandardOutPath</key>
            <string>/tmp/purelytab.stdout.log</string>
            <key>StandardErrorPath</key>
            <string>/tmp/purelytab.stderr.log</string>
        </dict>
        </plist>
        """

        do {
            try plistContent.write(toFile: launchAgentPath, atomically: true, encoding: .utf8)
            print("[LaunchAgentManager] LaunchAgent created at \(launchAgentPath)")
        } catch {
            print("[LaunchAgentManager] Failed to create LaunchAgent: \(error)")
        }
    }

    /// 禁用开机启动
    private func disable() {
        guard FileManager.default.fileExists(atPath: launchAgentPath) else { return }

        do {
            try FileManager.default.removeItem(atPath: launchAgentPath)
            print("[LaunchAgentManager] LaunchAgent removed")
        } catch {
            print("[LaunchAgentManager] Failed to remove LaunchAgent: \(error)")
        }
    }
}
