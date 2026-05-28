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
    private var cycleController: CycleSessionController!
    private var settingsPanel: SettingsPanel?
    private var accessibilityTimer: Timer?

    public override init() {
        super.init()
    }

    public func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        window = FizzyWindow()
        window.orderFront(nil)
        window.onPetClicked = { [weak self] in self?.toggleList() }
        window.onPetHoverEnter = { [weak self] in
            if FizzyConfig.load().listTrigger == .hover { self?.showList() }
        }
        window.onPetHoverExit = { [weak self] in
            if FizzyConfig.load().listTrigger == .hover { self?.scheduleHideList() }
        }
        window.onSettingsClicked = { [weak self] in self?.showSettings() }

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
        menuBar.onSettingsClicked = { [weak self] in self?.showSettings() }
        menuBar.install()

        server = FizzyServer(
            port: 7319,
            onNotification: { [weak self] agent, payload, env in
                DispatchQueue.main.async { [weak self] in
                    self?.handleNotification(agent: agent, payload: payload, env: env)
                }
            },
            onSessionEnd: { [weak self] req in
                DispatchQueue.main.async { [weak self] in
                    self?.handleSessionEnd(req)
                }
            }
        )

        do {
            try server.start()
            NSLog("FizzyServer listening on 127.0.0.1:7319")
        } catch {
            NSLog("FizzyServer failed to start: \(error)")
        }

        cycleController = CycleSessionController(store: store)
        cycleController.onOpenSession = { [weak self] item in
            self?.openSession(item)
            self?.updateFizzyState()
            if self?.listVisible == true { self?.listPanel.reload() }
        }

        HotkeyManager.onSessionStart = { [weak self] in self?.cycleController.startSession() }
        HotkeyManager.onSessionStartBackward = { [weak self] in self?.cycleController.startSession(backward: true) }
        HotkeyManager.onCycleForward = { [weak self] in self?.cycleController.cycleForward() }
        HotkeyManager.onCycleBackward = { [weak self] in self?.cycleController.cycleBackward() }
        HotkeyManager.onActivate = { [weak self] in self?.cycleController.activate() }
        HotkeyManager.onCancel = { [weak self] in self?.cycleController.cancel() }
        if !HotkeyManager.install(prompt: true) {
            accessibilityTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                if HotkeyManager.install() {
                    self?.accessibilityTimer?.invalidate()
                    self?.accessibilityTimer = nil
                }
            }
        }
        DistributedNotificationCenter.default().addObserver(
            self, selector: #selector(handleActivateNotification),
            name: SingleInstanceGuard.activateNotificationName, object: nil
        )
    }

    private func handleNotification(agent: String, payload: any AgentPayload, env: EnvironmentContext) {
        let item = store.add(payload, agent: agent, env: env)
        window.updateFizzyState(unreadCount: store.unreadCount)
        if listVisible { listPanel.reload() }
        toastManager.show(item: item, relativeTo: window) { [weak self] item in
            self?.openSession(item)
        }
    }

    private func handleSessionEnd(_ req: SessionEndRequest) {
        store.endSession(agent: req.agent, sessionId: req.sessionId)
        window.updateFizzyState(unreadCount: store.unreadCount)
        if listVisible { listPanel.reload() }
    }

    @objc private func windowDidMove(_ notification: Notification) {
        window.saveOrigin()
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

    private func showSettings() {
        if settingsPanel == nil {
            settingsPanel = SettingsPanel()
        }
        settingsPanel?.show()
    }

    @objc private func handleActivateNotification(_ notification: Notification) {
        window.bounce()
    }

    public func applicationWillTerminate(_ notification: Notification) {
        DistributedNotificationCenter.default().removeObserver(self)
        accessibilityTimer?.invalidate()
        server?.stop()
    }
}
