import AppKit

public final class FizzyWindow: NSWindow {
    public let fizzyView = FizzyView()
    public var onPetClicked: (() -> Void)?
    public var onPetHoverEnter: (() -> Void)?
    public var onPetHoverExit: (() -> Void)?
    private var mouseDownOrigin: NSPoint?
    private var hoverTrackingArea: NSTrackingArea?

    public init() {
        let size = NSSize(width: 80, height: 96)
        let screenFrame = NSScreen.main?.visibleFrame ?? .zero
        let origin = NSPoint(
            x: screenFrame.maxX - size.width - 48,
            y: screenFrame.minY + 48
        )
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
}
