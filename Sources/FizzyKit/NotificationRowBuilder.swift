import AppKit

enum NotificationRowBuilder {
    static let claudeCodeIcon: NSImage? = {
        guard let url = Bundle.module.url(forResource: "ClaudeCodeIcon", withExtension: "png") else { return nil }
        guard let img = NSImage(contentsOf: url) else { return nil }
        img.size = NSSize(width: 24, height: 24)
        return img
    }()

    static func displayTitle(for type: String) -> String {
        switch type {
        case "idle_prompt": return "Claude is idle"
        default: return type.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    static func relativeTime(from date: Date) -> String {
        let seconds = Int(-date.timeIntervalSinceNow)
        if seconds < 60 { return "now" }
        if seconds < 3600 { return "\(seconds / 60)m" }
        if seconds < 86400 { return "\(seconds / 3600)h" }
        return "\(seconds / 86400)d"
    }

    struct Layout {
        let rowHeight: CGFloat
        let titleY: CGFloat
        let messageY: CGFloat
        let messageH: CGFloat
        let projectY: CGFloat
        let contentMidY: CGFloat

        static let topPad: CGFloat = 8
        static let titleH: CGFloat = 18
        static let gap1: CGFloat = 2
        static let gap2: CGFloat = 6
        static let projectH: CGFloat = 14
        static let bottomPad: CGFloat = 6

        init(message: String, width: CGFloat) {
            let messageFont = NSFont.systemFont(ofSize: 12)
            let lineH = ceil(messageFont.ascender - messageFont.descender + messageFont.leading)
            let attrs: [NSAttributedString.Key: Any] = [.font: messageFont]
            let textRect = (message as NSString).boundingRect(
                with: NSSize(width: width, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: attrs
            )
            messageH = min(ceil(textRect.height), lineH * 2)

            let h = Self.topPad + Self.titleH + Self.gap1 + messageH + Self.gap2 + Self.projectH + Self.bottomPad + 1
            rowHeight = h
            titleY = h - Self.topPad - Self.titleH
            messageY = titleY - Self.gap1 - messageH
            projectY = messageY - Self.gap2 - Self.projectH
            contentMidY = (h - Self.topPad + messageY) / 2
        }
    }

    static func buildContent(
        item: NotificationItem,
        in container: NSView,
        layout: Layout,
        messageWidth: CGFloat,
        isRead: Bool
    ) {
        let unreadAlpha: CGFloat = isRead ? 0.35 : 1.0

        // Icon
        let iconView = NSImageView(frame: NSRect(x: 12, y: layout.contentMidY - 10, width: 20, height: 20))
        iconView.image = claudeCodeIcon
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.alphaValue = isRead ? 0.30 : 0.85
        container.addSubview(iconView)

        // Title — use payload title if present, fall back to derived title
        let titleText = item.notification.title ?? displayTitle(for: item.notification.notificationType)
        let titleLabel = NSTextField(labelWithString: titleText)
        titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        titleLabel.textColor = .white.withAlphaComponent(0.90 * unreadAlpha)
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.frame = NSRect(x: 42, y: layout.titleY, width: messageWidth - 40, height: Layout.titleH)
        container.addSubview(titleLabel)

        // Time
        let timeLabel = NSTextField(labelWithString: relativeTime(from: item.arrivedAt))
        timeLabel.font = .systemFont(ofSize: 10)
        timeLabel.textColor = .white.withAlphaComponent(0.30)
        timeLabel.alignment = .right
        let timeX = 42 + messageWidth - 40
        timeLabel.frame = NSRect(x: timeX, y: layout.titleY + 2, width: 40, height: 14)
        container.addSubview(timeLabel)

        // Message
        let message = NSTextField(wrappingLabelWithString: item.notification.message)
        message.font = .systemFont(ofSize: 12)
        message.textColor = .white.withAlphaComponent(0.60 * unreadAlpha)
        message.isEditable = false
        message.isBordered = false
        message.drawsBackground = false
        message.maximumNumberOfLines = 2
        message.cell?.truncatesLastVisibleLine = true
        message.wantsLayer = true
        message.layer?.masksToBounds = true
        message.frame = NSRect(x: 42, y: layout.messageY, width: messageWidth, height: layout.messageH)
        container.addSubview(message)

        // Project name · notification_type
        let projectName = URL(fileURLWithPath: item.notification.cwd).lastPathComponent
        let projectLabel = NSTextField(labelWithString: "\(projectName) \u{00B7} \(displayTitle(for: item.notification.notificationType))")
        projectLabel.font = .systemFont(ofSize: 10)
        projectLabel.textColor = .white.withAlphaComponent(0.25)
        projectLabel.frame = NSRect(x: 42, y: layout.projectY, width: messageWidth, height: Layout.projectH)
        container.addSubview(projectLabel)

        // Divider
        let div = NSView(frame: NSRect(x: 42, y: 0, width: container.bounds.width - 42, height: 1))
        div.wantsLayer = true
        div.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.08).cgColor
        container.addSubview(div)
    }
}
