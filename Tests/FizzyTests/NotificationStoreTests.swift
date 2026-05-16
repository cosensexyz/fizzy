import XCTest
@testable import FizzyKit

final class NotificationStoreTests: XCTestCase {
    private func makeNotification(message: String = "test") -> ClaudeCodeNotification {
        ClaudeCodeNotification(
            sessionId: "s1",
            transcriptPath: "/tmp/t",
            cwd: "/tmp/project",
            hookEventName: "Notification",
            message: message,
            notificationType: "idle_prompt"
        )
    }

    func testAddPrependsItem() {
        let store = NotificationStore()
        let item = store.add(makeNotification(message: "first"))
        _ = store.add(makeNotification(message: "second"))

        XCTAssertEqual(store.items.count, 2)
        XCTAssertEqual(store.items[0].notification.message, "second")
        XCTAssertEqual(store.items[1].id, item.id)
    }

    func testUnreadCount() {
        let store = NotificationStore()
        _ = store.add(makeNotification())
        _ = store.add(makeNotification())

        XCTAssertEqual(store.unreadCount, 2)
    }

    func testMarkRead() {
        let store = NotificationStore()
        let item = store.add(makeNotification())

        store.markRead(id: item.id)

        XCTAssertTrue(store.items[0].isRead)
        XCTAssertEqual(store.unreadCount, 0)
    }

    func testDismiss() {
        let store = NotificationStore()
        let item = store.add(makeNotification())
        _ = store.add(makeNotification())

        store.dismiss(id: item.id)

        XCTAssertEqual(store.items.count, 1)
    }

    func testMarkAllRead() {
        let store = NotificationStore()
        _ = store.add(makeNotification())
        _ = store.add(makeNotification())

        store.markAllRead()

        XCTAssertEqual(store.unreadCount, 0)
    }
}
