import AppKit

public final class NotificationListPanel: NSPanel {
    private let scrollView = NSScrollView()
    private let stackView = NSStackView()
    private let subtitleLabel = NSTextField(labelWithString: "")
    private var store: NotificationStore?
    private var onUpdate: (() -> Void)?
    private var onOpen: ((NotificationItem) -> Void)?
    public var onClose: (() -> Void)?
    private var detailPanel: NSPanel?
    private var hoveredItemId: UUID?
    private var dismissTimer: Timer?
    private var isMouseInDetail = false

    static let panelWidth: CGFloat = 320
    static let panelHeight: CGFloat = 400

    public init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: Self.panelWidth, height: Self.panelHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = .clear
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .stationary]
        hasShadow = true
        isMovableByWindowBackground = true
        appearance = NSAppearance(named: .darkAqua)

        let w = Self.panelWidth
        let h = Self.panelHeight
        let container = NSView(frame: NSRect(x: 0, y: 0, width: w, height: h))

        let bg = NSVisualEffectView(frame: container.bounds)
        bg.material = .hudWindow
        bg.state = .active
        bg.wantsLayer = true
        bg.layer?.cornerRadius = 12
        bg.layer?.masksToBounds = true
        bg.autoresizingMask = [.width, .height]
        container.addSubview(bg)

        // --- Header ---
        let headerBottom = h - 56

        let title = NSTextField(labelWithString: "Notifications")
        title.font = .boldSystemFont(ofSize: 14)
        title.textColor = .white.withAlphaComponent(0.90)
        title.frame = NSRect(x: 16, y: h - 28, width: 160, height: 20)
        container.addSubview(title)

        subtitleLabel.font = .systemFont(ofSize: 11)
        subtitleLabel.textColor = .white.withAlphaComponent(0.35)
        subtitleLabel.frame = NSRect(x: 16, y: h - 46, width: 160, height: 16)
        container.addSubview(subtitleLabel)

        let closeBtn = NSButton(title: "\u{00D7}", target: self, action: #selector(closeClicked))
        closeBtn.isBordered = false
        closeBtn.font = .systemFont(ofSize: 18, weight: .light)
        closeBtn.contentTintColor = .white.withAlphaComponent(0.50)
        closeBtn.focusRingType = .none
        closeBtn.frame = NSRect(x: w - 34, y: h - 36, width: 24, height: 24)
        container.addSubview(closeBtn)

        let markAllBtn = NSButton(title: "Mark all read", target: self, action: #selector(markAllReadClicked))
        markAllBtn.isBordered = false
        markAllBtn.font = .systemFont(ofSize: 11)
        markAllBtn.contentTintColor = .white.withAlphaComponent(0.60)
        markAllBtn.wantsLayer = true
        markAllBtn.layer?.borderColor = NSColor.white.withAlphaComponent(0.20).cgColor
        markAllBtn.layer?.borderWidth = 1
        markAllBtn.layer?.cornerRadius = 11
        markAllBtn.focusRingType = .none
        markAllBtn.frame = NSRect(x: w - 138, y: h - 38, width: 96, height: 22)
        container.addSubview(markAllBtn)

        addDivider(at: headerBottom, width: w, in: container)

        // --- Scroll area ---
        let footerTop: CGFloat = 28
        scrollView.frame = NSRect(x: 0, y: footerTop, width: w, height: headerBottom - footerTop)
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.scrollerStyle = .overlay
        scrollView.autohidesScrollers = true
        scrollView.documentView = stackView

        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 0
        container.addSubview(scrollView)

        // --- Footer ---
        addDivider(at: footerTop, width: w, in: container)

        let fizzyLabel = NSTextField(labelWithString: "FIZZY")
        fizzyLabel.font = .monospacedSystemFont(ofSize: 9, weight: .medium)
        fizzyLabel.textColor = .white.withAlphaComponent(0.25)
        fizzyLabel.frame = NSRect(x: 16, y: 7, width: 40, height: 14)
        container.addSubview(fizzyLabel)

        let escLabel = NSTextField(labelWithString: "esc to close")
        escLabel.font = .monospacedSystemFont(ofSize: 9, weight: .regular)
        escLabel.textColor = .white.withAlphaComponent(0.20)
        escLabel.alignment = .right
        escLabel.frame = NSRect(x: w - 100, y: 7, width: 84, height: 14)
        container.addSubview(escLabel)

        contentView = container
    }

    public override var canBecomeKey: Bool { true }

    public override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            if detailPanel != nil { dismissDetail() }
            else { onClose?() }
        } else {
            super.keyDown(with: event)
        }
    }

    public func show(
        store: NotificationStore,
        relativeTo petWindow: NSWindow,
        onUpdate: @escaping () -> Void,
        onOpen: @escaping (NotificationItem) -> Void
    ) {
        self.store = store
        self.onUpdate = onUpdate
        self.onOpen = onOpen

        reposition(relativeTo: petWindow)
        reload()
        makeKeyAndOrderFront(nil)
    }

    private func reposition(relativeTo petWindow: NSWindow) {
        let petFrame = petWindow.frame
        let screenFrame = petWindow.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero
        let direction = ToastManager.bestDirection(petFrame: petFrame, screenFrame: screenFrame)
        let origin = ToastManager.toastOrigin(
            petFrame: petFrame, screenFrame: screenFrame,
            toastSize: frame.size, index: 0, direction: direction
        )
        setFrameOrigin(origin)
    }

    public func reload() {
        dismissDetail()
        guard let store else { return }
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        subtitleLabel.stringValue = "\(store.unreadCount) unread \u{00B7} \(store.items.count) total"

        if store.items.isEmpty {
            let empty = NSTextField(labelWithString: "No notifications")
            empty.translatesAutoresizingMaskIntoConstraints = false
            empty.font = .systemFont(ofSize: 12)
            empty.textColor = .white.withAlphaComponent(0.30)
            empty.alignment = .center
            empty.widthAnchor.constraint(equalToConstant: Self.panelWidth).isActive = true
            empty.heightAnchor.constraint(equalToConstant: 40).isActive = true
            stackView.addArrangedSubview(empty)
        } else {
            for item in store.items {
                stackView.addArrangedSubview(makeRow(for: item))
            }
        }

        stackView.layoutSubtreeIfNeeded()
        let w = scrollView.frame.width
        let h = max(stackView.fittingSize.height, scrollView.frame.height)
        stackView.setFrameSize(NSSize(width: w, height: h))
    }

    // MARK: - Row

    private func makeRow(for item: NotificationItem) -> NSView {
        let w = Self.panelWidth
        let messageWidth: CGFloat = 202
        let layout = NotificationRowBuilder.Layout(message: item.notification.message, width: messageWidth)

        let row = HoverRow(frame: NSRect(x: 0, y: 0, width: w, height: layout.rowHeight))
        row.translatesAutoresizingMaskIntoConstraints = false
        row.widthAnchor.constraint(equalToConstant: w).isActive = true
        row.heightAnchor.constraint(equalToConstant: layout.rowHeight).isActive = true
        row.itemId = item.id
        row.onHoverEnter = { [weak self] id in self?.handleHoverEnter(id) }
        row.onHoverExit = { [weak self] id in self?.handleHoverExit(id) }

        NotificationRowBuilder.buildContent(
            item: item, in: row, layout: layout,
            messageWidth: messageWidth, isRead: item.isRead
        )

        // Open button — top-aligned with title
        let openBtnW: CGFloat = 50
        let openBtnH: CGFloat = 24
        let openBtn = ActionButton(
            title: "Open", uuid: item.id,
            action: { [weak self] id in self?.handleOpen(id) }
        )
        openBtn.wantsLayer = true
        openBtn.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.12).cgColor
        openBtn.layer?.cornerRadius = 6
        openBtn.font = .systemFont(ofSize: 11, weight: .medium)
        openBtn.contentTintColor = .white.withAlphaComponent(0.85)
        let openX = w - 16 - openBtnW
        openBtn.frame = NSRect(x: openX, y: layout.titleY - 3, width: openBtnW, height: openBtnH)
        row.addSubview(openBtn)

        // Dismiss × — right-aligned with Open, just below
        let dismissBtn = ActionButton(
            title: "\u{00D7}", uuid: item.id,
            action: { [weak self] id in self?.handleDismiss(id) }
        )
        dismissBtn.font = .systemFont(ofSize: 16, weight: .light)
        dismissBtn.contentTintColor = .white.withAlphaComponent(0.30)
        dismissBtn.frame = NSRect(x: openX + openBtnW - 24, y: layout.titleY - 3 - 22, width: 24, height: 22)
        row.addSubview(dismissBtn)

        return row
    }

    // MARK: - Hover detail

    private func handleHoverEnter(_ itemId: UUID) {
        dismissTimer?.invalidate()
        dismissTimer = nil
        hoveredItemId = itemId
        isMouseInDetail = false
        guard let item = store?.items.first(where: { $0.id == itemId }) else { return }
        showDetail(for: item)
    }

    private func handleHoverExit(_ itemId: UUID) {
        guard hoveredItemId == itemId else { return }
        scheduleDismiss()
    }

    private func detailPanelMouseEntered() {
        dismissTimer?.invalidate()
        dismissTimer = nil
        isMouseInDetail = true
    }

    private func detailPanelMouseExited() {
        isMouseInDetail = false
        scheduleDismiss()
    }

    private func scheduleDismiss() {
        dismissTimer?.invalidate()
        dismissTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: false) { [weak self] _ in
            guard let self, !self.isMouseInDetail else { return }
            self.hoveredItemId = nil
            self.dismissDetail()
        }
    }

    private func showDetail(for item: NotificationItem) {
        dismissDetail()

        let dw: CGFloat = 300
        let pad: CGFloat = 14
        let contentW = dw - pad * 2
        let messageFont = NSFont.systemFont(ofSize: 12)
        let monoFont = NSFont.monospacedSystemFont(ofSize: 10, weight: .regular)

        let n = item.notification
        let titleText = n.title ?? NotificationRowBuilder.displayTitle(for: n.notificationType)
        let transcript = TranscriptReader.lastAssistantMessage(at: n.transcriptPath)

        // Measure variable-height text blocks
        let msgH = Self.measureText(n.message, font: messageFont, width: contentW)
        let maxTranscriptVisible: CGFloat = 200
        var transcriptH: CGFloat = 0
        if let transcript {
            transcriptH = Self.measureText(transcript, font: monoFont, width: contentW)
        }
        let transcriptVisibleH = min(transcriptH, maxTranscriptVisible)

        // Height: header(30) + div(1) + msgPad(8) + msg + pad(8) + div(1) + metaPad(6)
        //       + 3 rows(14*3) + 2 gaps(3*2) + pad(6) + [transcript section] + bottom(10)
        var dh: CGFloat = 30 + 1 + 8 + msgH + 8 + 1 + 6 + 14 * 3 + 3 * 2 + 6 + 10
        if transcript != nil {
            dh += 1 + 6 + 14 + 3 + transcriptVisibleH + 4
        }
        dh = min(max(dh, 100), 600)

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: dw, height: dh),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .floating
        panel.appearance = NSAppearance(named: .darkAqua)
        panel.hasShadow = true

        let container = HoverDetailView(frame: NSRect(x: 0, y: 0, width: dw, height: dh))
        container.onEnter = { [weak self] in self?.detailPanelMouseEntered() }
        container.onExit = { [weak self] in self?.detailPanelMouseExited() }

        let bg = NSVisualEffectView(frame: container.bounds)
        bg.material = .hudWindow
        bg.state = .active
        bg.wantsLayer = true
        bg.layer?.cornerRadius = 10
        bg.layer?.masksToBounds = true
        bg.autoresizingMask = [.width, .height]
        container.addSubview(bg)

        // Cursor tracks current Y from top
        var y = dh

        // --- Header: icon + title ---
        y -= 30
        let iconView = NSImageView(frame: NSRect(x: pad, y: y + 8, width: 14, height: 14))
        iconView.image = NotificationRowBuilder.claudeCodeIcon
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.alphaValue = 0.85
        container.addSubview(iconView)

        let titleField = NSTextField(labelWithString: titleText)
        titleField.font = .systemFont(ofSize: 13, weight: .semibold)
        titleField.textColor = .white.withAlphaComponent(0.90)
        titleField.lineBreakMode = .byTruncatingTail
        titleField.frame = NSRect(x: pad + 20, y: y + 6, width: contentW - 20, height: 18)
        container.addSubview(titleField)

        // --- Divider ---
        y -= 1
        addDetailDivider(at: y, width: dw, in: container)

        // --- Message ---
        y -= 8 + msgH
        let message = NSTextField(wrappingLabelWithString: n.message)
        message.font = messageFont
        message.textColor = .white.withAlphaComponent(0.70)
        message.isEditable = false
        message.isBordered = false
        message.drawsBackground = false
        message.maximumNumberOfLines = 0
        message.frame = NSRect(x: pad, y: y, width: contentW, height: msgH)
        container.addSubview(message)

        // --- Divider ---
        y -= 8 + 1
        addDetailDivider(at: y, width: dw, in: container)

        // --- Metadata rows ---
        y -= 6
        let metaRows: [(String, String)] = [
            ("Type", n.notificationType),
            ("Session", String(n.sessionId.prefix(12))),
            ("CWD", n.cwd),
        ]
        for (label, value) in metaRows {
            y -= 14
            addMetaRow(label: label, value: value, at: y, pad: pad, contentW: contentW,
                       font: monoFont, in: container)
            y -= 3
        }
        y -= 3

        // --- Transcript context ---
        if let transcript {
            addDetailDivider(at: y, width: dw, in: container)
            y -= 1 + 6

            y -= 14
            let contextLabel = NSTextField(labelWithString: "Last message:")
            contextLabel.font = .systemFont(ofSize: 10, weight: .medium)
            contextLabel.textColor = .white.withAlphaComponent(0.40)
            contextLabel.frame = NSRect(x: pad, y: y, width: contentW, height: 14)
            container.addSubview(contextLabel)

            y -= 3 + transcriptVisibleH
            let contextField = NSTextField(wrappingLabelWithString: transcript)
            contextField.font = monoFont
            contextField.textColor = .white.withAlphaComponent(0.50)
            contextField.isEditable = false
            contextField.isSelectable = true
            contextField.isBordered = false
            contextField.drawsBackground = false
            contextField.maximumNumberOfLines = 0
            contextField.frame = NSRect(x: 0, y: 0, width: contentW, height: transcriptH)

            let scrollView = NSScrollView(frame: NSRect(x: pad, y: y, width: contentW, height: transcriptVisibleH))
            scrollView.drawsBackground = false
            scrollView.hasVerticalScroller = true
            scrollView.scrollerStyle = .overlay
            scrollView.autohidesScrollers = true
            scrollView.documentView = contextField
            container.addSubview(scrollView)
        }

        panel.contentView = container

        // Position to the side with more screen space
        let listFrame = self.frame
        let screenFrame = self.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero
        let spaceLeft = listFrame.minX - screenFrame.minX
        let spaceRight = screenFrame.maxX - listFrame.maxX
        let gap: CGFloat = 6

        let px: CGFloat
        if spaceRight >= dw + gap {
            px = listFrame.maxX + gap
        } else if spaceLeft >= dw + gap {
            px = listFrame.minX - dw - gap
        } else {
            px = spaceRight >= spaceLeft ? listFrame.maxX + gap : listFrame.minX - dw - gap
        }
        let py = max(screenFrame.minY, min(listFrame.midY - dh / 2, screenFrame.maxY - dh))
        panel.setFrameOrigin(NSPoint(x: px, y: py))
        panel.orderFront(nil)
        detailPanel = panel
    }

    private func addMetaRow(
        label: String, value: String, at y: CGFloat, pad: CGFloat,
        contentW: CGFloat, font: NSFont, in container: NSView
    ) {
        let labelW: CGFloat = 56
        let lbl = NSTextField(labelWithString: label)
        lbl.font = .systemFont(ofSize: 10, weight: .medium)
        lbl.textColor = .white.withAlphaComponent(0.35)
        lbl.frame = NSRect(x: pad, y: y, width: labelW, height: 14)
        container.addSubview(lbl)

        let val = NSTextField(labelWithString: value)
        val.font = font
        val.textColor = .white.withAlphaComponent(0.55)
        val.lineBreakMode = .byTruncatingMiddle
        val.frame = NSRect(x: pad + labelW, y: y, width: contentW - labelW, height: 14)
        container.addSubview(val)
    }

    private func addDetailDivider(at y: CGFloat, width: CGFloat, in container: NSView) {
        let div = NSView(frame: NSRect(x: 14, y: y, width: width - 28, height: 1))
        div.wantsLayer = true
        div.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.08).cgColor
        container.addSubview(div)
    }

    private static func measureText(_ text: String, font: NSFont, width: CGFloat) -> CGFloat {
        let attrs: [NSAttributedString.Key: Any] = [.font: font]
        let rect = (text as NSString).boundingRect(
            with: NSSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attrs
        )
        return ceil(rect.height)
    }

    private func dismissDetail() {
        dismissTimer?.invalidate()
        dismissTimer = nil
        isMouseInDetail = false
        detailPanel?.orderOut(nil)
        detailPanel = nil
    }

    // MARK: - Actions

    @objc private func closeClicked() {
        onClose?()
    }

    private func handleOpen(_ itemId: UUID) {
        guard let item = store?.items.first(where: { $0.id == itemId }) else { return }
        onOpen?(item)
        store?.dismiss(id: itemId)
        reload()
        onUpdate?()
    }

    private func handleDismiss(_ itemId: UUID) {
        store?.dismiss(id: itemId)
        reload()
        onUpdate?()
    }

    @objc private func markAllReadClicked() {
        store?.markAllRead()
        reload()
        onUpdate?()
    }

    // MARK: - Helpers

    private func addDivider(at y: CGFloat, width: CGFloat, in parent: NSView) {
        let view = NSView(frame: NSRect(x: 0, y: y, width: width, height: 1))
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.08).cgColor
        parent.addSubview(view)
    }

    static func displayTitle(for type: String) -> String {
        NotificationRowBuilder.displayTitle(for: type)
    }

    static func relativeTime(from date: Date) -> String {
        NotificationRowBuilder.relativeTime(from: date)
    }
}

// MARK: - Hover-tracking detail container

private final class HoverDetailView: NSView {
    var onEnter: (() -> Void)?
    var onExit: (() -> Void)?
    private var hoverTrackingArea: NSTrackingArea?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = hoverTrackingArea { removeTrackingArea(existing) }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways],
            owner: self
        )
        addTrackingArea(area)
        hoverTrackingArea = area
    }

    override func mouseEntered(with event: NSEvent) { onEnter?() }
    override func mouseExited(with event: NSEvent) { onExit?() }
}

// MARK: - Hover-tracking row

private final class HoverRow: NSView {
    var itemId: UUID?
    var onHoverEnter: ((UUID) -> Void)?
    var onHoverExit: ((UUID) -> Void)?
    private var hoverTrackingArea: NSTrackingArea?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = hoverTrackingArea { removeTrackingArea(existing) }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInKeyWindow],
            owner: self
        )
        addTrackingArea(area)
        hoverTrackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        guard let id = itemId else { return }
        onHoverEnter?(id)
    }

    override func mouseExited(with event: NSEvent) {
        guard let id = itemId else { return }
        onHoverExit?(id)
    }
}

// MARK: - Self-contained action button

private final class ActionButton: NSButton {
    private let uuid: UUID
    private let handler: (UUID) -> Void

    init(title: String, uuid: UUID, action handler: @escaping (UUID) -> Void) {
        self.uuid = uuid
        self.handler = handler
        super.init(frame: .zero)
        self.title = title
        self.isBordered = false
        self.focusRingType = .none
        self.target = self
        self.action = #selector(clicked)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    @objc private func clicked() {
        handler(uuid)
    }
}
