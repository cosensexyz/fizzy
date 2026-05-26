import AppKit

public final class CycleSessionController {
    private let store: NotificationStore
    private let config: () -> CycleConfig
    private var panel: SwitcherPanel?

    public private(set) var selectedIndex = 0
    public private(set) var isActive = false

    public var onOpenSession: ((NotificationItem) -> Void)?

    public init(store: NotificationStore, config: @escaping () -> CycleConfig = { CycleConfig.load() }) {
        self.store = store
        self.config = config
    }

    public func startSession() {
        guard !store.items.isEmpty else { return }
        isActive = true
        selectedIndex = 0

        if config().displayMode == .listAndPreview {
            panel = SwitcherPanel(items: store.items, selectedIndex: 0)
            panel?.show()
        }

        TerminalActivator.enterPreview(for: store.items[0])
    }

    public func cycleForward() {
        guard isActive, !store.items.isEmpty else { return }
        selectedIndex = (selectedIndex + 1) % store.items.count
        panel?.updateSelection(index: selectedIndex)
        TerminalActivator.switchPreview(to: store.items[selectedIndex])
    }

    public func cycleBackward() {
        guard isActive, !store.items.isEmpty else { return }
        selectedIndex = (selectedIndex - 1 + store.items.count) % store.items.count
        panel?.updateSelection(index: selectedIndex)
        TerminalActivator.switchPreview(to: store.items[selectedIndex])
    }

    public func activate() {
        guard isActive else { return }
        let item = store.items[selectedIndex]
        TerminalActivator.clearPreviewState()
        panel?.hide()
        panel = nil
        isActive = false
        selectedIndex = 0
        store.dismiss(id: item.id)
        onOpenSession?(item)
    }

    public func cancel() {
        guard isActive else { return }
        TerminalActivator.exitPreview()
        panel?.hide()
        panel = nil
        isActive = false
        selectedIndex = 0
    }
}
