import XCTest
@testable import PurelyTab

final class WindowInfoTests: XCTestCase {
    func testDisplayTitleUsesWindowNameWhenAvailable() {
        let window = makeWindow(windowName: "Document.txt")

        XCTAssertEqual(window.displayTitle(appWindowCount: 3), "Document.txt")
    }

    func testDisplayTitleFallsBackToOwnerNameWhenWindowNameIsEmpty() {
        let window = makeWindow(windowName: "", indexInApp: 2)

        XCTAssertEqual(window.displayTitle(appWindowCount: 3), "Example")
    }

    func testDisplayTitleDoesNotUseUntitledFallback() {
        let window = makeWindow(windowName: "")

        XCTAssertNotEqual(window.displayTitle(appWindowCount: 3), "无标题窗口")
    }

    func testDisplayTitleDoesNotAppendWindowIndexForEmptyTitle() {
        let window = makeWindow(windowName: "", indexInApp: 2)

        XCTAssertNotEqual(window.displayTitle(appWindowCount: 3), "Example - 2")
    }

    func testDisplayNameFallsBackToOwnerNameWhenWindowNameIsEmpty() {
        let window = makeWindow(windowName: "")

        XCTAssertEqual(window.displayName, "Example")
    }

    private func makeWindow(windowName: String, indexInApp: Int = 1) -> WindowInfo {
        let window = WindowInfo(
            id: 1,
            ownerName: "Example",
            windowName: windowName,
            processId: 100,
            bundleIdentifier: "com.example.app",
            boundsX: 0,
            boundsY: 0,
            indexInApp: indexInApp,
            isMinimized: false
        )

        return window
    }
}
