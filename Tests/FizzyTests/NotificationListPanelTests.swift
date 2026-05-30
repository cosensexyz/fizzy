import XCTest
@testable import FizzyKit

final class NotificationListPanelTests: XCTestCase {
    private func makePayload(message: String = "test", sessionId: String = "s1") -> ClaudeCodePayload {
        ClaudeCodePayload(
            sessionId: sessionId, transcriptPath: "/tmp/t", cwd: "/tmp/project",
            hookEventName: "Notification", message: message,
            notificationType: "idle_prompt"
        )
    }

    private func showPanel(itemCount: Int) -> (NotificationListPanel, NotificationStore) {
        let panel = NotificationListPanel()
        let store = NotificationStore()
        for i in 1...itemCount {
            _ = store.add(makePayload(message: "msg \(i)", sessionId: "s\(i)"))
        }
        let petWindow = NSWindow(
            contentRect: NSRect(x: 100, y: 100, width: 80, height: 96),
            styleMask: .borderless, backing: .buffered, defer: false
        )
        panel.show(store: store, relativeTo: petWindow, onUpdate: {}, onOpen: { _ in })
        return (panel, store)
    }

    private func arrangedRows(in panel: NotificationListPanel) -> [NSView] {
        findScrollView(in: panel.contentView!)
            .flatMap { ($0.documentView as? NSStackView)?.arrangedSubviews ?? [] }
    }

    private func findScrollView(in view: NSView) -> [NSScrollView] {
        if let sv = view as? NSScrollView { return [sv] }
        return view.subviews.flatMap { findScrollView(in: $0) }
    }

    func testRowHasExplicitHeightConstraint() {
        let (panel, _) = showPanel(itemCount: 5)
        let rows = arrangedRows(in: panel)

        XCTAssertEqual(rows.count, 5)
        for row in rows {
            let heightConstraint = row.constraints.first {
                $0.firstAttribute == .height && $0.constant > 0
            }
            XCTAssertNotNil(heightConstraint, "Each row must have an explicit height constraint")
        }
    }

    func testShortMessageProducesShorterRow() {
        let panel = NotificationListPanel()
        let store = NotificationStore()
        _ = store.add(makePayload(message: "short", sessionId: "s1"))
        _ = store.add(makePayload(message: "This is a much longer message that should wrap to two lines in the notification list", sessionId: "s2"))
        let petWindow = NSWindow(
            contentRect: NSRect(x: 100, y: 100, width: 80, height: 96),
            styleMask: .borderless, backing: .buffered, defer: false
        )
        panel.show(store: store, relativeTo: petWindow, onUpdate: {}, onOpen: { _ in })
        let rows = arrangedRows(in: panel)

        let longRowH = rows[0].constraints.first { $0.firstAttribute == .height }!.constant
        let shortRowH = rows[1].constraints.first { $0.firstAttribute == .height }!.constant
        XCTAssertGreaterThan(longRowH, shortRowH, "2-line message row must be taller than 1-line")
    }

    func testRowHasOneDismissButton() {
        let (panel, _) = showPanel(itemCount: 1)
        let rows = arrangedRows(in: panel)

        let buttons = rows.first?.subviews.compactMap { $0 as? NSButton } ?? []
        XCTAssertEqual(buttons.count, 1, "Each row must have only a dismiss button")
    }

    func testRowClickFiresOnOpenAndDismisses() {
        let panel = NotificationListPanel()
        let store = NotificationStore()
        let item = store.add(makePayload(message: "click me"))
        let petWindow = NSWindow(
            contentRect: NSRect(x: 100, y: 100, width: 80, height: 96),
            styleMask: .borderless, backing: .buffered, defer: false
        )
        var openedItem: NotificationItem?
        panel.show(store: store, relativeTo: petWindow, onUpdate: {}, onOpen: { openedItem = $0 })

        let rows = arrangedRows(in: panel)
        guard let row = rows.first else { return XCTFail("Expected one row") }

        let clickEvent = NSEvent.mouseEvent(
            with: .leftMouseDown, location: NSPoint(x: 10, y: 10),
            modifierFlags: [], timestamp: 0, windowNumber: panel.windowNumber,
            context: nil, eventNumber: 0, clickCount: 1, pressure: 1.0
        )!
        row.mouseDown(with: clickEvent)

        XCTAssertEqual(openedItem?.id, item.id, "Click must fire onOpen with the item")
        XCTAssertTrue(store.items.isEmpty, "Click must dismiss the item from the store")
    }

    func testDisplayTitleMapsNotificationType() {
        XCTAssertEqual(NotificationRowBuilder.displayTitle(for: "idle_prompt"), "Claude is idle")
        XCTAssertEqual(NotificationRowBuilder.displayTitle(for: "some_type"), "Some Type")
    }

    func testRelativeTimeFormats() {
        XCTAssertEqual(NotificationRowBuilder.relativeTime(from: Date()), "now")
        XCTAssertEqual(NotificationRowBuilder.relativeTime(from: Date(timeIntervalSinceNow: -120)), "2m")
        XCTAssertEqual(NotificationRowBuilder.relativeTime(from: Date(timeIntervalSinceNow: -7200)), "2h")
    }

    func testEscKeyInvokesOnClose() {
        let (panel, _) = showPanel(itemCount: 1)
        var closeCalled = false
        panel.onClose = { closeCalled = true }

        let escEvent = NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: [],
            timestamp: 0, windowNumber: panel.windowNumber,
            context: nil, characters: "\u{1B}", charactersIgnoringModifiers: "\u{1B}",
            isARepeat: false, keyCode: 53
        )!
        panel.keyDown(with: escEvent)

        XCTAssertTrue(closeCalled, "ESC key must invoke onClose callback")
    }

    func testHoverDoesNotMarkRead() {
        let (panel, store) = showPanel(itemCount: 3)
        let unreadBefore = store.unreadCount

        _ = panel
        XCTAssertEqual(store.unreadCount, unreadBefore, "Hover must not mark items as read")
    }

    func testHitTestTargetsCorrectRowByPosition() {
        let (panel, _) = showPanel(itemCount: 3)
        let rows = arrangedRows(in: panel)
        guard rows.count == 3 else { return XCTFail("Expected 3 rows") }

        for (i, row) in rows.enumerated() {
            // hitTest takes a point in the receiver's superview coordinate space
            let center = NSPoint(x: row.frame.midX, y: row.frame.midY)
            let hit = row.hitTest(center)
            XCTAssertEqual(hit, row, "hitTest at center of row \(i) must return that row")
        }

        let outside = NSPoint(x: -100, y: -100)
        for (i, row) in rows.enumerated() {
            let hit = row.hitTest(outside)
            XCTAssertNil(hit, "hitTest outside bounds of row \(i) must return nil")
        }
    }

    func testClickTargetsCorrectRowInMixedList() {
        let panel = NotificationListPanel()
        let store = NotificationStore()
        let itemA = store.add(ClaudeCodePayload(
            sessionId: "s1", transcriptPath: "/tmp/t", cwd: "/tmp/projectA",
            hookEventName: "Notification", message: "msg A", notificationType: "idle_prompt"
        ))
        _ = store.add(ClaudeCodePayload(
            sessionId: "s2", transcriptPath: "/tmp/t", cwd: "/tmp/projectB",
            hookEventName: "Notification", message: "msg B", notificationType: "idle_prompt"
        ))
        let petWindow = NSWindow(
            contentRect: NSRect(x: 100, y: 100, width: 80, height: 96),
            styleMask: .borderless, backing: .buffered, defer: false
        )
        var openedItem: NotificationItem?
        panel.show(store: store, relativeTo: petWindow, onUpdate: {}, onOpen: { openedItem = $0 })

        let rows = arrangedRows(in: panel)
        guard rows.count == 2 else { return XCTFail("Expected 2 rows") }

        // store.add prepends, so rows[0] is most recent, rows[1] = itemA
        let secondRow = rows[1]
        let clickEvent = NSEvent.mouseEvent(
            with: .leftMouseDown, location: NSPoint(x: 10, y: 10),
            modifierFlags: [], timestamp: 0, windowNumber: panel.windowNumber,
            context: nil, eventNumber: 0, clickCount: 1, pressure: 1.0
        )!
        secondRow.mouseDown(with: clickEvent)

        XCTAssertEqual(openedItem?.id, itemA.id, "Clicking second row must open itemA, not itemB")
    }

    func testHoverThenClickOpensHoveredItem() {
        let panel = NotificationListPanel()
        let store = NotificationStore()
        let itemA = store.add(ClaudeCodePayload(
            sessionId: "s1", transcriptPath: "/tmp/t", cwd: "/tmp/projectA",
            hookEventName: "Notification", message: "msg A", notificationType: "idle_prompt"
        ))
        _ = store.add(ClaudeCodePayload(
            sessionId: "s2", transcriptPath: "/tmp/t", cwd: "/tmp/projectB",
            hookEventName: "Notification", message: "msg B", notificationType: "idle_prompt"
        ))
        let petWindow = NSWindow(
            contentRect: NSRect(x: 100, y: 100, width: 80, height: 96),
            styleMask: .borderless, backing: .buffered, defer: false
        )
        var openedItem: NotificationItem?
        panel.show(store: store, relativeTo: petWindow, onUpdate: {}, onOpen: { openedItem = $0 })

        let rows = arrangedRows(in: panel)
        guard rows.count == 2 else { return XCTFail("Expected 2 rows") }

        let targetRow = rows[1]

        let clickEvent = NSEvent.mouseEvent(
            with: .leftMouseDown, location: NSPoint(x: 10, y: 10),
            modifierFlags: [], timestamp: 0, windowNumber: panel.windowNumber,
            context: nil, eventNumber: 0, clickCount: 1, pressure: 1.0
        )!
        // HoverRow.mouseEntered ignores the event parameter; reuse clickEvent to avoid
        // NSEvent.mouseEvent rejecting the .mouseEntered type
        targetRow.mouseEntered(with: clickEvent)
        targetRow.mouseDown(with: clickEvent)

        XCTAssertEqual(openedItem?.id, itemA.id, "After hovering and clicking a row, onOpen must receive that row's item")
    }
}
