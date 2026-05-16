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

    public override init() {
        super.init()
    }

    public func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        window = FizzyWindow()
        window.orderFront(nil)
        window.onPetClicked = { [weak self] in self?.toggleList() }

        NotificationCenter.default.addObserver(
            self, selector: #selector(windowDidMove),
            name: NSWindow.didMoveNotification, object: window
        )

        toastManager = ToastManager()
        listPanel = NotificationListPanel()
        listPanel.onClose = { [weak self] in
            self?.listPanel.orderOut(nil)
            self?.listVisible = false
        }

        NotificationCenter.default.addObserver(
            self, selector: #selector(listPanelDidMove),
            name: NSWindow.didMoveNotification, object: listPanel
        )

        menuBar = MenuBarController()

        server = FizzyServer(port: 7319) { [weak self] notification in
            DispatchQueue.main.async {
                self?.handleNotification(notification)
            }
        }

        do {
            try server.start()
            NSLog("FizzyServer listening on 127.0.0.1:7319")
        } catch {
            NSLog("FizzyServer failed to start: \(error)")
        }
    }

    private func handleNotification(_ notification: ClaudeCodeNotification) {
        let item = store.add(notification)
        window.updateFizzyState(unreadCount: store.unreadCount)
        toastManager.show(item: item, relativeTo: window)
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

    private func toggleList() {
        if listVisible {
            listPanel.orderOut(nil)
            listVisible = false
        } else {
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
    }

    private func openSession(_ item: NotificationItem) {
        activateTerminal()
    }

    private func updateFizzyState() {
        window.updateFizzyState(unreadCount: store.unreadCount)
    }

    private func activateTerminal() {
        let terminalBundleIds = [
            "com.mitchellh.ghostty",
            "com.googlecode.iterm2",
            "com.apple.Terminal",
        ]
        let running = NSWorkspace.shared.runningApplications
        for bundleId in terminalBundleIds {
            if let app = running.first(where: { $0.bundleIdentifier == bundleId && !$0.isTerminated }) {
                app.activate()
                return
            }
        }
    }

    public func applicationWillTerminate(_ notification: Notification) {
        server?.stop()
    }
}
