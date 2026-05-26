import XCTest
@testable import FizzyKit

final class SwitcherPanelTests: XCTestCase {
    // MARK: - projectName helper

    func testProjectNameFromPath() {
        let item = NotificationItem(
            notification: GenericPayload(message: "test", cwd: "/Users/angus/project/fizzy")
        )
        XCTAssertEqual(SwitcherPanel.projectName(for: item), "fizzy")
    }

    func testProjectNameFromRootPath() {
        let item = NotificationItem(
            notification: GenericPayload(message: "test", cwd: "/")
        )
        XCTAssertEqual(SwitcherPanel.projectName(for: item), "/")
    }

    func testProjectNameFromSingleComponent() {
        let item = NotificationItem(
            notification: GenericPayload(message: "test", cwd: "/myproject")
        )
        XCTAssertEqual(SwitcherPanel.projectName(for: item), "myproject")
    }

    // MARK: - Selection

    func testUpdateSelectionUpdatesIndex() {
        guard NSScreen.main != nil else { return }
        let items = makeItems(count: 3)
        let panel = SwitcherPanel(items: items, selectedIndex: 0)
        addTeardownBlock { panel.orderOut(nil) }

        panel.updateSelection(index: 2)
        XCTAssertEqual(panel.selectedIndex, 2)
    }

    func testUpdateSelectionUpdatesPreviewMessage() {
        guard NSScreen.main != nil else { return }
        let items = [
            NotificationItem(notification: GenericPayload(message: "first msg", cwd: "/tmp/a")),
            NotificationItem(notification: GenericPayload(message: "second msg", cwd: "/tmp/b")),
        ]
        let panel = SwitcherPanel(items: items, selectedIndex: 0)
        addTeardownBlock { panel.orderOut(nil) }

        panel.updateSelection(index: 1)
        XCTAssertEqual(panel.currentPreviewMessage, "second msg")
    }

    // MARK: - Helpers

    private func makeItems(count: Int) -> [NotificationItem] {
        (0..<count).map { i in
            NotificationItem(
                notification: GenericPayload(message: "msg \(i)", cwd: "/tmp/project\(i)")
            )
        }
    }
}
