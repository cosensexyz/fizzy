import XCTest
@testable import FizzyKit

final class MenuBarControllerTests: XCTestCase {
    func testMenuContainsSettingsAndQuit() {
        let menuBar = MenuBarController()
        let items = menuBar.menu.items
        XCTAssertEqual(items.count, 4)
        XCTAssertEqual(items[0].title, "Fizzy — localhost:7319")
        XCTAssertTrue(items[1].isSeparatorItem)
        XCTAssertEqual(items[2].title, "Settings...")
        XCTAssertEqual(items[2].keyEquivalent, ",")
        XCTAssertTrue(items[3].title.contains("Quit"))
    }

    func testSettingsCallbackFires() {
        let menuBar = MenuBarController()
        var fired = false
        menuBar.onSettingsClicked = { fired = true }
        let settingsItem = menuBar.menu.items[2]
        _ = settingsItem.target?.perform(settingsItem.action)
        XCTAssertTrue(fired)
    }
}
