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
        keyCode: UInt16 = 124,
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
        var config = CycleConfig()
        if let rawFlags = defaults.object(forKey: modifierKey) as? UInt64 {
            config.modifierFlags = CGEventFlags(rawValue: rawFlags)
        }
        if let rawKeyCode = defaults.object(forKey: keyCodeKey) as? Int {
            config.keyCode = UInt16(rawKeyCode)
        }
        if let rawMode = defaults.string(forKey: displayModeKey),
           let mode = DisplayMode(rawValue: rawMode) {
            config.displayMode = mode
        }
        return config
    }

    public func save() {
        let defaults = UserDefaults.standard
        defaults.set(modifierFlags.rawValue, forKey: Self.modifierKey)
        defaults.set(Int(keyCode), forKey: Self.keyCodeKey)
        defaults.set(displayMode.rawValue, forKey: Self.displayModeKey)
    }
}
