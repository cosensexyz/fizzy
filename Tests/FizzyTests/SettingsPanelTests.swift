// Tests/FizzyTests/SettingsPanelTests.swift
import XCTest
import CoreGraphics
@testable import FizzyKit

final class SettingsPanelTests: XCTestCase {
    func testPermissionStatusGranted() {
        XCTAssertEqual(SettingsPanel.permissionStatus(for: noErr), .granted)
    }

    func testPermissionStatusDenied() {
        XCTAssertEqual(SettingsPanel.permissionStatus(for: OSStatus(errAEEventNotPermitted)), .denied)
    }

    func testPermissionStatusNotAsked() {
        XCTAssertEqual(SettingsPanel.permissionStatus(for: OSStatus(errAEEventWouldRequireUserConsent)), .notAsked)
    }

    func testPermissionStatusNotRunning() {
        XCTAssertEqual(SettingsPanel.permissionStatus(for: OSStatus(procNotFound)), .notRunning)
    }

    func testPermissionStatusUnknownDefaultsToNotRunning() {
        XCTAssertEqual(SettingsPanel.permissionStatus(for: -9999), .notRunning)
    }

    func testModifierSymbolsDefault() {
        let symbols = SettingsPanel.modifierSymbols(for: [.maskCommand, .maskShift])
        XCTAssertEqual(symbols, ["⌘", "⇧"])
    }

    func testModifierSymbolsAll() {
        let symbols = SettingsPanel.modifierSymbols(
            for: [.maskControl, .maskAlternate, .maskShift, .maskCommand]
        )
        XCTAssertEqual(symbols, ["⌘", "⇧", "⌥", "⌃"])
    }

    func testModifierSymbolsSingle() {
        let symbols = SettingsPanel.modifierSymbols(for: [.maskCommand])
        XCTAssertEqual(symbols, ["⌘"])
    }

    // MARK: - Modifier validation

    func testRemovingOneOfTwoModifiersIsValid() {
        XCTAssertTrue(SettingsPanel.isValidRemoval(
            current: [.maskCommand, .maskShift], removing: .maskShift
        ))
    }

    func testRemovingLastModifierIsInvalid() {
        XCTAssertFalse(SettingsPanel.isValidRemoval(
            current: [.maskCommand], removing: .maskCommand
        ))
    }

    func testRemovingUnsetModifierIsValid() {
        XCTAssertTrue(SettingsPanel.isValidRemoval(
            current: [.maskCommand, .maskShift], removing: .maskAlternate
        ))
    }
}
