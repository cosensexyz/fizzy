import XCTest
@testable import FizzyKit

final class NotificationStoreTests: XCTestCase {
    private func makePayload(message: String = "test", sessionId: String = "s1") -> ClaudeCodePayload {
        ClaudeCodePayload(
            sessionId: sessionId, transcriptPath: "/tmp/t", cwd: "/tmp/project",
            hookEventName: "Notification", message: message,
            notificationType: "idle_prompt"
        )
    }

    func testAddPrependsItem() {
        let store = NotificationStore()
        let item = store.add(makePayload(message: "first", sessionId: "s1"))
        _ = store.add(makePayload(message: "second", sessionId: "s2"))

        XCTAssertEqual(store.items.count, 2)
        XCTAssertEqual(store.items[0].notification.message, "second")
        XCTAssertEqual(store.items[1].id, item.id)
    }

    func testUnreadCount() {
        let store = NotificationStore()
        _ = store.add(makePayload(sessionId: "s1"))
        _ = store.add(makePayload(sessionId: "s2"))

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
        let item = store.add(makePayload(message: "first", sessionId: "s1"))
        _ = store.add(makePayload(message: "second", sessionId: "s2"))

        store.dismiss(id: item.id)

        XCTAssertEqual(store.items.count, 1)
    }

    func testMarkAllRead() {
        let store = NotificationStore()
        _ = store.add(makePayload(sessionId: "s1"))
        _ = store.add(makePayload(sessionId: "s2"))

        store.markAllRead()

        XCTAssertEqual(store.items.count, 2)
        XCTAssertEqual(store.unreadCount, 0)
    }

    func testAddWithEnv() {
        let store = NotificationStore()
        let env = EnvironmentContext(gitBranch: "main")
        let item = store.add(makePayload(), agent: "claude_code", env: env)

        XCTAssertEqual(item.agent, "claude_code")
        XCTAssertEqual(item.env.gitBranch, "main")
    }

    func testAddDedupsBySessionId() {
        let store = NotificationStore()
        _ = store.add(makePayload(message: "first", sessionId: "s1"))
        _ = store.add(makePayload(message: "second", sessionId: "s1"))

        XCTAssertEqual(store.items.count, 1)
        XCTAssertEqual(store.items[0].notification.message, "second")
    }

    func testAddDoesNotDedupDifferentSessions() {
        let store = NotificationStore()
        _ = store.add(makePayload(message: "first", sessionId: "s1"))
        _ = store.add(makePayload(message: "second", sessionId: "s2"))

        XCTAssertEqual(store.items.count, 2)
    }

    func testAddDedupsScopedByAgent() {
        let store = NotificationStore()
        _ = store.add(makePayload(message: "claude", sessionId: "s1"), agent: "claude_code")
        _ = store.add(
            GenericPayload(message: "codex", cwd: "/tmp", sessionId: "s1"),
            agent: "codex"
        )

        XCTAssertEqual(store.items.count, 2)
        XCTAssertEqual(store.items[0].notification.message, "codex")
        XCTAssertEqual(store.items[1].notification.message, "claude")
    }

    func testAddDoesNotDedupGenericPayload() {
        let store = NotificationStore()
        let first = GenericPayload(message: "first", cwd: "/tmp")
        let second = GenericPayload(message: "second", cwd: "/tmp")
        _ = store.add(first)
        _ = store.add(second)

        XCTAssertEqual(store.items.count, 2)
    }

    func testDedupNewItemIsUnread() {
        let store = NotificationStore()
        let item1 = store.add(makePayload(message: "first", sessionId: "s1"))
        store.markRead(id: item1.id)
        _ = store.add(makePayload(message: "second", sessionId: "s1"))

        XCTAssertFalse(store.items[0].isRead)
        XCTAssertEqual(store.unreadCount, 1)
    }

    func testEndSessionRemovesMatchingItem() {
        let store = NotificationStore()
        _ = store.add(makePayload(message: "active", sessionId: "s1"), agent: "claude_code")
        _ = store.add(makePayload(message: "other", sessionId: "s2"), agent: "claude_code")

        store.endSession(agent: "claude_code", sessionId: "s1")

        XCTAssertEqual(store.items.count, 1)
        XCTAssertEqual(store.items[0].notification.message, "other")
    }

    func testEndSessionDoesNotRemoveOtherAgents() {
        let store = NotificationStore()
        _ = store.add(makePayload(message: "claude", sessionId: "s1"), agent: "claude_code")
        _ = store.add(
            GenericPayload(message: "codex", cwd: "/tmp", sessionId: "s1"),
            agent: "codex"
        )

        store.endSession(agent: "claude_code", sessionId: "s1")

        XCTAssertEqual(store.items.count, 1)
        XCTAssertEqual(store.items[0].notification.message, "codex")
    }

    func testEndSessionNoMatchIsNoop() {
        let store = NotificationStore()
        _ = store.add(makePayload(message: "active", sessionId: "s1"), agent: "claude_code")

        store.endSession(agent: "claude_code", sessionId: "nonexistent")

        XCTAssertEqual(store.items.count, 1)
    }
}
