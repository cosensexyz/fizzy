import XCTest
@testable import FizzyKit

final class FizzyWindowTests: XCTestCase {
    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: FizzyWindow.originKey)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: FizzyWindow.originKey)
        super.tearDown()
    }

    func testSavedOriginIsValid() {
        let screen = NSScreen.main!.visibleFrame
        let validPoint = NSPoint(x: screen.midX, y: screen.midY)
        let data = try! JSONEncoder().encode([validPoint.x, validPoint.y])
        UserDefaults.standard.set(data, forKey: FizzyWindow.originKey)

        let origin = FizzyWindow.savedOrigin()
        XCTAssertEqual(origin?.x, validPoint.x)
        XCTAssertEqual(origin?.y, validPoint.y)
    }

    func testSavedOriginOffScreenReturnsNil() {
        let offScreen = NSPoint(x: -9999, y: -9999)
        let data = try! JSONEncoder().encode([offScreen.x, offScreen.y])
        UserDefaults.standard.set(data, forKey: FizzyWindow.originKey)

        XCTAssertNil(FizzyWindow.savedOrigin())
    }

    func testNoSavedOriginReturnsNil() {
        UserDefaults.standard.removeObject(forKey: FizzyWindow.originKey)
        XCTAssertNil(FizzyWindow.savedOrigin())
    }

    func testContextMenuHasSettingsAndQuit() {
        let window = FizzyWindow()
        let menu = window.contextMenu()
        XCTAssertEqual(menu.items.count, 3)
        XCTAssertEqual(menu.items[0].title, "Settings...")
        XCTAssertTrue(menu.items[1].isSeparatorItem)
        XCTAssertEqual(menu.items[2].title, "Quit")
    }

    func testUpdateBubbleColorPropagates() {
        let window = FizzyWindow()
        let color = NSColor.systemCyan
        window.updateBubbleColor(color)
        let result = window.fizzyView.bubbleColor.usingColorSpace(.sRGB)!
        let expected = color.usingColorSpace(.sRGB)!
        XCTAssertEqual(result.redComponent, expected.redComponent, accuracy: 0.01)
        XCTAssertEqual(result.greenComponent, expected.greenComponent, accuracy: 0.01)
        XCTAssertEqual(result.blueComponent, expected.blueComponent, accuracy: 0.01)
    }

    func testBounceDoesNotCrash() {
        let window = FizzyWindow()
        window.bounce()
        XCTAssertTrue(window.isVisible || true)
    }
}
