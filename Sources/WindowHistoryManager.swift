import Cocoa

/// 窗口历史记录项
struct WindowHistoryItem: Hashable {
    let windowID: CGWindowID
    let processId: pid_t
    let ownerName: String
    let windowName: String
    let timestamp: Date

    /// 用于去重的唯一标识（pid + windowID 组合）
    var uniqueKey: String {
        "\(processId):\(windowID)"
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(uniqueKey)
    }

    static func == (lhs: WindowHistoryItem, rhs: WindowHistoryItem) -> Bool {
        lhs.uniqueKey == rhs.uniqueKey
    }
}

/// 窗口历史栈管理器
/// 记录最近切换的窗口顺序，用于按历史排序窗口列表
class WindowHistoryManager {
    static let shared = WindowHistoryManager()

    /// 最大历史记录数
    private let maxHistoryCount = 20

    /// 历史栈（最近的在前）
    private(set) var history: [WindowHistoryItem] = []

    /// 快速查找索引（用于去重）
    private var historyIndex: [String: Int] = [:]

    private init() {}

    // MARK: - Public API

    /// 记录窗口切换历史
    /// - Parameters:
    ///   - windowID: 窗口 ID
    ///   - processId: 进程 ID
    ///   - ownerName: 应用名称
    ///   - windowName: 窗口标题
    func recordSwitch(windowID: CGWindowID, processId: pid_t, ownerName: String, windowName: String) {
        let item = WindowHistoryItem(
            windowID: windowID,
            processId: processId,
            ownerName: ownerName,
            windowName: windowName,
            timestamp: Date()
        )

        // 去重：如果已存在，先移除旧的
        if let existingIndex = historyIndex[item.uniqueKey] {
            history.remove(at: existingIndex)
            rebuildIndex()
        }

        // 插入到最前面
        history.insert(item, at: 0)

        // 限制数量
        if history.count > maxHistoryCount {
            let removed = history.suffix(history.count - maxHistoryCount)
            for r in removed {
                historyIndex.removeValue(forKey: r.uniqueKey)
            }
            history = Array(history.prefix(maxHistoryCount))
        }

        // 更新索引
        rebuildIndex()
    }

    /// 获取窗口的历史排序权重（越大越靠前）
    /// - Returns: 历史位置索引，不在历史中返回 Int.max
    func historyWeight(for windowID: CGWindowID, processId: pid_t) -> Int {
        let key = "\(processId):\(windowID)"
        return historyIndex[key] ?? Int.max
    }

    /// 检查窗口是否在历史中
    func isInHistory(windowID: CGWindowID, processId: pid_t) -> Bool {
        let key = "\(processId):\(windowID)"
        return historyIndex[key] != nil
    }

    /// 清理已关闭窗口的历史记录
    /// - Parameter activeWindows: 当前活跃的窗口列表
    func cleanupClosedWindows(activeWindows: [WindowInfo]) {
        let activeKeys = Set(activeWindows.map { "\($0.processId):\($0.id)" })

        // 过滤掉已关闭的窗口
        let originalCount = history.count
        history = history.filter { activeKeys.contains($0.uniqueKey) }

        if history.count != originalCount {
            rebuildIndex()
        }
    }

    /// 清空历史
    func clear() {
        history.removeAll()
        historyIndex.removeAll()
    }

    // MARK: - Private

    private func rebuildIndex() {
        historyIndex.removeAll()
        for (index, item) in history.enumerated() {
            historyIndex[item.uniqueKey] = index
        }
    }
}
