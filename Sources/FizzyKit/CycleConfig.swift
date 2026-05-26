// Sources/FizzyKit/CycleConfig.swift
import CoreGraphics
import Foundation

public struct CycleConfig {
    public var modifierFlags: CGEventFlags
    public var keyCode: UInt16
    public var displayMode: DisplayMode

    public enum DisplayMode: String, CaseIterable {
        case listAndPreview
        case previewOnly
    }

    public init(
        modifierFlags: CGEventFlags = [.maskCommand, .maskShift],
        keyCode: UInt16 = 49,
        displayMode: DisplayMode = .listAndPreview
    ) {
        self.modifierFlags = modifierFlags
        self.keyCode = keyCode
        self.displayMode = displayMode
    }

    private static let modifierKey = "cycleModifierFlags"
    private static let keyCodeKey = "cycleKeyCode"
    private static let displayModeKey = "cycleDisplayMode"

    public static func load() -> CycleConfig {
        let defaults = UserDefaults.standard
        let rawFlags = defaults.object(forKey: modifierKey) as? UInt64
        let rawKeyCode = defaults.object(forKey: keyCodeKey) as? Int
        let rawMode = defaults.string(forKey: displayModeKey)

        return CycleConfig(
            modifierFlags: rawFlags.map { CGEventFlags(rawValue: $0) } ?? [.maskCommand, .maskShift],
            keyCode: rawKeyCode.map { UInt16($0) } ?? 49,
            displayMode: rawMode.flatMap { DisplayMode(rawValue: $0) } ?? .listAndPreview
        )
    }

    public func save() {
        let defaults = UserDefaults.standard
        defaults.set(modifierFlags.rawValue, forKey: Self.modifierKey)
        defaults.set(Int(keyCode), forKey: Self.keyCodeKey)
        defaults.set(displayMode.rawValue, forKey: Self.displayModeKey)
    }
}
