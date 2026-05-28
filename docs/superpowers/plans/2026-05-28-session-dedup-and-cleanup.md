# Session Dedup and Cleanup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deduplicate notification list items by (agent, sessionId) and auto-remove items when a session ends.

**Architecture:** Add `sessionId` to `GenericPayload` so all agents can opt into dedup. Change the dedup key from `sessionId` to `(agent, sessionId)`. Add a `/session-end` endpoint that removes items. Remove the dead `/claudecode/notification` endpoint.

**Tech Stack:** Swift, Swift NIO (HTTP server), XCTest

---

### Task 1: Add `sessionId` to `GenericPayload`

**Files:**
- Modify: `Sources/FizzyKit/Models.swift:55-81` (GenericPayload)
- Test: `Tests/FizzyTests/ModelsTests.swift`

- [ ] **Step 1: Write failing test for GenericPayload with session_id**

In `Tests/FizzyTests/ModelsTests.swift`, add after `testDecodeGenericPayloadFull`:

```swift
func testDecodeGenericPayloadWithSessionId() throws {
    let json = """
    {"message": "hi", "cwd": "/tmp", "session_id": "codex-123"}
    """.data(using: .utf8)!

    let payload = try JSONDecoder().decode(GenericPayload.self, from: json)

    XCTAssertEqual(payload.sessionId, "codex-123")
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter ModelsTests/testDecodeGenericPayloadWithSessionId 2>&1 | tail -5`
Expected: FAIL — `GenericPayload` has no `sessionId` property.

- [ ] **Step 3: Implement sessionId on GenericPayload**

In `Sources/FizzyKit/Models.swift`, modify `GenericPayload`:

Add `sessionId` property and coding key:

```swift
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
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter ModelsTests 2>&1 | tail -5`
Expected: All ModelsTests pass, including the new one. Existing `testDecodeGenericPayloadMinimal` still passes (sessionId defaults to nil).

- [ ] **Step 5: Commit**

```bash
git add Sources/FizzyKit/Models.swift Tests/FizzyTests/ModelsTests.swift
git commit -m "feat: add sessionId to GenericPayload"
```

---

### Task 2: Composite dedup key in NotificationStore

**Files:**
- Modify: `Sources/FizzyKit/NotificationStore.swift:18-20`
- Test: `Tests/FizzyTests/NotificationStoreTests.swift`

- [ ] **Step 1: Write failing test for cross-agent dedup isolation**

In `Tests/FizzyTests/NotificationStoreTests.swift`, add:

```swift
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter NotificationStoreTests/testAddDedupsScopedByAgent 2>&1 | tail -5`
Expected: FAIL — count is 1 because current dedup only checks sessionId, so the codex item replaces the claude_code item.

- [ ] **Step 3: Change dedup predicate to composite key**

In `Sources/FizzyKit/NotificationStore.swift`, change line 18-20 from:

```swift
if let sid = notification.sessionId {
    items.removeAll { $0.notification.sessionId == sid }
}
```

to:

```swift
if let sid = notification.sessionId {
    items.removeAll { $0.agent == agent && $0.notification.sessionId == sid }
}
```

- [ ] **Step 4: Run all store tests**

Run: `swift test --filter NotificationStoreTests 2>&1 | tail -5`
Expected: All pass — existing dedup tests still work because they all use the default agent `"claude_code"`.

- [ ] **Step 5: Commit**

```bash
git add Sources/FizzyKit/NotificationStore.swift Tests/FizzyTests/NotificationStoreTests.swift
git commit -m "feat: dedup notifications by (agent, sessionId)"
```

---

### Task 3: Add `endSession` to NotificationStore

**Files:**
- Modify: `Sources/FizzyKit/NotificationStore.swift`
- Test: `Tests/FizzyTests/NotificationStoreTests.swift`

- [ ] **Step 1: Write failing tests for endSession**

In `Tests/FizzyTests/NotificationStoreTests.swift`, add:

```swift
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter NotificationStoreTests/testEndSession 2>&1 | tail -5`
Expected: FAIL — `endSession` method does not exist.

- [ ] **Step 3: Implement endSession**

In `Sources/FizzyKit/NotificationStore.swift`, add after the `dismiss` method:

```swift
public func endSession(agent: String, sessionId: String) {
    items.removeAll { $0.agent == agent && $0.notification.sessionId == sessionId }
}
```

- [ ] **Step 4: Run all store tests**

Run: `swift test --filter NotificationStoreTests 2>&1 | tail -5`
Expected: All pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/FizzyKit/NotificationStore.swift Tests/FizzyTests/NotificationStoreTests.swift
git commit -m "feat: add endSession to NotificationStore"
```

---

### Task 4: Add `SessionEndRequest` model

**Files:**
- Modify: `Sources/FizzyKit/Models.swift`
- Test: `Tests/FizzyTests/ModelsTests.swift`

- [ ] **Step 1: Write failing test**

In `Tests/FizzyTests/ModelsTests.swift`, add:

```swift
// MARK: - SessionEndRequest

func testDecodeSessionEndRequest() throws {
    let json = """
    {"agent": "claude_code", "session_id": "abc123"}
    """.data(using: .utf8)!

    let req = try JSONDecoder().decode(SessionEndRequest.self, from: json)

    XCTAssertEqual(req.agent, "claude_code")
    XCTAssertEqual(req.sessionId, "abc123")
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter ModelsTests/testDecodeSessionEndRequest 2>&1 | tail -5`
Expected: FAIL — `SessionEndRequest` type does not exist.

- [ ] **Step 3: Implement SessionEndRequest**

In `Sources/FizzyKit/Models.swift`, add before the `NotificationItem` section:

```swift
// MARK: - Session end request

public struct SessionEndRequest: Codable, Sendable {
    public let agent: String
    public let sessionId: String

    enum CodingKeys: String, CodingKey {
        case agent
        case sessionId = "session_id"
    }
}
```

- [ ] **Step 4: Run tests**

Run: `swift test --filter ModelsTests 2>&1 | tail -5`
Expected: All pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/FizzyKit/Models.swift Tests/FizzyTests/ModelsTests.swift
git commit -m "feat: add SessionEndRequest model"
```

---

### Task 5: Add `/session-end` endpoint, remove `/claudecode/notification`

**Files:**
- Modify: `Sources/FizzyKit/FizzyServer.swift`
- Test: `Tests/FizzyTests/FizzyServerTests.swift`

- [ ] **Step 1: Write failing tests**

In `Tests/FizzyTests/FizzyServerTests.swift`:

Replace `testLegacyEndpointBackwardCompat` with a test that verifies the old endpoint is gone, and add the session-end test:

```swift
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
```

Also update `testEnvelopeEndpoint` and `testWrongPathReturns404` to use the new init signature:

In `testEnvelopeEndpoint`, change:
```swift
let server = FizzyServer(port: 17319) { agent, payload, env in
```
to:
```swift
let server = FizzyServer(port: 17319, onNotification: { agent, payload, env in
```
and add closing `) , onSessionEnd: { _, _ in })` — full line:
```swift
let server = FizzyServer(port: 17319, onNotification: { agent, payload, env in
    XCTAssertEqual(agent, "claude_code")
    XCTAssertEqual(payload.message, "hello from envelope")
    XCTAssertEqual(env.gitBranch, "main")
    expectation.fulfill()
}, onSessionEnd: { _, _ in })
```

In `testWrongPathReturns404`, change:
```swift
let server = FizzyServer(port: 17321) { _, _, _ in }
```
to:
```swift
let server = FizzyServer(port: 17321, onNotification: { _, _, _ in }, onSessionEnd: { _, _ in })
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter FizzyServerTests 2>&1 | tail -10`
Expected: FAIL — `FizzyServer` init doesn't accept `onSessionEnd` parameter.

- [ ] **Step 3: Implement server changes**

In `Sources/FizzyKit/FizzyServer.swift`:

Add `onSessionEnd` to `FizzyServer`:

```swift
public final class FizzyServer: @unchecked Sendable {
    private let port: Int
    private let group: MultiThreadedEventLoopGroup
    private var channel: Channel?
    private let onNotification: @Sendable (String, any AgentPayload, EnvironmentContext) -> Void
    private let onSessionEnd: @Sendable (String, String) -> Void

    public init(
        port: Int,
        onNotification: @escaping @Sendable (String, any AgentPayload, EnvironmentContext) -> Void,
        onSessionEnd: @escaping @Sendable (String, String) -> Void
    ) {
        self.port = port
        self.group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        self.onNotification = onNotification
        self.onSessionEnd = onSessionEnd
    }

    public func start() throws {
        let handler = { @Sendable [onNotification, onSessionEnd] in
            return RequestHandler(onNotification: onNotification, onSessionEnd: onSessionEnd)
        }
        let bootstrap = ServerBootstrap(group: group)
            .serverChannelOption(.socketOption(.so_reuseaddr), value: 1)
            .childChannelInitializer { channel in
                channel.pipeline.configureHTTPServerPipeline(withErrorHandling: true).flatMap {
                    channel.pipeline.addHandler(handler())
                }
            }
            .childChannelOption(.socketOption(.so_reuseaddr), value: 1)

        channel = try bootstrap.bind(host: "127.0.0.1", port: port).wait()
    }

    public func stop() {
        try? channel?.close().wait()
        try? group.syncShutdownGracefully()
    }
}
```

Update `RequestHandler` to accept both callbacks and handle the new route:

```swift
private final class RequestHandler: ChannelInboundHandler, RemovableChannelHandler, @unchecked Sendable {
    typealias InboundIn = HTTPServerRequestPart
    typealias OutboundOut = HTTPServerResponsePart

    private let onNotification: @Sendable (String, any AgentPayload, EnvironmentContext) -> Void
    private let onSessionEnd: @Sendable (String, String) -> Void
    private var requestHead: HTTPRequestHead?
    private var body = ByteBuffer()

    init(
        onNotification: @escaping @Sendable (String, any AgentPayload, EnvironmentContext) -> Void,
        onSessionEnd: @escaping @Sendable (String, String) -> Void
    ) {
        self.onNotification = onNotification
        self.onSessionEnd = onSessionEnd
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        switch Self.unwrapInboundIn(data) {
        case .head(let head):
            requestHead = head
            body.clear()
        case .body(var buf):
            body.writeBuffer(&buf)
        case .end:
            processRequest(context: context)
        }
    }

    private func processRequest(context: ChannelHandlerContext) {
        guard let head = requestHead, head.method == .POST else {
            respond(context: context, status: .notFound, json: #"{"error":"not found"}"#)
            return
        }

        guard let bytes = body.readBytes(length: body.readableBytes) else {
            respond(context: context, status: .badRequest, json: #"{"error":"invalid request"}"#)
            return
        }
        let bodyData = Data(bytes)

        switch head.uri {
        case "/notification":
            guard let notification = try? JSONDecoder().decode(FizzyNotification.self, from: bodyData) else {
                respond(context: context, status: .badRequest, json: #"{"error":"invalid request"}"#)
                return
            }
            respond(context: context, status: .ok, json: #"{"continue":true}"#)
            onNotification(notification.agent, notification.payload, notification.env)

        case "/session-end":
            guard let req = try? JSONDecoder().decode(SessionEndRequest.self, from: bodyData) else {
                respond(context: context, status: .badRequest, json: #"{"error":"invalid request"}"#)
                return
            }
            respond(context: context, status: .ok, json: #"{"ok":true}"#)
            onSessionEnd(req.agent, req.sessionId)

        default:
            respond(context: context, status: .notFound, json: #"{"error":"not found"}"#)
        }
    }

    private func respond(context: ChannelHandlerContext, status: HTTPResponseStatus, json: String) {
        respond(context: context, status: status, data: Data(json.utf8))
    }

    private func respond(context: ChannelHandlerContext, status: HTTPResponseStatus, data: Data) {
        var buffer = context.channel.allocator.buffer(capacity: data.count)
        buffer.writeBytes(data)

        let head = HTTPResponseHead(version: .http1_1, status: status, headers: [
            "Content-Type": "application/json",
            "Content-Length": "\(data.count)",
        ])
        context.write(Self.wrapOutboundOut(.head(head)), promise: nil)
        context.write(Self.wrapOutboundOut(.body(.byteBuffer(buffer))), promise: nil)
        context.writeAndFlush(Self.wrapOutboundOut(.end(nil)), promise: nil)
    }
}
```

- [ ] **Step 4: Run all server tests**

Run: `swift test --filter FizzyServerTests 2>&1 | tail -10`
Expected: All pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/FizzyKit/FizzyServer.swift Tests/FizzyTests/FizzyServerTests.swift
git commit -m "feat: add /session-end endpoint, remove /claudecode/notification"
```

---

### Task 6: Wire session-end in FizzyApp

**Files:**
- Modify: `Sources/FizzyKit/FizzyApp.swift:56-67`

- [ ] **Step 1: Update FizzyServer initialization**

In `Sources/FizzyKit/FizzyApp.swift`, replace the server initialization block (lines 56-67):

```swift
server = FizzyServer(port: 7319) { [weak self] agent, payload, env in
    DispatchQueue.main.async { [weak self] in
        self?.handleNotification(agent: agent, payload: payload, env: env)
    }
}
```

with:

```swift
server = FizzyServer(
    port: 7319,
    onNotification: { [weak self] agent, payload, env in
        DispatchQueue.main.async { [weak self] in
            self?.handleNotification(agent: agent, payload: payload, env: env)
        }
    },
    onSessionEnd: { [weak self] agent, sessionId in
        DispatchQueue.main.async { [weak self] in
            self?.handleSessionEnd(agent: agent, sessionId: sessionId)
        }
    }
)
```

- [ ] **Step 2: Add handleSessionEnd method**

In `Sources/FizzyKit/FizzyApp.swift`, add after `handleNotification`:

```swift
private func handleSessionEnd(agent: String, sessionId: String) {
    store.endSession(agent: agent, sessionId: sessionId)
    window.updateFizzyState(unreadCount: store.unreadCount)
    if listVisible { listPanel.reload() }
}
```

- [ ] **Step 3: Build and run full test suite**

Run: `swift test 2>&1 | tail -5`
Expected: All tests pass.

- [ ] **Step 4: Commit**

```bash
git add Sources/FizzyKit/FizzyApp.swift
git commit -m "feat: wire session-end handler in FizzyApp"
```
