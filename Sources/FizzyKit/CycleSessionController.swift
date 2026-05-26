import AppKit

public final class CycleSessionController {
    private let store: NotificationStore
    private let config: () -> CycleConfig
    private var panel: SwitcherPanel?
    private var sessionItems: [NotificationItem] = []

    public private(set) var selectedIndex = 0
    public private(set) var isActive = false

    public var onOpenSession: ((NotificationItem) -> Void)?

    public init(store: NotificationStore, config: @escaping () -> CycleConfig = { CycleConfig.load() }) {
        self.store = store
        self.config = config
    }

    public func startSession(backward: Bool = false) {
        guard !store.items.isEmpty else { return }
        sessionItems = store.items
        isActive = true
        selectedIndex = backward ? sessionItems.count - 1 : 0

        if config().displayMode == .listAndPreview {
            panel = SwitcherPanel(items: sessionItems, selectedIndex: selectedIndex)
            panel?.show()
        }

        TerminalActivator.enterPreview(for: sessionItems[selectedIndex])
    }

    public func cycleForward() {
        guard isActive, !sessionItems.isEmpty else { return }
        selectedIndex = (selectedIndex + 1) % sessionItems.count
        panel?.updateSelection(index: selectedIndex)
        TerminalActivator.switchPreview(to: sessionItems[selectedIndex])
    }

    public func cycleBackward() {
        guard isActive, !sessionItems.isEmpty else { return }
        selectedIndex = (selectedIndex - 1 + sessionItems.count) % sessionItems.count
        panel?.updateSelection(index: selectedIndex)
        TerminalActivator.switchPreview(to: sessionItems[selectedIndex])
    }

    public func activate() {
        guard isActive else { return }
        let item = sessionItems[selectedIndex]
        TerminalActivator.clearPreviewState()
        panel?.hide()
        panel = nil
        isActive = false
        selectedIndex = 0
        sessionItems = []
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
        sessionItems = []
    }
}
