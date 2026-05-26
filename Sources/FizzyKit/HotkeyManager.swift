// Sources/FizzyKit/HotkeyManager.swift
import CoreGraphics
import AppKit

public enum HotkeyManager {
    public enum State: Equatable {
        case idle
        case cycling
    }

    public enum Action: Equatable {
        case startSession
        case startSessionBackward
        case cycleForward
        case cycleBackward
        case activate
        case cancel
    }

    public struct EventResult: Equatable {
        public let action: Action
        public let newState: State
    }

    private(set) static var state: State = .idle
    private static var _config = CycleConfig.load()
    private static var eventTap: CFMachPort?
    private static var runLoopSource: CFRunLoopSource?

    public static var onSessionStart: (() -> Void)?
    public static var onSessionStartBackward: (() -> Void)?
    public static var onCycleForward: (() -> Void)?
    public static var onCycleBackward: (() -> Void)?
    public static var onActivate: (() -> Void)?
    public static var onCancel: (() -> Void)?

    // MARK: - Pure state machine

    public static func mapEvent(
        keyCode: UInt16,
        eventType: CGEventType,
        flags: CGEventFlags,
        state: State,
        config: CycleConfig
    ) -> EventResult? {
        let hasModifiers = flags.contains(config.modifierFlags)

        switch (state, eventType) {
        case (.idle, .keyDown) where keyCode == 124 && hasModifiers:
            return EventResult(action: .startSession, newState: .cycling)

        case (.idle, .keyDown) where keyCode == 123 && hasModifiers:
            return EventResult(action: .startSessionBackward, newState: .cycling)

        case (.cycling, .keyDown) where hasModifiers:
            switch keyCode {
            case 124:
                return EventResult(action: .cycleForward, newState: .cycling)
            case 123:
                return EventResult(action: .cycleBackward, newState: .cycling)
            case 125:
                return EventResult(action: .activate, newState: .idle)
            case 126:
                return EventResult(action: .cancel, newState: .idle)
            default:
                return nil
            }

        case (.cycling, .flagsChanged) where !hasModifiers:
            return EventResult(action: .activate, newState: .idle)

        default:
            return nil
        }
    }

    // MARK: - Tap lifecycle

    public static func install() {
        guard eventTap == nil else { return }
        guard AXIsProcessTrusted() else { return }

        let mask: CGEventMask = (1 << CGEventType.keyDown.rawValue) |
                                (1 << CGEventType.flagsChanged.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, _ in
                HotkeyManager.handleTapEvent(type: type, event: event)
            },
            userInfo: nil
        ) else { return }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource!, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    public static func uninstall() {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        eventTap = nil
        runLoopSource = nil
        state = .idle
    }

    public static func updateConfig(_ config: CycleConfig) {
        _config = config
    }

    // MARK: - Private (tap callback runs on main thread via CFRunLoopGetMain)

    private static func handleTapEvent(
        type: CGEventType,
        event: CGEvent
    ) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }

        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags

        guard let result = mapEvent(
            keyCode: keyCode, eventType: type, flags: flags,
            state: state, config: _config
        ) else {
            return Unmanaged.passUnretained(event)
        }

        state = result.newState

        switch result.action {
        case .startSession: onSessionStart?()
        case .startSessionBackward: onSessionStartBackward?()
        case .cycleForward: onCycleForward?()
        case .cycleBackward: onCycleBackward?()
        case .activate: onActivate?()
        case .cancel: onCancel?()
        }

        return nil
    }
}
