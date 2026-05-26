import Foundation

public struct FizzyConfig {
    public var cycle: CycleConfig
    public var listTrigger: ListTrigger

    public enum ListTrigger: String, CaseIterable {
        case click
        case hover
    }

    public init(cycle: CycleConfig = CycleConfig(), listTrigger: ListTrigger = .click) {
        self.cycle = cycle
        self.listTrigger = listTrigger
    }

    private static let listTriggerKey = "listTrigger"

    public static func load() -> FizzyConfig {
        var config = FizzyConfig()
        config.cycle = CycleConfig.load()
        if let raw = UserDefaults.standard.string(forKey: listTriggerKey),
           let trigger = ListTrigger(rawValue: raw) {
            config.listTrigger = trigger
        }
        return config
    }

    public func save() {
        cycle.save()
        UserDefaults.standard.set(listTrigger.rawValue, forKey: Self.listTriggerKey)
    }
}
