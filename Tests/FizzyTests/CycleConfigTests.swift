// Tests/FizzyTests/CycleConfigTests.swift
import XCTest
import CoreGraphics
@testable import FizzyKit

final class CycleConfigTests: XCTestCase {
    private let testKeys = ["cycleModifierFlags", "cycleDisplayMode"]

    override func setUp() {
        super.setUp()
        for key in testKeys { UserDefaults.standard.removeObject(forKey: key) }
    }

    override func tearDown() {
        for key in testKeys { UserDefaults.standard.removeObject(forKey: key) }
        super.tearDown()
    }

    func testDefaultValues() {
        let config = CycleConfig()
        XCTAssertTrue(config.modifierFlags.contains(.maskCommand))
        XCTAssertTrue(config.modifierFlags.contains(.maskShift))
        XCTAssertEqual(config.displayMode, .listAndPreview)
    }

    func testSaveAndLoadRoundTrip() {
        var config = CycleConfig()
        config.modifierFlags = [.maskCommand, .maskAlternate]
        config.displayMode = .previewOnly
        config.save()

        let loaded = CycleConfig.load()
        XCTAssertTrue(loaded.modifierFlags.contains(.maskCommand))
        XCTAssertTrue(loaded.modifierFlags.contains(.maskAlternate))
        XCTAssertFalse(loaded.modifierFlags.contains(.maskShift))
        XCTAssertEqual(loaded.displayMode, .previewOnly)
    }

    func testLoadWithNoSavedDefaults() {
        let config = CycleConfig.load()
        XCTAssertTrue(config.modifierFlags.contains(.maskCommand))
        XCTAssertTrue(config.modifierFlags.contains(.maskShift))
        XCTAssertEqual(config.displayMode, .listAndPreview)
    }

    func testDisplayModeCaseIterable() {
        XCTAssertEqual(CycleConfig.DisplayMode.allCases.count, 2)
    }
}
