import AppKit

public class FizzyApp: NSObject, NSApplicationDelegate {
    private var window: FizzyWindow!
    private var menuBar: MenuBarController!
    private var server: FizzyServer!
    private let store = NotificationStore()
    private var toastManager: ToastManager!
    private var listPanel: NotificationListPanel!
    private var listVisible = false
    private var petToListOffset = NSPoint.zero
    private var isRepositioning = false
    private var listDismissTimer: Timer?

    public override init() {
        super.init()
    }

    public func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        window = FizzyWindow()
        window.orderFront(nil)
        window.onPetClicked = { [weak self] in self?.toggleList() }
        window.onPetHoverEnter = { [weak self] in self?.showList() }
        window.onPetHoverExit = { [weak self] in self?.scheduleHideList() }

        NotificationCenter.default.addObserver(
            self, selector: #selector(windowDidMove),
            name: NSWindow.didMoveNotification, object: window
        )

        toastManager = ToastManager()
        listPanel = NotificationListPanel()
        listPanel.onClose = { [weak self] in self?.hideList() }
        listPanel.onPanelHoverEnter = { [weak self] in self?.cancelHideList() }
        listPanel.onPanelHoverExit = { [weak self] in self?.scheduleHideList() }

        NotificationCenter.default.addObserver(
            self, selector: #selector(listPanelDidMove),
            name: NSWindow.didMoveNotification, object: listPanel
        )

        menuBar = MenuBarController()

        server = FizzyServer(port: 7319) { [weak self] agent, payload, env in
            DispatchQueue.main.async {
                self?.handleNotification(agent: agent, payload: payload, env: env)
            }
        }

        do {
            try server.start()
            NSLog("FizzyServer listening on 127.0.0.1:7319")
        } catch {
            NSLog("FizzyServer failed to start: \(error)")
        }
    }

    private func handleNotification(agent: String, payload: any AgentPayload, env: EnvironmentContext) {
        let item = store.add(payload, agent: agent, env: env)
        window.updateFizzyState(unreadCount: store.unreadCount)
        if listVisible { listPanel.reload() }
        toastManager.show(item: item, relativeTo: window) { [weak self] item in
            self?.openSession(item)
        }
    }

    @objc private func windowDidMove(_ notification: Notification) {
        guard listVisible, !isRepositioning else { return }
        isRepositioning = true
        listPanel.setFrameOrigin(NSPoint(
            x: window.frame.origin.x + petToListOffset.x,
            y: window.frame.origin.y + petToListOffset.y
        ))
        isRepositioning = false
    }

    @objc private func listPanelDidMove(_ notification: Notification) {
        guard listVisible, !isRepositioning else { return }
        isRepositioning = true
        window.setFrameOrigin(NSPoint(
            x: listPanel.frame.origin.x - petToListOffset.x,
            y: listPanel.frame.origin.y - petToListOffset.y
        ))
        isRepositioning = false
    }

    private func showList() {
        cancelHideList()
        guard !listVisible else { return }
        listPanel.show(
            store: store,
            relativeTo: window,
            onUpdate: { [weak self] in self?.updateFizzyState() },
            onOpen: { [weak self] item in self?.openSession(item) }
        )
        petToListOffset = NSPoint(
            x: listPanel.frame.origin.x - window.frame.origin.x,
            y: listPanel.frame.origin.y - window.frame.origin.y
        )
        listVisible = true
    }

    private func hideList() {
        cancelHideList()
        TerminalActivator.exitPreview()
        listPanel.orderOut(nil)
        listVisible = false
    }

    private func scheduleHideList() {
        listDismissTimer?.invalidate()
        listDismissTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: false) { [weak self] _ in
            self?.hideList()
        }
    }

    private func cancelHideList() {
        listDismissTimer?.invalidate()
        listDismissTimer = nil
    }

    private func toggleList() {
        if listVisible {
            hideList()
        } else {
            showList()
        }
    }

    private func openSession(_ item: NotificationItem) {
        TerminalActivator.activate(for: item)
    }

    private func updateFizzyState() {
        window.updateFizzyState(unreadCount: store.unreadCount)
    }

    public func applicationWillTerminate(_ notification: Notification) {
        server?.stop()
    }
}
