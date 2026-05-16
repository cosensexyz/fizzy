import Foundation

public struct ClaudeCodeNotification: Codable, Sendable {
    public let sessionId: String
    public let transcriptPath: String
    public let cwd: String
    public let hookEventName: String
    public let message: String
    public let notificationType: String
    public let title: String?

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case transcriptPath = "transcript_path"
        case cwd
        case hookEventName = "hook_event_name"
        case message
        case notificationType = "notification_type"
        case title
    }

    public init(
        sessionId: String, transcriptPath: String, cwd: String,
        hookEventName: String, message: String, notificationType: String,
        title: String? = nil
    ) {
        self.sessionId = sessionId
        self.transcriptPath = transcriptPath
        self.cwd = cwd
        self.hookEventName = hookEventName
        self.message = message
        self.notificationType = notificationType
        self.title = title
    }
}

public struct NotificationResponse: Codable, Sendable {
    public let shouldContinue: Bool
    public var hookSpecificOutput: HookSpecificOutput?

    public init(shouldContinue: Bool, hookSpecificOutput: HookSpecificOutput? = nil) {
        self.shouldContinue = shouldContinue
        self.hookSpecificOutput = hookSpecificOutput
    }

    enum CodingKeys: String, CodingKey {
        case shouldContinue = "continue"
        case hookSpecificOutput
    }

    public struct HookSpecificOutput: Codable, Sendable {
        public let hookEventName: String
        public let additionalContext: String

        public init(hookEventName: String, additionalContext: String) {
            self.hookEventName = hookEventName
            self.additionalContext = additionalContext
        }
    }
}

public struct NotificationItem: Identifiable, Sendable {
    public let id: UUID
    public let notification: ClaudeCodeNotification
    public let arrivedAt: Date
    public var isRead: Bool

    public init(notification: ClaudeCodeNotification, arrivedAt: Date = Date()) {
        self.id = UUID()
        self.notification = notification
        self.arrivedAt = arrivedAt
        self.isRead = false
    }
}
