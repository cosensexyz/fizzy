import XCTest
@testable import FizzyKit

final class NotificationRowBuilderTests: XCTestCase {
    private func makeItem(
        message: String = "test msg",
        notificationType: String = "idle_prompt",
        title: String? = nil
    ) -> NotificationItem {
        NotificationItem(notification: ClaudeCodeNotification(
            sessionId: "s1", transcriptPath: "/tmp/t", cwd: "/tmp/project",
            hookEventName: "Notification", message: message,
            notificationType: notificationType, title: title
        ))
    }

    func testDisplayTitleUsesPayloadTitleWhenPresent() {
        let item = makeItem(title: "Permission Needed")
        let row = NSView(frame: NSRect(x: 0, y: 0, width: 320, height: 80))
        let layout = NotificationRowBuilder.Layout(message: item.notification.message, width: 202)

        NotificationRowBuilder.buildContent(
            item: item, in: row, layout: layout,
            messageWidth: 202, isRead: false
        )

        let titleLabel = row.subviews.compactMap { $0 as? NSTextField }
            .first { $0.font?.fontDescriptor.symbolicTraits.contains(.bold) == true
                     && $0.stringValue != "" }
        XCTAssertEqual(titleLabel?.stringValue, "Permission Needed")
    }

    func testDisplayTitleFallsBackToNotificationType() {
        let item = makeItem(notificationType: "idle_prompt", title: nil)
        let row = NSView(frame: NSRect(x: 0, y: 0, width: 320, height: 80))
        let layout = NotificationRowBuilder.Layout(message: item.notification.message, width: 202)

        NotificationRowBuilder.buildContent(
            item: item, in: row, layout: layout,
            messageWidth: 202, isRead: false
        )

        let titleLabel = row.subviews.compactMap { $0 as? NSTextField }
            .first { $0.font?.fontDescriptor.symbolicTraits.contains(.bold) == true
                     && $0.stringValue != "" }
        XCTAssertEqual(titleLabel?.stringValue, "Claude is idle")
    }

    func testProjectLineIncludesNotificationType() {
        let item = makeItem(notificationType: "permission_prompt")
        let row = NSView(frame: NSRect(x: 0, y: 0, width: 320, height: 80))
        let layout = NotificationRowBuilder.Layout(message: item.notification.message, width: 202)

        NotificationRowBuilder.buildContent(
            item: item, in: row, layout: layout,
            messageWidth: 202, isRead: false
        )

        let projectLabel = row.subviews.compactMap { $0 as? NSTextField }
            .first { $0.font == .systemFont(ofSize: 10)
                     && $0.stringValue.contains("project") }
        XCTAssertNotNil(projectLabel)
        XCTAssertTrue(
            projectLabel!.stringValue.contains("Permission Prompt"),
            "Project line '\(projectLabel!.stringValue)' should contain formatted notification type"
        )
    }
}
