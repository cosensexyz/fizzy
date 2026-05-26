// Tests/FizzyTests/SettingsPanelTests.swift
import XCTest
import CoreGraphics
@testable import FizzyKit

final class SettingsPanelTests: XCTestCase {
    // MARK: - Permission status mapping

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

    // MARK: - Shortcut description

    func testShortcutDescriptionDefault() {
        let desc = SettingsPanel.shortcutDescription(
            modifiers: [.maskCommand, .maskShift], keyCode: 49
        )
        XCTAssertEqual(desc, "Shift+Cmd+Space")
    }

    func testShortcutDescriptionAllModifiers() {
        let desc = SettingsPanel.shortcutDescription(
            modifiers: [.maskControl, .maskAlternate, .maskShift, .maskCommand],
            keyCode: 49
        )
        XCTAssertEqual(desc, "Ctrl+Opt+Shift+Cmd+Space")
    }

    func testShortcutDescriptionCustomKey() {
        let desc = SettingsPanel.shortcutDescription(
            modifiers: [.maskCommand], keyCode: 36
        )
        XCTAssertEqual(desc, "Cmd+Return")
    }

    func testShortcutDescriptionUnknownKey() {
        let desc = SettingsPanel.shortcutDescription(
            modifiers: [.maskCommand], keyCode: 999
        )
        XCTAssertTrue(desc.hasPrefix("Cmd+"))
    }

    // MARK: - Key name mapping

    func testKeyNameForCommonKeys() {
        XCTAssertEqual(SettingsPanel.keyName(for: 49), "Space")
        XCTAssertEqual(SettingsPanel.keyName(for: 36), "Return")
        XCTAssertEqual(SettingsPanel.keyName(for: 48), "Tab")
        XCTAssertEqual(SettingsPanel.keyName(for: 53), "Escape")
        XCTAssertEqual(SettingsPanel.keyName(for: 51), "Delete")
    }

    func testKeyNameForArrows() {
        XCTAssertEqual(SettingsPanel.keyName(for: 123), "←")
        XCTAssertEqual(SettingsPanel.keyName(for: 124), "→")
        XCTAssertEqual(SettingsPanel.keyName(for: 125), "↓")
        XCTAssertEqual(SettingsPanel.keyName(for: 126), "↑")
    }
}
