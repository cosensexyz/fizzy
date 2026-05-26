import XCTest
@testable import FizzyKit

final class CycleSessionControllerTests: XCTestCase {
    private func makeController(items: [NotificationItem]? = nil) -> (CycleSessionController, NotificationStore) {
        let store = NotificationStore()
        if let items = items {
            for item in items.reversed() {
                _ = store.add(item.notification, agent: item.agent, env: item.env)
            }
        }
        let controller = CycleSessionController(
            store: store,
            config: { CycleConfig(displayMode: .previewOnly) }
        )
        return (controller, store)
    }

    private func makeItem(message: String, cwd: String = "/tmp/project") -> NotificationItem {
        NotificationItem(notification: GenericPayload(message: message, cwd: cwd))
    }

    // MARK: - Start

    func testStartWithEmptyStoreStaysIdle() {
        let (controller, _) = makeController()
        controller.startSession()
        XCTAssertFalse(controller.isActive)
    }

    func testStartSelectsFirstItem() {
        let (controller, _) = makeController(items: [
            makeItem(message: "a"), makeItem(message: "b")
        ])
        controller.startSession()
        XCTAssertTrue(controller.isActive)
        XCTAssertEqual(controller.selectedIndex, 0)
    }

    // MARK: - Cycle forward

    func testCycleForward() {
        let (controller, _) = makeController(items: [
            makeItem(message: "a"), makeItem(message: "b"), makeItem(message: "c")
        ])
        controller.startSession()

        controller.cycleForward()
        XCTAssertEqual(controller.selectedIndex, 1)

        controller.cycleForward()
        XCTAssertEqual(controller.selectedIndex, 2)
    }

    func testCycleForwardWraps() {
        let (controller, _) = makeController(items: [
            makeItem(message: "a"), makeItem(message: "b")
        ])
        controller.startSession()

        controller.cycleForward()
        XCTAssertEqual(controller.selectedIndex, 1)

        controller.cycleForward()
        XCTAssertEqual(controller.selectedIndex, 0)
    }

    // MARK: - Cycle backward

    func testCycleBackwardWraps() {
        let (controller, _) = makeController(items: [
            makeItem(message: "a"), makeItem(message: "b"), makeItem(message: "c")
        ])
        controller.startSession()

        controller.cycleBackward()
        XCTAssertEqual(controller.selectedIndex, 2)
    }

    func testCycleBackwardThenForward() {
        let (controller, _) = makeController(items: [
            makeItem(message: "a"), makeItem(message: "b"), makeItem(message: "c")
        ])
        controller.startSession()

        controller.cycleBackward()
        XCTAssertEqual(controller.selectedIndex, 2)

        controller.cycleForward()
        XCTAssertEqual(controller.selectedIndex, 0)
    }

    // MARK: - Activate

    func testActivateCallsCallbackWithSelectedItem() {
        let (controller, store) = makeController(items: [
            makeItem(message: "first"), makeItem(message: "second")
        ])

        var activatedMessage: String?
        controller.onOpenSession = { activatedMessage = $0.notification.message }

        controller.startSession()
        controller.cycleForward()
        controller.activate()

        XCTAssertFalse(controller.isActive)
        XCTAssertEqual(activatedMessage, "second")
        XCTAssertEqual(store.items.count, 1)
    }

    func testActivateWithoutCyclingActivatesFirst() {
        let (controller, store) = makeController(items: [
            makeItem(message: "only")
        ])

        var activatedMessage: String?
        controller.onOpenSession = { activatedMessage = $0.notification.message }

        controller.startSession()
        controller.activate()

        XCTAssertEqual(activatedMessage, "only")
        XCTAssertEqual(store.items.count, 0)
    }

    // MARK: - Cancel

    func testCancelResetsWithoutDismissing() {
        let (controller, store) = makeController(items: [
            makeItem(message: "a"), makeItem(message: "b")
        ])

        var callbackCalled = false
        controller.onOpenSession = { _ in callbackCalled = true }

        controller.startSession()
        controller.cycleForward()
        controller.cancel()

        XCTAssertFalse(controller.isActive)
        XCTAssertEqual(controller.selectedIndex, 0)
        XCTAssertFalse(callbackCalled)
        XCTAssertEqual(store.items.count, 2)
    }

    // MARK: - No-op when inactive

    func testCycleForwardWhenInactiveIsNoOp() {
        let (controller, _) = makeController(items: [makeItem(message: "a")])
        controller.cycleForward()
        XCTAssertFalse(controller.isActive)
        XCTAssertEqual(controller.selectedIndex, 0)
    }

    func testActivateWhenInactiveIsNoOp() {
        let (controller, _) = makeController(items: [makeItem(message: "a")])
        var called = false
        controller.onOpenSession = { _ in called = true }
        controller.activate()
        XCTAssertFalse(called)
    }
}
