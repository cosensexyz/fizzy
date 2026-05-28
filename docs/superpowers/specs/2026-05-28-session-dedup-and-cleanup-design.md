# Session Dedup and Cleanup

## Problem

Two issues with the current notification list:

1. **Dedup key too broad.** Dedup uses `sessionId` alone. If two different agents (e.g., codex and claude_code) happen to share a session ID, they collide and one replaces the other.

2. **No session-end cleanup.** Items stay in the list until manually dismissed. When a Claude Code session ends (user exits, `/clear`, etc.), the corresponding item should be automatically removed.

## Changes

### 1. Add `sessionId` to `GenericPayload`

`GenericPayload` currently has no `sessionId` (defaults to `nil` via the protocol extension). Add an optional `session_id` field so any agent can opt into session-based dedup.

**File:** `Models.swift`

- Add `public let sessionId: String?` property
- Add `sessionId = "session_id"` to `CodingKeys`
- Decode with `decodeIfPresent`, default `nil`
- Update `init` with optional `sessionId` parameter

### 2. Dedup by `(agent, sessionId)`

Change the dedup predicate in `NotificationStore.add()` from matching `sessionId` alone to matching both `agent` and `sessionId`.

**File:** `NotificationStore.swift`

```swift
// Before
items.removeAll { $0.notification.sessionId == sid }

// After
items.removeAll { $0.agent == agent && $0.notification.sessionId == sid }
```

### 3. Add `endSession(agent:sessionId:)` to `NotificationStore`

New method that removes all items matching the `(agent, sessionId)` pair. Called when a session-end signal arrives.

**File:** `NotificationStore.swift`

```swift
public func endSession(agent: String, sessionId: String) {
    items.removeAll { $0.agent == agent && $0.notification.sessionId == sessionId }
}
```

### 4. Add `POST /session-end` endpoint

Minimal endpoint that accepts:

```json
{
  "agent": "claude_code",
  "session_id": "abc123"
}
```

A new `SessionEndRequest` struct handles decoding. `FizzyServer` gains a second callback `onSessionEnd: (String, String) -> Void` for `(agent, sessionId)`.

**File:** `FizzyServer.swift`, `Models.swift`

### 5. Remove `POST /claudecode/notification`

Dead code. It loses `EnvironmentContext` and is superseded by `POST /notification`. Delete the case from `processRequest()`.

**File:** `FizzyServer.swift`

### 6. Wire session-end in `FizzyApp`

Pass `onSessionEnd` to `FizzyServer`. The callback calls `store.endSession()`, updates fizzy state, and reloads the list panel if visible.

**File:** `FizzyApp.swift`

## Reliability

`SessionEnd` does not fire on `kill -9`, crash, or power loss. This is acceptable: stale items remain in the list until manually dismissed. No TTL or polling fallback needed for a desktop pet app.

## Files Changed

| File | Change |
|------|--------|
| `Models.swift` | Add `sessionId` to `GenericPayload`; add `SessionEndRequest` struct |
| `NotificationStore.swift` | Composite dedup key; add `endSession()` |
| `FizzyServer.swift` | Add `/session-end` endpoint; remove `/claudecode/notification` |
| `FizzyApp.swift` | Wire `onSessionEnd` callback |
| Tests | Cover composite dedup, `endSession()`, new endpoint, removed endpoint |
