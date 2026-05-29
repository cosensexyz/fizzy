import XCTest
@testable import FizzyKit

final class FizzyViewTests: XCTestCase {
    func testIdleStateHasNoRevealedSlots() {
        let view = FizzyView()
        view.state = .idle
        XCTAssertEqual(view.revealedSlots.count, 0)
    }

    func testFirstNotificationRevealsNoBubbles() {
        let view = FizzyView()
        view.state = .active(unreadCount: 1)
        XCTAssertEqual(view.revealedSlots.count, 0)
    }

    func testSecondNotificationRevealsFirstBubble() {
        let view = FizzyView()
        view.state = .active(unreadCount: 2)
        XCTAssertEqual(view.revealedSlots.count, 1)
    }

    func testActiveStateRevealsSlots() {
        let view = FizzyView()
        view.state = .active(unreadCount: 4)
        XCTAssertEqual(view.revealedSlots.count, 3)
    }

    func testActiveStateCapsAt4() {
        let view = FizzyView()
        view.state = .active(unreadCount: 10)
        XCTAssertEqual(view.revealedSlots.count, 4)
    }

    func testRevealedSlotsAreValidIndices() {
        let view = FizzyView()
        view.state = .active(unreadCount: 5)
        for index in view.revealedSlots {
            XCTAssertTrue((0..<FizzyView.bubbleSlots.count).contains(index))
        }
        XCTAssertEqual(Set(view.revealedSlots).count, 4)
    }

    func testTransitionToIdleClearsAll() {
        let view = FizzyView()
        view.state = .active(unreadCount: 4)
        view.state = .idle
        XCTAssertEqual(view.revealedSlots.count, 0)
    }

    func testReducingCountRemovesLastRevealed() {
        let view = FizzyView()
        view.state = .active(unreadCount: 5)
        let original = view.revealedSlots
        view.state = .active(unreadCount: 3)
        XCTAssertEqual(view.revealedSlots.count, 2)
        XCTAssertEqual(view.revealedSlots, Array(original.prefix(2)))
    }

    func testIncreasingCountPreservesExisting() {
        let view = FizzyView()
        view.state = .active(unreadCount: 3)
        let first2 = view.revealedSlots
        view.state = .active(unreadCount: 5)
        XCTAssertEqual(Array(view.revealedSlots.prefix(2)), first2)
        XCTAssertEqual(view.revealedSlots.count, 4)
    }

    func testDefaultBubbleColorIsWhite() {
        let view = FizzyView()
        let color = view.bubbleColor.usingColorSpace(.sRGB)!
        XCTAssertEqual(color.redComponent, 1.0, accuracy: 0.01)
        XCTAssertEqual(color.greenComponent, 1.0, accuracy: 0.01)
        XCTAssertEqual(color.blueComponent, 1.0, accuracy: 0.01)
    }

    func testBubbleColorCanBeChanged() {
        let view = FizzyView()
        view.bubbleColor = NSColor.systemCyan
        let color = view.bubbleColor.usingColorSpace(.sRGB)!
        let cyan = NSColor.systemCyan.usingColorSpace(.sRGB)!
        XCTAssertEqual(color.redComponent, cyan.redComponent, accuracy: 0.01)
        XCTAssertEqual(color.greenComponent, cyan.greenComponent, accuracy: 0.01)
        XCTAssertEqual(color.blueComponent, cyan.blueComponent, accuracy: 0.01)
    }
}
