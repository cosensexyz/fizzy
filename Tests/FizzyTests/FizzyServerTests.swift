import XCTest
@testable import FizzyKit

final class FizzyServerTests: XCTestCase {
    private func post(port: Int, path: String, json: String) async throws -> (Data, HTTPURLResponse) {
        var request = URLRequest(url: URL(string: "http://127.0.0.1:\(port)\(path)")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = json.data(using: .utf8)
        let (data, response) = try await URLSession.shared.data(for: request)
        return (data, response as! HTTPURLResponse)
    }

    func testEnvelopeEndpoint() async throws {
        let expectation = expectation(description: "callback")
        let server = FizzyServer(port: 17319, onNotification: { agent, payload, env in
            XCTAssertEqual(agent, "claude_code")
            XCTAssertEqual(payload.message, "hello from envelope")
            XCTAssertEqual(env.gitBranch, "main")
            expectation.fulfill()
        }, onSessionEnd: { _, _ in })
        try server.start()
        defer { server.stop() }

        let json = """
        {
            "agent": "claude_code",
            "payload": {
                "session_id": "s1", "transcript_path": "/tmp/t", "cwd": "/tmp",
                "hook_event_name": "Notification", "message": "hello from envelope",
                "notification_type": "idle_prompt"
            },
            "env": {"git_branch": "main"}
        }
        """
        let (data, response) = try await post(port: 17319, path: "/notification", json: json)

        XCTAssertEqual(response.statusCode, 200)
        let dict = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertEqual(dict["continue"] as? Bool, true)
        await fulfillment(of: [expectation], timeout: 2)
    }

    func testLegacyEndpointRemoved() async throws {
        let server = FizzyServer(port: 17320, onNotification: { _, _, _ in }, onSessionEnd: { _, _ in })
        try server.start()
        defer { server.stop() }

        let json = """
        {"session_id":"s1","transcript_path":"/tmp/t","cwd":"/tmp","hook_event_name":"Notification","message":"hello legacy","notification_type":"idle_prompt"}
        """
        let (_, response) = try await post(port: 17320, path: "/claudecode/notification", json: json)

        XCTAssertEqual(response.statusCode, 404)
    }

    func testSessionEndEndpoint() async throws {
        let expectation = expectation(description: "session-end callback")
        var receivedAgent: String?
        var receivedSessionId: String?

        let server = FizzyServer(port: 17322, onNotification: { _, _, _ in }, onSessionEnd: { agent, sessionId in
            receivedAgent = agent
            receivedSessionId = sessionId
            expectation.fulfill()
        })
        try server.start()
        defer { server.stop() }

        let json = """
        {"agent": "claude_code", "session_id": "abc123"}
        """
        let (data, response) = try await post(port: 17322, path: "/session-end", json: json)

        XCTAssertEqual(response.statusCode, 200)
        let dict = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertEqual(dict["ok"] as? Bool, true)
        await fulfillment(of: [expectation], timeout: 2)
        XCTAssertEqual(receivedAgent, "claude_code")
        XCTAssertEqual(receivedSessionId, "abc123")
    }

    func testWrongPathReturns404() async throws {
        let server = FizzyServer(port: 17321, onNotification: { _, _, _ in }, onSessionEnd: { _, _ in })
        try server.start()
        defer { server.stop() }

        var request = URLRequest(url: URL(string: "http://127.0.0.1:17321/wrong/path")!)
        request.httpMethod = "POST"
        let (_, response) = try await URLSession.shared.data(for: request)
        XCTAssertEqual((response as! HTTPURLResponse).statusCode, 404)
    }
}
