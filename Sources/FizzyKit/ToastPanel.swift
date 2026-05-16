import AppKit

public final class ToastPanel: NSPanel {
    public init(item: NotificationItem) {
        let w: CGFloat = 280
        let messageWidth: CGFloat = w - 42 - 10
        let layout = NotificationRowBuilder.Layout(message: item.notification.message, width: messageWidth)
        let h = layout.rowHeight

        super.init(
            contentRect: NSRect(x: 0, y: 0, width: w, height: h),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = .clear
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .stationary]
        hasShadow = true
        appearance = NSAppearance(named: .darkAqua)

        let container = NSView(frame: NSRect(x: 0, y: 0, width: w, height: h))

        let background = NSVisualEffectView(frame: container.bounds)
        background.material = .hudWindow
        background.state = .active
        background.wantsLayer = true
        background.layer?.cornerRadius = 10
        background.layer?.masksToBounds = true
        background.autoresizingMask = [.width, .height]
        container.addSubview(background)

        NotificationRowBuilder.buildContent(
            item: item, in: container, layout: layout,
            messageWidth: messageWidth, isRead: false
        )

        contentView = container
    }
}
