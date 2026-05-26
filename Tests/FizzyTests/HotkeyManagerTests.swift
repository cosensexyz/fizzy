// Tests/FizzyTests/HotkeyManagerTests.swift
import XCTest
import CoreGraphics
@testable import FizzyKit

final class HotkeyManagerTests: XCTestCase {
    private let defaultConfig = CycleConfig()

    // MARK: - Idle state

    func testIdleStartsSessionOnModifierPlusArrowRight() {
        let result = HotkeyManager.mapEvent(
            keyCode: 124, eventType: .keyDown,
            flags: [.maskCommand, .maskShift],
            state: .idle, config: defaultConfig
        )
        XCTAssertEqual(result?.action, .startSession)
        XCTAssertEqual(result?.newState, .cycling)
    }

    func testIdleStartsSessionOnModifierPlusArrowLeft() {
        let result = HotkeyManager.mapEvent(
            keyCode: 123, eventType: .keyDown,
            flags: [.maskCommand, .maskShift],
            state: .idle, config: defaultConfig
        )
        XCTAssertEqual(result?.action, .startSession)
        XCTAssertEqual(result?.newState, .cycling)
    }

    func testIdleIgnoresKeyWithoutModifiers() {
        let result = HotkeyManager.mapEvent(
            keyCode: 124, eventType: .keyDown,
            flags: [], state: .idle, config: defaultConfig
        )
        XCTAssertNil(result)
    }

    func testIdleIgnoresWrongKey() {
        let result = HotkeyManager.mapEvent(
            keyCode: 13, eventType: .keyDown,
            flags: [.maskCommand, .maskShift],
            state: .idle, config: defaultConfig
        )
        XCTAssertNil(result)
    }

    func testIdleIgnoresPartialModifiers() {
        let result = HotkeyManager.mapEvent(
            keyCode: 124, eventType: .keyDown,
            flags: [.maskCommand], state: .idle, config: defaultConfig
        )
        XCTAssertNil(result)
    }

    func testIdleIgnoresFlagsChanged() {
        let result = HotkeyManager.mapEvent(
            keyCode: 0, eventType: .flagsChanged,
            flags: [], state: .idle, config: defaultConfig
        )
        XCTAssertNil(result)
    }

    // MARK: - Cycling state: forward

    func testCyclingForwardWithArrowRight() {
        let result = HotkeyManager.mapEvent(
            keyCode: 124, eventType: .keyDown,
            flags: [.maskCommand, .maskShift],
            state: .cycling, config: defaultConfig
        )
        XCTAssertEqual(result?.action, .cycleForward)
        XCTAssertEqual(result?.newState, .cycling)
    }

    // MARK: - Cycling state: backward

    func testCyclingBackwardWithArrowLeft() {
        let result = HotkeyManager.mapEvent(
            keyCode: 123, eventType: .keyDown,
            flags: [.maskCommand, .maskShift],
            state: .cycling, config: defaultConfig
        )
        XCTAssertEqual(result?.action, .cycleBackward)
        XCTAssertEqual(result?.newState, .cycling)
    }

    // MARK: - Cycling state: activate/cancel

    func testCyclingActivateWithArrowDown() {
        let result = HotkeyManager.mapEvent(
            keyCode: 125, eventType: .keyDown,
            flags: [.maskCommand, .maskShift],
            state: .cycling, config: defaultConfig
        )
        XCTAssertEqual(result?.action, .activate)
        XCTAssertEqual(result?.newState, .idle)
    }

    func testCyclingCancelWithArrowUp() {
        let result = HotkeyManager.mapEvent(
            keyCode: 126, eventType: .keyDown,
            flags: [.maskCommand, .maskShift],
            state: .cycling, config: defaultConfig
        )
        XCTAssertEqual(result?.action, .cancel)
        XCTAssertEqual(result?.newState, .idle)
    }

    func testCyclingActivateOnModifierRelease() {
        let result = HotkeyManager.mapEvent(
            keyCode: 0, eventType: .flagsChanged,
            flags: [.maskCommand],  // Shift released
            state: .cycling, config: defaultConfig
        )
        XCTAssertEqual(result?.action, .activate)
        XCTAssertEqual(result?.newState, .idle)
    }

    func testCyclingActivateOnAllModifiersReleased() {
        let result = HotkeyManager.mapEvent(
            keyCode: 0, eventType: .flagsChanged,
            flags: [],  // all released
            state: .cycling, config: defaultConfig
        )
        XCTAssertEqual(result?.action, .activate)
        XCTAssertEqual(result?.newState, .idle)
    }

    // MARK: - Cycling state: ignore unrelated

    func testCyclingIgnoresUnrelatedKey() {
        let result = HotkeyManager.mapEvent(
            keyCode: 13, eventType: .keyDown,
            flags: [.maskCommand, .maskShift],
            state: .cycling, config: defaultConfig
        )
        XCTAssertNil(result)
    }

    func testCyclingIgnoresKeyWithoutModifiers() {
        let result = HotkeyManager.mapEvent(
            keyCode: 124, eventType: .keyDown,
            flags: [], state: .cycling, config: defaultConfig
        )
        XCTAssertNil(result)
    }

    // MARK: - Custom config

    func testCustomModifierAndKey() {
        let config = CycleConfig(
            modifierFlags: [.maskCommand, .maskAlternate],
            keyCode: 36
        )
        let result = HotkeyManager.mapEvent(
            keyCode: 36, eventType: .keyDown,
            flags: [.maskCommand, .maskAlternate],
            state: .idle, config: config
        )
        XCTAssertEqual(result?.action, .startSession)
    }

    func testCustomConfigRejectsOldShortcut() {
        let config = CycleConfig(
            modifierFlags: [.maskCommand, .maskAlternate],
            keyCode: 36
        )
        let result = HotkeyManager.mapEvent(
            keyCode: 49, eventType: .keyDown,
            flags: [.maskCommand, .maskShift],
            state: .idle, config: config
        )
        XCTAssertNil(result)
    }

    // MARK: - Extra modifiers allowed

    func testExtraModifiersStillMatch() {
        let result = HotkeyManager.mapEvent(
            keyCode: 124, eventType: .keyDown,
            flags: [.maskCommand, .maskShift, .maskAlternate],
            state: .idle, config: defaultConfig
        )
        XCTAssertEqual(result?.action, .startSession)
    }
}
