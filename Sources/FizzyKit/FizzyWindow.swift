import AppKit

public final class FizzyWindow: NSWindow {
    static let windowSize = NSSize(width: 80, height: 96)
    static let originKey = "FizzyWindowOrigin"

    public let fizzyView = FizzyView()
    public var onPetClicked: (() -> Void)?
    public var onPetHoverEnter: (() -> Void)?
    public var onPetHoverExit: (() -> Void)?
    public var onSettingsClicked: (() -> Void)?
    private var mouseDownOrigin: NSPoint?
    private var hoverTrackingArea: NSTrackingArea?

    public static func savedOrigin() -> NSPoint? {
        guard let data = UserDefaults.standard.data(forKey: originKey),
              let coords = try? JSONDecoder().decode([CGFloat].self, from: data),
              coords.count == 2 else { return nil }
        let point = NSPoint(x: coords[0], y: coords[1])
        let windowRect = NSRect(origin: point, size: windowSize)
        let onScreen = NSScreen.screens.contains { $0.visibleFrame.intersects(windowRect) }
        return onScreen ? point : nil
    }

    public func saveOrigin() {
        let data = try? JSONEncoder().encode([frame.origin.x, frame.origin.y])
        UserDefaults.standard.set(data, forKey: FizzyWindow.originKey)
    }

    public init() {
        let size = FizzyWindow.windowSize
        let screenFrame = NSScreen.main?.visibleFrame ?? .zero
        let defaultOrigin = NSPoint(
            x: screenFrame.maxX - size.width - 48,
            y: screenFrame.minY + 48
        )
        let origin = FizzyWindow.savedOrigin() ?? defaultOrigin
        super.init(
            contentRect: NSRect(origin: origin, size: size),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = .clear
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .stationary]
        isMovableByWindowBackground = true
        hasShadow = false

        fizzyView.frame = NSRect(origin: .zero, size: size)
        contentView = fizzyView

        updatePetTrackingArea()
    }

    private func updatePetTrackingArea() {
        if let existing = hoverTrackingArea {
            contentView?.removeTrackingArea(existing)
        }
        let area = NSTrackingArea(
            rect: fizzyView.bounds,
            options: [.mouseEnteredAndExited, .activeAlways],
            owner: self
        )
        contentView?.addTrackingArea(area)
        hoverTrackingArea = area
    }

    public override func mouseEntered(with event: NSEvent) {
        onPetHoverEnter?()
    }

    public override func mouseExited(with event: NSEvent) {
        onPetHoverExit?()
    }

    public override func mouseDown(with event: NSEvent) {
        mouseDownOrigin = frame.origin
        super.mouseDown(with: event)
    }

    public override func mouseUp(with event: NSEvent) {
        if let origin = mouseDownOrigin {
            let moved = abs(frame.origin.x - origin.x) + abs(frame.origin.y - origin.y)
            if moved < 3 {
                onPetClicked?()
            }
        }
        mouseDownOrigin = nil
    }

    public func updateFizzyState(unreadCount: Int) {
        fizzyView.state = unreadCount > 0 ? .active(unreadCount: unreadCount) : .idle
    }

    public func contextMenu() -> NSMenu {
        let menu = NSMenu()
        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(settingsClicked), keyEquivalent: "")
        settingsItem.target = self
        menu.addItem(settingsItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "")
        return menu
    }

    @objc private func settingsClicked() {
        onSettingsClicked?()
    }

    public override func rightMouseDown(with event: NSEvent) {
        let menu = contextMenu()
        let location = event.locationInWindow
        menu.popUp(positioning: nil, at: location, in: contentView)
    }
}
