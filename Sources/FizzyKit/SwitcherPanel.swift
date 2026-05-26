import AppKit

public final class SwitcherPanel: NSPanel {
    private static let cardSize: CGFloat = 64
    private static let cardSpacing: CGFloat = 12
    private static let padding: CGFloat = 20
    private static let labelHeight: CGFloat = 20
    private static let previewHeight: CGFloat = 24
    private static let maxVisibleCards = 8

    private let items: [NotificationItem]
    public private(set) var selectedIndex: Int
    private var cardViews: [NSView] = []
    private var borderLayers: [CALayer] = []
    private var nameLabels: [NSTextField] = []
    private let previewLabel: NSTextField = {
        let label = NSTextField(labelWithString: "")
        label.font = .systemFont(ofSize: 12)
        label.textColor = .secondaryLabelColor
        label.alignment = .center
        label.lineBreakMode = .byTruncatingTail
        return label
    }()

    public var currentPreviewMessage: String { previewLabel.stringValue }

    public init(items: [NotificationItem], selectedIndex: Int) {
        self.items = items
        self.selectedIndex = selectedIndex

        let visibleCount = min(items.count, Self.maxVisibleCards)
        let cardsWidth = CGFloat(visibleCount) * Self.cardSize + CGFloat(max(0, visibleCount - 1)) * Self.cardSpacing
        let panelWidth = Self.padding * 2 + cardsWidth
        let panelHeight = Self.padding + Self.cardSize + Self.labelHeight + Self.previewHeight + Self.padding

        let screen = NSScreen.main ?? NSScreen.screens[0]
        let origin = NSPoint(
            x: screen.frame.midX - panelWidth / 2,
            y: screen.frame.midY - panelHeight / 2
        )

        super.init(
            contentRect: NSRect(origin: origin, size: NSSize(width: panelWidth, height: panelHeight)),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = .clear
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .stationary]

        setupUI(visibleCount: visibleCount, panelWidth: panelWidth, panelHeight: panelHeight)
        updateSelection(index: selectedIndex)
    }

    private func setupUI(visibleCount: Int, panelWidth: CGFloat, panelHeight: CGFloat) {
        let bg = NSVisualEffectView(frame: NSRect(origin: .zero, size: NSSize(width: panelWidth, height: panelHeight)))
        bg.material = .hudWindow
        bg.state = .active
        bg.wantsLayer = true
        bg.layer?.cornerRadius = 16
        bg.layer?.masksToBounds = true
        contentView = bg

        let cardsWidth = CGFloat(visibleCount) * Self.cardSize + CGFloat(max(0, visibleCount - 1)) * Self.cardSpacing
        var x = (panelWidth - cardsWidth) / 2

        for i in 0..<visibleCount {
            let item = items[i]
            let cardY = panelHeight - Self.padding - Self.cardSize

            let card = NSView(frame: NSRect(x: x, y: cardY, width: Self.cardSize, height: Self.cardSize))
            card.wantsLayer = true
            card.layer?.cornerRadius = 12
            card.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.3).cgColor

            let border = CALayer()
            border.frame = card.bounds
            border.cornerRadius = 12
            border.borderWidth = 0
            card.layer?.addSublayer(border)
            borderLayers.append(border)

            let initial = Self.projectName(for: item).prefix(1).uppercased()
            let letterLabel = NSTextField(labelWithString: initial)
            letterLabel.font = .systemFont(ofSize: 24, weight: .medium)
            letterLabel.textColor = .white
            letterLabel.alignment = .center
            letterLabel.frame = card.bounds
            card.addSubview(letterLabel)

            bg.addSubview(card)
            cardViews.append(card)

            let nameLabel = NSTextField(labelWithString: Self.projectName(for: item))
            nameLabel.font = .systemFont(ofSize: 10)
            nameLabel.textColor = .labelColor
            nameLabel.alignment = .center
            nameLabel.lineBreakMode = .byTruncatingTail
            nameLabel.frame = NSRect(x: x - 4, y: cardY - Self.labelHeight, width: Self.cardSize + 8, height: Self.labelHeight)
            bg.addSubview(nameLabel)
            nameLabels.append(nameLabel)

            x += Self.cardSize + Self.cardSpacing
        }

        previewLabel.frame = NSRect(x: Self.padding, y: Self.padding / 2, width: panelWidth - Self.padding * 2, height: Self.previewHeight)
        bg.addSubview(previewLabel)
    }

    public func updateSelection(index: Int) {
        if selectedIndex < borderLayers.count {
            borderLayers[selectedIndex].borderWidth = 0
            borderLayers[selectedIndex].borderColor = nil
        }
        if selectedIndex < nameLabels.count {
            nameLabels[selectedIndex].textColor = .labelColor
        }

        selectedIndex = index

        if selectedIndex < borderLayers.count {
            borderLayers[selectedIndex].borderColor = NSColor.cyan.cgColor
            borderLayers[selectedIndex].borderWidth = 2
        }
        if selectedIndex < nameLabels.count {
            nameLabels[selectedIndex].textColor = .white
        }
        if selectedIndex < items.count {
            previewLabel.stringValue = items[selectedIndex].notification.message
        }
    }

    public func show() { orderFront(nil) }
    public func hide() { orderOut(nil) }

    public static func projectName(for item: NotificationItem) -> String {
        let url = URL(fileURLWithPath: item.notification.cwd)
        let name = url.lastPathComponent
        return name.isEmpty ? "/" : name
    }
}
