import XCTest
@testable import FizzyKit

final class NotificationStoreTests: XCTestCase {
    private func makePayload(message: String = "test") -> ClaudeCodePayload {
        ClaudeCodePayload(
            sessionId: "s1", transcriptPath: "/tmp/t", cwd: "/tmp/project",
            hookEventName: "Notification", message: message,
            notificationType: "idle_prompt"
        )
    }

    func testAddPrependsItem() {
        let store = NotificationStore()
        let item = store.add(makePayload(message: "first"))
        _ = store.add(makePayload(message: "second"))

        XCTAssertEqual(store.items.count, 2)
        XCTAssertEqual(store.items[0].notification.message, "second")
        XCTAssertEqual(store.items[1].id, item.id)
    }

    func testUnreadCount() {
        let store = NotificationStore()
        _ = store.add(makePayload())
        _ = store.add(makePayload())

        XCTAssertEqual(store.unreadCount, 2)
    }

    func testMarkRead() {
        let store = NotificationStore()
        let item = store.add(makePayload())

        store.markRead(id: item.id)

        XCTAssertTrue(store.items[0].isRead)
        XCTAssertEqual(store.unreadCount, 0)
    }

    func testDismiss() {
        let store = NotificationStore()
        let item = store.add(makePayload())
        _ = store.add(makePayload())

        store.dismiss(id: item.id)

        XCTAssertEqual(store.items.count, 1)
    }

    func testMarkAllRead() {
        let store = NotificationStore()
        _ = store.add(makePayload())
        _ = store.add(makePayload())

        store.markAllRead()

        XCTAssertEqual(store.unreadCount, 0)
    }

    func testAddWithEnv() {
        let store = NotificationStore()
        let env = EnvironmentContext(gitBranch: "main")
        let item = store.add(makePayload(), agent: "claude_code", env: env)

        XCTAssertEqual(item.agent, "claude_code")
        XCTAssertEqual(item.env.gitBranch, "main")
    }
}
