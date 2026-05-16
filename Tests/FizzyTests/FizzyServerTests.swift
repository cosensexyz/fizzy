import XCTest
@testable import FizzyKit

final class FizzyServerTests: XCTestCase {
    private func postNotification(port: Int, json: String) async throws -> (Data, HTTPURLResponse) {
        var request = URLRequest(url: URL(string: "http://127.0.0.1:\(port)/claudecode/notification")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = json.data(using: .utf8)
        let (data, response) = try await URLSession.shared.data(for: request)
        return (data, response as! HTTPURLResponse)
    }

    func testNotificationRespondsImmediately() async throws {
        let expectation = expectation(description: "callback called")
        let server = FizzyServer(port: 17319) { notification in
            XCTAssertEqual(notification.message, "hello from test")
            expectation.fulfill()
        }
        try server.start()
        defer { server.stop() }

        let json = """
        {"session_id":"s1","transcript_path":"/tmp/t","cwd":"/tmp","hook_event_name":"Notification","message":"hello from test","notification_type":"idle_prompt"}
        """
        let (data, response) = try await postNotification(port: 17319, json: json)

        XCTAssertEqual(response.statusCode, 200)
        let dict = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertEqual(dict["continue"] as? Bool, true)

        await fulfillment(of: [expectation], timeout: 2)
    }

    func testWrongPathReturns404() async throws {
        let server = FizzyServer(port: 17321) { _ in }
        try server.start()
        defer { server.stop() }

        var request = URLRequest(url: URL(string: "http://127.0.0.1:17321/wrong/path")!)
        request.httpMethod = "POST"
        let (_, response) = try await URLSession.shared.data(for: request)
        XCTAssertEqual((response as! HTTPURLResponse).statusCode, 404)
    }
}
