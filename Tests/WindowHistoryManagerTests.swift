import XCTest
@testable import PurelyTab

final class WindowHistoryManagerTests: XCTestCase {

    override func setUp() {
        super.setUp()
        WindowHistoryManager.shared.clear()
    }

    override func tearDown() {
        WindowHistoryManager.shared.clear()
        super.tearDown()
    }

    // MARK: - 基础记录测试

    func testRecordSingleWindowAddsToHistory() {
        WindowHistoryManager.shared.recordSwitch(
            windowID: 42, processId: 100,
            ownerName: "Chrome", windowName: "GitHub"
        )

        XCTAssertEqual(WindowHistoryManager.shared.history.count, 1)
    }

    func testRecordSameWindowMovesToTop() {
        let mgr = WindowHistoryManager.shared

        mgr.recordSwitch(windowID: 1, processId: 100, ownerName: "A", windowName: "w1")
        mgr.recordSwitch(windowID: 2, processId: 100, ownerName: "A", windowName: "w2")
        // 再次选择第一个窗口，应移到最前
        mgr.recordSwitch(windowID: 1, processId: 100, ownerName: "A", windowName: "w1")

        XCTAssertEqual(mgr.history.count, 2, "去重后应只有 2 条")
        XCTAssertEqual(mgr.history.first?.windowID, 1, "重新选择的窗口应排第一")
    }

    func testHistoryIsLimitedToMaxCount() {
        let mgr = WindowHistoryManager.shared

        // 插入 25 条（超过 max=20）
        for i in 0..<25 {
            mgr.recordSwitch(
                windowID: CGWindowID(i), processId: 100,
                ownerName: "App", windowName: "w\(i)"
            )
        }

        XCTAssertEqual(mgr.history.count, 20, "应限制为 20 条")
    }

    // MARK: - 排序权重测试

    func testHistoryWeightRecentIsLower() {
        let mgr = WindowHistoryManager.shared

        mgr.recordSwitch(windowID: 1, processId: 100, ownerName: "A", windowName: "w1")
        mgr.recordSwitch(windowID: 2, processId: 100, ownerName: "A", windowName: "w2")
        mgr.recordSwitch(windowID: 3, processId: 100, ownerName: "A", windowName: "w3")

        // 最近插入的（windowID=3）权重最小
        XCTAssertEqual(mgr.historyWeight(for: 3, processId: 100), 0)
        XCTAssertEqual(mgr.historyWeight(for: 2, processId: 100), 1)
        XCTAssertEqual(mgr.historyWeight(for: 1, processId: 100), 2)
    }

    func testHistoryWeightNotInHistoryReturnsMax() {
        let mgr = WindowHistoryManager.shared

        let weight = mgr.historyWeight(for: 999, processId: 999)
        XCTAssertEqual(weight, Int.max, "不在历史中的窗口权重应为 Int.max")
    }

    // MARK: - 清理测试

    func testCleanupRemovesClosedWindows() {
        let mgr = WindowHistoryManager.shared

        mgr.recordSwitch(windowID: 1, processId: 100, ownerName: "A", windowName: "w1")
        mgr.recordSwitch(windowID: 2, processId: 100, ownerName: "A", windowName: "w2")
        mgr.recordSwitch(windowID: 3, processId: 100, ownerName: "A", windowName: "w3")

        // 模拟窗口 2 已关闭
        let activeWindows = [
            makeWindow(id: 1, pid: 100, ownerName: "A", windowName: "w1"),
            makeWindow(id: 3, pid: 100, ownerName: "A", windowName: "w3")
        ]

        mgr.cleanupClosedWindows(activeWindows: activeWindows)

        XCTAssertEqual(mgr.history.count, 2, "已关闭窗口的历史应被清理")
        XCTAssertFalse(mgr.isInHistory(windowID: 2, processId: 100), "已关闭窗口不应在历史中")
        XCTAssertTrue(mgr.isInHistory(windowID: 1, processId: 100))
        XCTAssertTrue(mgr.isInHistory(windowID: 3, processId: 100))
    }

    // MARK: - 去重测试

    func testRecordWindowAlreadyInHistoryDoesNotDuplicate() {
        let mgr = WindowHistoryManager.shared

        mgr.recordSwitch(windowID: 42, processId: 100, ownerName: "A", windowName: "w")
        mgr.recordSwitch(windowID: 42, processId: 100, ownerName: "A", windowName: "w")
        mgr.recordSwitch(windowID: 42, processId: 100, ownerName: "A", windowName: "w")

        XCTAssertEqual(mgr.history.count, 1, "同一窗口不应重复出现")
        XCTAssertEqual(mgr.historyWeight(for: 42, processId: 100), 0)
    }

    func testDifferentPidsWithSameWindowIDAreSeparate() {
        let mgr = WindowHistoryManager.shared

        mgr.recordSwitch(windowID: 1, processId: 100, ownerName: "Chrome", windowName: "tab")
        mgr.recordSwitch(windowID: 1, processId: 200, ownerName: "Safari", windowName: "tab")

        XCTAssertEqual(mgr.history.count, 2, "不同 pid 的相同 windowID 应分别存储")
    }

    // MARK: - 排序模拟测试

    func testSortByHistoryPutsRecentFirst() {
        let mgr = WindowHistoryManager.shared

        // 历史：B(最近) → A(较早)
        mgr.recordSwitch(windowID: 2, processId: 100, ownerName: "A", windowName: "B")
        mgr.recordSwitch(windowID: 1, processId: 100, ownerName: "A", windowName: "A")

        let windows = [
            makeWindow(id: 1, pid: 100, ownerName: "A", windowName: "A"),
            makeWindow(id: 2, pid: 100, ownerName: "A", windowName: "B"),
            makeWindow(id: 3, pid: 100, ownerName: "A", windowName: "C") // 无历史
        ]

        let sorted = windows.sorted { w1, w2 in
            let w1h = mgr.historyWeight(for: w1.id, processId: w1.processId)
            let w2h = mgr.historyWeight(for: w2.id, processId: w2.processId)
            return w1h < w2h
        }

        // 期望顺序：A(最近), B(较早), C(无历史)
        XCTAssertEqual(sorted[0].windowName, "A", "最近使用的应在最前面")
        XCTAssertEqual(sorted[1].windowName, "B")
        XCTAssertEqual(sorted[2].windowName, "C", "无历史的不应影响排序")
    }

    // MARK: - 当前最前窗口优先测试

    func testFrontmostWindowAlwaysFirst() {
        let mgr = WindowHistoryManager.shared

        // 历史：B(最近)
        mgr.recordSwitch(windowID: 2, processId: 100, ownerName: "Safari", windowName: "Safari")

        // C 属于当前最前应用 (pid=200)，即使不在历史中也应排第一
        let windows = [
            makeWindow(id: 2, pid: 100, ownerName: "Safari", windowName: "Safari"),
            makeWindow(id: 3, pid: 200, ownerName: "Chrome", windowName: "GitHub"),
            makeWindow(id: 1, pid: 100, ownerName: "Safari", windowName: "Another")
        ]

        let sorted = windows.sorted { w1, w2 in
            if w1.processId == 200 && w2.processId != 200 { return true }
            if w2.processId == 200 && w1.processId != 200 { return false }
            let w1h = mgr.historyWeight(for: w1.id, processId: w1.processId)
            let w2h = mgr.historyWeight(for: w2.id, processId: w2.processId)
            return w1h < w2h
        }

        // Chrome (200) 应排第一，然后 Safari 窗口按历史
        XCTAssertEqual(sorted[0].windowName, "GitHub", "当前最前应用的窗口应排第一")
        XCTAssertEqual(sorted[0].processId, 200)
        XCTAssertEqual(sorted[1].windowName, "Safari", "历史中最近的其次")
        XCTAssertEqual(sorted[2].windowName, "Another")
    }

    // MARK: - Helpers

    private func makeWindow(id: CGWindowID, pid: pid_t, ownerName: String, windowName: String) -> WindowInfo {
        WindowInfo(
            id: id, ownerName: ownerName, windowName: windowName,
            processId: pid, bundleIdentifier: "test.bundle",
            boundsX: 0, boundsY: 0, indexInApp: 1, isMinimized: false
        )
    }
}
