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

    public func startSession(backward: Bool = false) {
        guard !store.items.isEmpty else { return }
        isActive = true
        selectedIndex = backward ? store.items.count - 1 : 0

        if config().displayMode == .listAndPreview {
            panel = SwitcherPanel(items: store.items, selectedIndex: selectedIndex)
            panel?.show()
        }

        TerminalActivator.enterPreview(for: store.items[selectedIndex])
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
        guard selectedIndex < store.items.count else { cancel(); return }
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
