import XCTest
@testable import FizzyKit

final class ModelsTests: XCTestCase {
    func testDecodeClaudeCodeNotification() throws {
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

        let notification = try JSONDecoder().decode(ClaudeCodeNotification.self, from: json)

        XCTAssertEqual(notification.sessionId, "abc123")
        XCTAssertEqual(notification.cwd, "/Users/test/project")
        XCTAssertEqual(notification.message, "Session needs your input")
        XCTAssertEqual(notification.notificationType, "permission_prompt")
        XCTAssertNil(notification.title, "title should be nil when absent from JSON")
    }

    func testDecodeNotificationWithTitle() throws {
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

        let notification = try JSONDecoder().decode(ClaudeCodeNotification.self, from: json)

        XCTAssertEqual(notification.title, "Permission Needed")
        XCTAssertEqual(notification.message, "Claude needs permission to use Bash")
    }

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
