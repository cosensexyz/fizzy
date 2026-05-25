import XCTest
@testable import FizzyKit

final class ModelsTests: XCTestCase {

    // MARK: - ClaudeCodePayload

    func testDecodeClaudeCodePayload() throws {
        let json = """
        {
            "session_id": "abc123",
            "transcript_path": "/Users/test/.claude/sessions/s/transcript.jsonl",
            "cwd": "/Users/test/project",
            "hook_event_name": "Notification",
            "message": "Session needs your input",
            "notification_type": "permission_prompt"
        }
        """.data(using: .utf8)!

        let payload = try JSONDecoder().decode(ClaudeCodePayload.self, from: json)

        XCTAssertEqual(payload.sessionId, "abc123")
        XCTAssertEqual(payload.cwd, "/Users/test/project")
        XCTAssertEqual(payload.message, "Session needs your input")
        XCTAssertEqual(payload.notificationType, "permission_prompt")
        XCTAssertNil(payload.title)
    }

    func testDecodeClaudeCodePayloadWithTitle() throws {
        let json = """
        {
            "session_id": "s1",
            "transcript_path": "/tmp/t",
            "cwd": "/tmp/project",
            "hook_event_name": "Notification",
            "message": "Claude needs permission to use Bash",
            "notification_type": "permission_prompt",
            "title": "Permission Needed"
        }
        """.data(using: .utf8)!

        let payload = try JSONDecoder().decode(ClaudeCodePayload.self, from: json)

        XCTAssertEqual(payload.title, "Permission Needed")
        XCTAssertEqual(payload.message, "Claude needs permission to use Bash")
    }

    func testClaudeCodePayloadConformsToAgentPayload() {
        let payload = ClaudeCodePayload(
            sessionId: "s1", transcriptPath: "/tmp/t", cwd: "/tmp",
            hookEventName: "Notification", message: "test",
            notificationType: "idle_prompt"
        )
        let agent: any AgentPayload = payload
        XCTAssertEqual(agent.message, "test")
        XCTAssertEqual(agent.cwd, "/tmp")
        XCTAssertEqual(agent.notificationType, "idle_prompt")
        XCTAssertNil(agent.title)
    }

    // MARK: - GenericPayload

    func testDecodeGenericPayloadMinimal() throws {
        let json = """
        {"message": "hello", "cwd": "/tmp"}
        """.data(using: .utf8)!

        let payload = try JSONDecoder().decode(GenericPayload.self, from: json)

        XCTAssertEqual(payload.message, "hello")
        XCTAssertEqual(payload.cwd, "/tmp")
        XCTAssertEqual(payload.notificationType, "notification")
        XCTAssertNil(payload.title)
    }

    func testDecodeGenericPayloadFull() throws {
        let json = """
        {"message": "hi", "cwd": "/tmp", "notification_type": "alert", "title": "Alert"}
        """.data(using: .utf8)!

        let payload = try JSONDecoder().decode(GenericPayload.self, from: json)

        XCTAssertEqual(payload.notificationType, "alert")
        XCTAssertEqual(payload.title, "Alert")
    }

    // MARK: - EnvironmentContext

    func testDecodeEnvironmentContextFull() throws {
        let json = """
        {
            "terminal_pid": 12345,
            "tmux_pane": "%3",
            "tmux_socket_path": "/private/tmp/tmux-501/default",
            "git_branch": "main"
        }
        """.data(using: .utf8)!

        let env = try JSONDecoder().decode(EnvironmentContext.self, from: json)

        XCTAssertEqual(env.terminalPid, 12345)
        XCTAssertEqual(env.tmuxPane, "%3")
        XCTAssertEqual(env.tmuxSocketPath, "/private/tmp/tmux-501/default")
        XCTAssertEqual(env.gitBranch, "main")
    }

    func testDecodeEnvironmentContextEmpty() throws {
        let json = "{}".data(using: .utf8)!

        let env = try JSONDecoder().decode(EnvironmentContext.self, from: json)

        XCTAssertNil(env.terminalPid)
        XCTAssertNil(env.tmuxPane)
        XCTAssertNil(env.tmuxSocketPath)
        XCTAssertNil(env.gitBranch)
    }

    func testDecodeEnvironmentContextWithTmuxSessionAndClientTty() throws {
        let json = """
        {
            "terminal_pid": 12345,
            "tmux_pane": "%3",
            "tmux_socket_path": "/private/tmp/tmux-501/default",
            "tmux_session_name": "main",
            "tmux_client_tty": "/dev/ttys003",
            "git_branch": "main"
        }
        """.data(using: .utf8)!

        let env = try JSONDecoder().decode(EnvironmentContext.self, from: json)

        XCTAssertEqual(env.tmuxSessionName, "main")
        XCTAssertEqual(env.tmuxClientTty, "/dev/ttys003")
    }

    func testDecodeEnvironmentContextOmitsNewFieldsGracefully() throws {
        let json = """
        {"terminal_pid": 1, "tmux_pane": "%0"}
        """.data(using: .utf8)!

        let env = try JSONDecoder().decode(EnvironmentContext.self, from: json)

        XCTAssertNil(env.tmuxSessionName)
        XCTAssertNil(env.tmuxClientTty)
    }

    // MARK: - FizzyNotification envelope

    func testDecodeFizzyNotificationClaudeCode() throws {
        let json = """
        {
            "agent": "claude_code",
            "payload": {
                "session_id": "s1",
                "transcript_path": "/tmp/t",
                "cwd": "/tmp/project",
                "hook_event_name": "Notification",
                "message": "idle",
                "notification_type": "idle_prompt"
            },
            "env": {
                "terminal_pid": 99,
                "git_branch": "feat/x"
            }
        }
        """.data(using: .utf8)!

        let notification = try JSONDecoder().decode(FizzyNotification.self, from: json)

        XCTAssertEqual(notification.agent, "claude_code")
        XCTAssertEqual(notification.payload.message, "idle")
        XCTAssertEqual(notification.env.terminalPid, 99)
        XCTAssertEqual(notification.env.gitBranch, "feat/x")
        XCTAssertTrue(notification.payload is ClaudeCodePayload)
    }

    func testDecodeFizzyNotificationUnknownAgentUsesGeneric() throws {
        let json = """
        {
            "agent": "some_agent",
            "payload": {"message": "hi", "cwd": "/tmp"}
        }
        """.data(using: .utf8)!

        let notification = try JSONDecoder().decode(FizzyNotification.self, from: json)

        XCTAssertEqual(notification.agent, "some_agent")
        XCTAssertEqual(notification.payload.message, "hi")
        XCTAssertTrue(notification.payload is GenericPayload)
        XCTAssertNil(notification.env.terminalPid)
    }

    func testDecodeFizzyNotificationMissingEnv() throws {
        let json = """
        {
            "agent": "claude_code",
            "payload": {
                "session_id": "s1", "transcript_path": "/tmp/t",
                "cwd": "/tmp", "hook_event_name": "Notification",
                "message": "test", "notification_type": "idle_prompt"
            }
        }
        """.data(using: .utf8)!

        let notification = try JSONDecoder().decode(FizzyNotification.self, from: json)

        XCTAssertNil(notification.env.terminalPid)
        XCTAssertNil(notification.env.tmuxPane)
        XCTAssertNil(notification.env.gitBranch)
    }

    // MARK: - NotificationResponse (unchanged)

    func testEncodeNotificationResponseSimple() throws {
        let response = NotificationResponse(shouldContinue: true)
        let data = try JSONEncoder().encode(response)
        let dict = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertEqual(dict["continue"] as? Bool, true)
        XCTAssertNil(dict["hookSpecificOutput"])
    }

    func testEncodeNotificationResponseWithReply() throws {
        let response = NotificationResponse(
            shouldContinue: true,
            hookSpecificOutput: .init(
                hookEventName: "Notification",
                additionalContext: "User responded via Fizzy: looks good"
            )
        )
        let data = try JSONEncoder().encode(response)
        let dict = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let output = dict["hookSpecificOutput"] as! [String: Any]

        XCTAssertEqual(output["hookEventName"] as? String, "Notification")
        XCTAssertEqual(output["additionalContext"] as? String, "User responded via Fizzy: looks good")
    }
}
