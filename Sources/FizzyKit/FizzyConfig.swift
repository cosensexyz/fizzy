import Foundation

public struct FizzyConfig {
    public var cycle: CycleConfig
    public var listTrigger: ListTrigger
    public var bubbleColorHex: String

    public enum ListTrigger: String, CaseIterable {
        case click
        case hover
    }

    public init(cycle: CycleConfig = CycleConfig(), listTrigger: ListTrigger = .click, bubbleColorHex: String = "#FFFFFF") {
        self.cycle = cycle
        self.listTrigger = listTrigger
        self.bubbleColorHex = bubbleColorHex
    }

    private static let listTriggerKey = "listTrigger"
    private static let bubbleColorKey = "bubbleColor"

    public static func load() -> FizzyConfig {
        var config = FizzyConfig()
        config.cycle = CycleConfig.load()
        if let raw = UserDefaults.standard.string(forKey: listTriggerKey),
           let trigger = ListTrigger(rawValue: raw) {
            config.listTrigger = trigger
        }
        if let hex = UserDefaults.standard.string(forKey: bubbleColorKey) {
            config.bubbleColorHex = hex
        }
        return config
    }

    public func save() {
        cycle.save()
        UserDefaults.standard.set(listTrigger.rawValue, forKey: Self.listTriggerKey)
        UserDefaults.standard.set(bubbleColorHex, forKey: Self.bubbleColorKey)
    }
}
