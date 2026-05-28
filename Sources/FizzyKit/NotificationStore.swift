import Foundation

public final class NotificationStore {
    public private(set) var items: [NotificationItem] = []

    public var unreadCount: Int {
        items.filter { !$0.isRead }.count
    }

    public init() {}

    @discardableResult
    public func add(
        _ notification: any AgentPayload,
        agent: String = "claude_code",
        env: EnvironmentContext = EnvironmentContext()
    ) -> NotificationItem {
        if let sid = notification.sessionId {
            items.removeAll { $0.agent == agent && $0.notification.sessionId == sid }
        }
        let item = NotificationItem(agent: agent, notification: notification, env: env)
        items.insert(item, at: 0)
        return item
    }

    public func markRead(id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].isRead = true
    }

    public func dismiss(id: UUID) {
        items.removeAll { $0.id == id }
    }

    public func markAllRead() {
        for i in items.indices {
            items[i].isRead = true
        }
    }
}
