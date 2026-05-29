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

    // MARK: - Preset colors

    func testPresetColorsCount() {
        XCTAssertEqual(SettingsPanel.presetColors.count, 6)
    }

    func testPresetColorsProduceValidHex() {
        for preset in SettingsPanel.presetColors {
            let hex = preset.color.hexString
            XCTAssertTrue(hex.hasPrefix("#"), "\(preset.name) hex should start with #")
            XCTAssertEqual(hex.count, 7, "\(preset.name) hex should be 7 chars")
        }
    }

    func testPresetWhiteIsDefault() {
        let white = SettingsPanel.presetColors.first
        XCTAssertEqual(white?.name, "White")
        XCTAssertEqual(white?.color.hexString, "#FFFFFF")
    }

    func testPresetColorsMatchDefaultConfig() {
        let defaultHex = FizzyConfig().bubbleColorHex
        let match = SettingsPanel.presetColors.contains(where: { $0.color.hexString == defaultHex })
        XCTAssertTrue(match, "Default config color should match a preset")
    }
}
