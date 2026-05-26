import XCTest
import CoreGraphics
@testable import FizzyKit

final class FizzyConfigTests: XCTestCase {
    private let testKeys = ["cycleModifierFlags", "cycleDisplayMode", "listTrigger"]

    override func setUp() {
        super.setUp()
        for key in testKeys { UserDefaults.standard.removeObject(forKey: key) }
    }

    override func tearDown() {
        for key in testKeys { UserDefaults.standard.removeObject(forKey: key) }
        super.tearDown()
    }

    func testDefaultListTrigger() {
        let config = FizzyConfig()
        XCTAssertEqual(config.listTrigger, .click)
    }

    func testDefaultCycleConfig() {
        let config = FizzyConfig()
        XCTAssertTrue(config.cycle.modifierFlags.contains(.maskCommand))
        XCTAssertTrue(config.cycle.modifierFlags.contains(.maskShift))
        XCTAssertEqual(config.cycle.displayMode, .listAndPreview)
    }

    func testSaveAndLoadRoundTrip() {
        var config = FizzyConfig()
        config.listTrigger = .hover
        config.cycle.modifierFlags = [.maskCommand, .maskAlternate]
        config.cycle.displayMode = .previewOnly
        config.save()

        let loaded = FizzyConfig.load()
        XCTAssertEqual(loaded.listTrigger, .hover)
        XCTAssertTrue(loaded.cycle.modifierFlags.contains(.maskCommand))
        XCTAssertTrue(loaded.cycle.modifierFlags.contains(.maskAlternate))
        XCTAssertFalse(loaded.cycle.modifierFlags.contains(.maskShift))
        XCTAssertEqual(loaded.cycle.displayMode, .previewOnly)
    }

    func testLoadWithNoSavedDefaults() {
        let config = FizzyConfig.load()
        XCTAssertEqual(config.listTrigger, .click)
        XCTAssertTrue(config.cycle.modifierFlags.contains(.maskCommand))
        XCTAssertEqual(config.cycle.displayMode, .listAndPreview)
    }
}
