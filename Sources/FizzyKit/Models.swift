import Foundation

// MARK: - AgentPayload protocol

public protocol AgentPayload: Codable, Sendable {
    var message: String { get }
    var cwd: String { get }
    var notificationType: String { get }
    var title: String? { get }
    var sessionId: String? { get }
}

extension AgentPayload {
    public var sessionId: String? { nil }
}

// MARK: - Claude Code payload

public struct ClaudeCodePayload: AgentPayload {
    public let sessionId: String?
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
        sessionId: String? = nil, transcriptPath: String, cwd: String,
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

// MARK: - Generic payload (fallback for unknown agents)

public struct GenericPayload: AgentPayload {
    public let message: String
    public let cwd: String
    public let notificationType: String
    public let title: String?
    public let sessionId: String?

    enum CodingKeys: String, CodingKey {
        case message, cwd
        case notificationType = "notification_type"
        case title
        case sessionId = "session_id"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        message = try container.decode(String.self, forKey: .message)
        cwd = try container.decode(String.self, forKey: .cwd)
        notificationType = try container.decodeIfPresent(String.self, forKey: .notificationType) ?? "notification"
        title = try container.decodeIfPresent(String.self, forKey: .title)
        sessionId = try container.decodeIfPresent(String.self, forKey: .sessionId)
    }

    public init(message: String, cwd: String, notificationType: String = "notification", title: String? = nil, sessionId: String? = nil) {
        self.message = message
        self.cwd = cwd
        self.notificationType = notificationType
        self.title = title
        self.sessionId = sessionId
    }
}

// MARK: - Environment context (collected by hook script)

public struct EnvironmentContext: Codable, Sendable {
    public let terminalPid: Int?
    public let tmuxPane: String?
    public let tmuxSocketPath: String?
    public let tmuxSessionName: String?
    public let tmuxClientTty: String?
    public let gitBranch: String?

    enum CodingKeys: String, CodingKey {
        case terminalPid = "terminal_pid"
        case tmuxPane = "tmux_pane"
        case tmuxSocketPath = "tmux_socket_path"
        case tmuxSessionName = "tmux_session_name"
        case tmuxClientTty = "tmux_client_tty"
        case gitBranch = "git_branch"
    }

    public init(
        terminalPid: Int? = nil, tmuxPane: String? = nil,
        tmuxSocketPath: String? = nil, tmuxSessionName: String? = nil,
        tmuxClientTty: String? = nil, gitBranch: String? = nil
    ) {
        self.terminalPid = terminalPid
        self.tmuxPane = tmuxPane
        self.tmuxSocketPath = tmuxSocketPath
        self.tmuxSessionName = tmuxSessionName
        self.tmuxClientTty = tmuxClientTty
        self.gitBranch = gitBranch
    }
}

// MARK: - FizzyNotification envelope

public struct FizzyNotification: Sendable {
    public let agent: String
    public let payload: any AgentPayload
    public let env: EnvironmentContext

    enum CodingKeys: String, CodingKey {
        case agent, payload, env
    }

    public init(agent: String, payload: any AgentPayload, env: EnvironmentContext = EnvironmentContext()) {
        self.agent = agent
        self.payload = payload
        self.env = env
    }
}

extension FizzyNotification: Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        agent = try container.decode(String.self, forKey: .agent)
        env = try container.decodeIfPresent(EnvironmentContext.self, forKey: .env) ?? EnvironmentContext()
        switch agent {
        case "claude_code":
            payload = try container.decode(ClaudeCodePayload.self, forKey: .payload)
        default:
            payload = try container.decode(GenericPayload.self, forKey: .payload)
        }
    }
}

// MARK: - Notification response (unchanged)

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

// MARK: - Session end request

public struct SessionEndRequest: Codable, Sendable {
    public let agent: String
    public let sessionId: String

    enum CodingKeys: String, CodingKey {
        case agent
        case sessionId = "session_id"
    }

    public init(agent: String, sessionId: String) {
        self.agent = agent
        self.sessionId = sessionId
    }
}

// MARK: - NotificationItem

public struct NotificationItem: Identifiable, Sendable {
    public let id: UUID
    public let agent: String
    public let notification: any AgentPayload
    public let env: EnvironmentContext
    public let arrivedAt: Date
    public var isRead: Bool

    public init(
        agent: String = "claude_code",
        notification: any AgentPayload,
        env: EnvironmentContext = EnvironmentContext(),
        arrivedAt: Date = Date()
    ) {
        self.id = UUID()
        self.agent = agent
        self.notification = notification
        self.env = env
        self.arrivedAt = arrivedAt
        self.isRead = false
    }
}
