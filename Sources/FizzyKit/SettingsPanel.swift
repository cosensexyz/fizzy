// Sources/FizzyKit/SettingsPanel.swift
import AppKit
import CoreGraphics

public final class SettingsPanel: NSPanel {
    public enum PermissionStatus: String, Equatable {
        case granted, denied, notAsked, notRunning
    }

    // MARK: - State

    private var config = CycleConfig.load()
    private var modifierToggles: [UInt64: NSButton] = [:]
    private var displayModeCards: [Int: NSView] = [:]
    private var displayModeRadioDots: [Int: NSView] = [:]
    private var dynamicBindingBadgeStacks: [NSStackView] = []
    private var dynamicBindingRows: [NSView] = []
    private var permissionCardStack: NSStackView!

    // MARK: - Init

    public init() {
        let size = NSSize(width: 520, height: 700)
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let origin = NSPoint(
            x: screen.frame.midX - size.width / 2,
            y: screen.frame.midY - size.height / 2
        )

        super.init(
            contentRect: NSRect(origin: origin, size: size),
            styleMask: [.titled, .closable, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        title = "Settings"
        isOpaque = false
        backgroundColor = .clear
        level = .floating
        titlebarAppearsTransparent = true
        titleVisibility = .hidden

        setupUI()
    }

    // MARK: - UI Setup

    private func setupUI() {
        // Blur + paper background
        let visualEffect = NSVisualEffectView()
        visualEffect.translatesAutoresizingMaskIntoConstraints = false
        visualEffect.blendingMode = .behindWindow
        visualEffect.material = .underWindowBackground
        visualEffect.state = .active
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = 14
        visualEffect.layer?.masksToBounds = true

        let paperOverlay = NSView()
        paperOverlay.translatesAutoresizingMaskIntoConstraints = false
        paperOverlay.wantsLayer = true
        paperOverlay.layer?.backgroundColor = NSColor(red: 248/255, green: 247/255, blue: 244/255, alpha: 0.92).cgColor
        paperOverlay.layer?.cornerRadius = 14

        contentView = NSView()
        contentView!.wantsLayer = true
        contentView!.layer?.cornerRadius = 14
        contentView!.layer?.masksToBounds = true

        contentView!.addSubview(visualEffect)
        contentView!.addSubview(paperOverlay)

        let outerContainer = NSView()
        outerContainer.translatesAutoresizingMaskIntoConstraints = false
        contentView!.addSubview(outerContainer)

        NSLayoutConstraint.activate([
            visualEffect.topAnchor.constraint(equalTo: contentView!.topAnchor),
            visualEffect.leadingAnchor.constraint(equalTo: contentView!.leadingAnchor),
            visualEffect.trailingAnchor.constraint(equalTo: contentView!.trailingAnchor),
            visualEffect.bottomAnchor.constraint(equalTo: contentView!.bottomAnchor),

            paperOverlay.topAnchor.constraint(equalTo: contentView!.topAnchor),
            paperOverlay.leadingAnchor.constraint(equalTo: contentView!.leadingAnchor),
            paperOverlay.trailingAnchor.constraint(equalTo: contentView!.trailingAnchor),
            paperOverlay.bottomAnchor.constraint(equalTo: contentView!.bottomAnchor),

            outerContainer.topAnchor.constraint(equalTo: contentView!.topAnchor),
            outerContainer.leadingAnchor.constraint(equalTo: contentView!.leadingAnchor),
            outerContainer.trailingAnchor.constraint(equalTo: contentView!.trailingAnchor),
            outerContainer.bottomAnchor.constraint(equalTo: contentView!.bottomAnchor),
        ])

        // Scroll view
        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        outerContainer.addSubview(scrollView)

        let contentStack = NSStackView()
        contentStack.orientation = .vertical
        contentStack.alignment = .leading
        contentStack.spacing = 24
        contentStack.edgeInsets = NSEdgeInsets(top: 28, left: 20, bottom: 24, right: 20)
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        let clipView = scrollView.contentView
        scrollView.documentView = contentStack

        // Bottom bar
        let bottomBar = makeBottomBar()
        bottomBar.translatesAutoresizingMaskIntoConstraints = false
        outerContainer.addSubview(bottomBar)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: outerContainer.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: outerContainer.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: outerContainer.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomBar.topAnchor),

            bottomBar.leadingAnchor.constraint(equalTo: outerContainer.leadingAnchor),
            bottomBar.trailingAnchor.constraint(equalTo: outerContainer.trailingAnchor),
            bottomBar.bottomAnchor.constraint(equalTo: outerContainer.bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: clipView.topAnchor),
            contentStack.leadingAnchor.constraint(equalTo: clipView.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: clipView.trailingAnchor),
            contentStack.widthAnchor.constraint(equalTo: clipView.widthAnchor),
        ])

        // Section 1: Cycle Shortcut
        contentStack.addArrangedSubview(makeSectionHeader(
            title: "Cycle shortcut",
            subtitle: "Hold your modifiers, then use arrow keys to switch between Claude Code sessions."
        ))
        contentStack.addArrangedSubview(makeModifierToggleCard())
        contentStack.addArrangedSubview(makeKeyBindingsTable())

        // Section 2: Display Mode
        contentStack.addArrangedSubview(makeSectionHeader(
            title: "Display mode",
            subtitle: "What appears when you trigger the shortcut."
        ))
        contentStack.addArrangedSubview(makeDisplayModeCards())

        // Section 3: Permissions
        contentStack.addArrangedSubview(makePermissionsHeader())
        let permCard = makeCard()
        permCard.translatesAutoresizingMaskIntoConstraints = false
        permissionCardStack = NSStackView()
        permissionCardStack.orientation = .vertical
        permissionCardStack.alignment = .leading
        permissionCardStack.spacing = 0
        permissionCardStack.translatesAutoresizingMaskIntoConstraints = false
        permCard.addSubview(permissionCardStack)
        NSLayoutConstraint.activate([
            permissionCardStack.topAnchor.constraint(equalTo: permCard.topAnchor),
            permissionCardStack.leadingAnchor.constraint(equalTo: permCard.leadingAnchor),
            permissionCardStack.trailingAnchor.constraint(equalTo: permCard.trailingAnchor),
            permissionCardStack.bottomAnchor.constraint(equalTo: permCard.bottomAnchor),
        ])
        contentStack.addArrangedSubview(permCard)

        // Pin all content stack children to full width
        for view in contentStack.arrangedSubviews {
            view.translatesAutoresizingMaskIntoConstraints = false
            view.widthAnchor.constraint(equalTo: contentStack.widthAnchor, constant: -40).isActive = true
        }
    }

    // MARK: - Section Header

    private func makeSectionHeader(title: String, subtitle: String) -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 4

        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 13, weight: .bold)
        titleLabel.textColor = .labelColor

        let subtitleLabel = NSTextField(wrappingLabelWithString: subtitle)
        subtitleLabel.font = .systemFont(ofSize: 11)
        subtitleLabel.textColor = .secondaryLabelColor

        stack.addArrangedSubview(titleLabel)
        stack.addArrangedSubview(subtitleLabel)
        return stack
    }

    // MARK: - Modifier Toggle Card

    private func makeModifierToggleCard() -> NSView {
        let card = makeCard()

        // Horizontal grid: 90px label | toggles fill rest
        let grid = NSStackView()
        grid.orientation = .horizontal
        grid.spacing = 12
        grid.alignment = .centerY
        grid.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(grid)

        NSLayoutConstraint.activate([
            grid.topAnchor.constraint(equalTo: card.topAnchor, constant: 12),
            grid.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            grid.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
            grid.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -12),
        ])

        let label = NSTextField(labelWithString: "MODIFIERS")
        label.font = .systemFont(ofSize: 10, weight: .semibold)
        label.textColor = .secondaryLabelColor
        label.translatesAutoresizingMaskIntoConstraints = false
        label.widthAnchor.constraint(equalToConstant: 90).isActive = true
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)

        let togglesRow = NSStackView()
        togglesRow.orientation = .horizontal
        togglesRow.spacing = 8
        togglesRow.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let modifiers: [(CGEventFlags, String, String)] = [
            (.maskCommand, "⌘", "Cmd"),
            (.maskShift, "⇧", "Shift"),
            (.maskAlternate, "⌥", "Opt"),
            (.maskControl, "⌃", "Ctrl"),
        ]

        for (flag, symbol, name) in modifiers {
            let btn = makeModifierToggleButton(flag: flag, symbol: symbol, name: name)
            modifierToggles[flag.rawValue] = btn
            togglesRow.addArrangedSubview(btn)
        }

        grid.addArrangedSubview(label)
        grid.addArrangedSubview(togglesRow)
        return card
    }

    private func makeModifierToggleButton(flag: CGEventFlags, symbol: String, name: String) -> NSButton {
        let btn = NSButton()
        btn.title = ""
        btn.imagePosition = .noImage
        btn.bezelStyle = .regularSquare
        btn.isBordered = false
        btn.wantsLayer = true
        btn.layer?.cornerRadius = 8
        btn.layer?.borderWidth = 1.5
        btn.tag = Int(flag.rawValue & 0xFFFF)
        btn.target = self
        btn.action = #selector(modifierToggled(_:))

        let isSelected = config.modifierFlags.contains(flag)
        applyModifierButtonStyle(btn, isSelected: isSelected)

        let innerStack = NSStackView()
        innerStack.orientation = .horizontal
        innerStack.spacing = 6
        innerStack.translatesAutoresizingMaskIntoConstraints = false

        let checkbox = NSView()
        checkbox.wantsLayer = true
        checkbox.layer?.cornerRadius = 4
        checkbox.layer?.borderWidth = 1.5
        checkbox.translatesAutoresizingMaskIntoConstraints = false
        checkbox.widthAnchor.constraint(equalToConstant: 13).isActive = true
        checkbox.heightAnchor.constraint(equalToConstant: 13).isActive = true
        applyCheckboxStyle(checkbox, isSelected: isSelected)

        let keycap = makeModifierKeycapBadge(symbol)
        let nameLabel = NSTextField(labelWithString: name)
        nameLabel.font = .systemFont(ofSize: 12)

        innerStack.addArrangedSubview(checkbox)
        innerStack.addArrangedSubview(keycap)
        innerStack.addArrangedSubview(nameLabel)

        btn.addSubview(innerStack)
        NSLayoutConstraint.activate([
            innerStack.leadingAnchor.constraint(equalTo: btn.leadingAnchor, constant: 8),
            innerStack.trailingAnchor.constraint(equalTo: btn.trailingAnchor, constant: -8),
            innerStack.topAnchor.constraint(equalTo: btn.topAnchor, constant: 8),
            innerStack.bottomAnchor.constraint(equalTo: btn.bottomAnchor, constant: -8),
        ])

        return btn
    }

    private func applyModifierButtonStyle(_ btn: NSButton, isSelected: Bool) {
        btn.layer?.borderColor = isSelected
            ? NSColor.systemCyan.cgColor
            : NSColor.black.withAlphaComponent(0.1).cgColor
        btn.layer?.backgroundColor = isSelected
            ? NSColor.systemCyan.withAlphaComponent(0.06).cgColor
            : NSColor.white.withAlphaComponent(0.5).cgColor
        if isSelected {
            btn.layer?.shadowColor = NSColor.systemCyan.cgColor
            btn.layer?.shadowOpacity = 0.3
            btn.layer?.shadowRadius = 4
            btn.layer?.shadowOffset = .zero
        } else {
            btn.layer?.shadowOpacity = 0
        }
    }

    private func applyCheckboxStyle(_ view: NSView, isSelected: Bool) {
        if isSelected {
            view.layer?.backgroundColor = NSColor.systemCyan.cgColor
            view.layer?.borderColor = NSColor.systemCyan.cgColor
            // Add checkmark via sublayer
            view.subviews.forEach { $0.removeFromSuperview() }
            let check = NSTextField(labelWithString: "✓")
            check.font = .boldSystemFont(ofSize: 9)
            check.textColor = .white
            check.alignment = .center
            check.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(check)
            NSLayoutConstraint.activate([
                check.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                check.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            ])
        } else {
            view.layer?.backgroundColor = NSColor.clear.cgColor
            view.layer?.borderColor = NSColor.black.withAlphaComponent(0.2).cgColor
            view.subviews.forEach { $0.removeFromSuperview() }
        }
    }

    // MARK: - Key Bindings Table

    private func makeKeyBindingsTable() -> NSView {
        let card = makeCard()
        let tableStack = NSStackView()
        tableStack.orientation = .vertical
        tableStack.alignment = .leading
        tableStack.spacing = 0
        tableStack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(tableStack)

        NSLayoutConstraint.activate([
            tableStack.topAnchor.constraint(equalTo: card.topAnchor),
            tableStack.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            tableStack.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            tableStack.bottomAnchor.constraint(equalTo: card.bottomAnchor),
        ])

        // Primary rows (Enter cycling) — with cyan tint
        var forwardBadgesStack: NSStackView?
        let forwardRow = makeBindingRow(
            keyBadges: modifierBadges() + [makeKeycapBadge("→")],
            action: "Enter cycling",
            hint: "forward",
            isPrimary: true,
            capturedBadgesStack: &forwardBadgesStack
        )
        var backwardBadgesStack: NSStackView?
        let backwardRow = makeBindingRow(
            keyBadges: modifierBadges() + [makeKeycapBadge("←")],
            action: "Enter cycling",
            hint: "backward",
            isPrimary: true,
            capturedBadgesStack: &backwardBadgesStack
        )
        dynamicBindingRows = [forwardRow, backwardRow]
        dynamicBindingBadgeStacks = [forwardBadgesStack, backwardBadgesStack].compactMap { $0 }
        tableStack.addArrangedSubview(forwardRow)
        tableStack.addArrangedSubview(makeTableDivider())
        tableStack.addArrangedSubview(backwardRow)
        tableStack.addArrangedSubview(makeTableDivider())

        // Fixed rows
        tableStack.addArrangedSubview(makeBindingRow(
            keyBadges: [makeKeycapBadge("→")], action: "Cycle forward", hint: "while cycling"
        ))
        tableStack.addArrangedSubview(makeTableDivider())
        tableStack.addArrangedSubview(makeBindingRow(
            keyBadges: [makeKeycapBadge("←")], action: "Cycle backward", hint: "while cycling"
        ))
        tableStack.addArrangedSubview(makeTableDivider())
        tableStack.addArrangedSubview(makeBindingRow(
            keyBadges: [makeKeycapBadge("↓")], action: "Confirm", hint: "while cycling"
        ))
        tableStack.addArrangedSubview(makeTableDivider())
        tableStack.addArrangedSubview(makeBindingRow(
            keyBadges: [makeKeycapBadge("↑")], action: "Cancel", hint: "while cycling"
        ))
        tableStack.addArrangedSubview(makeTableDivider())
        tableStack.addArrangedSubview(makeReleaseModifiersRow())

        // Pin all rows to full width
        for view in tableStack.arrangedSubviews {
            view.translatesAutoresizingMaskIntoConstraints = false
            view.widthAnchor.constraint(equalTo: tableStack.widthAnchor).isActive = true
        }

        return card
    }

    private func modifierBadges() -> [NSView] {
        let badges = SettingsPanel.modifierSymbols(for: config.modifierFlags).map { makeModifierKeycapBadge($0) }
        let plus = NSTextField(labelWithString: "+")
        plus.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        plus.textColor = .tertiaryLabelColor
        return badges + [plus]
    }

    private func makeBindingRow(
        keyBadges: [NSView],
        action: String,
        hint: String,
        isPrimary: Bool = false,
        capturedBadgesStack: inout NSStackView?
    ) -> NSView {
        let row = NSView()
        row.wantsLayer = true
        if isPrimary {
            row.layer?.backgroundColor = NSColor.systemCyan.withAlphaComponent(0.04).cgColor
        }

        let badgesStack = NSStackView()
        badgesStack.orientation = .horizontal
        badgesStack.spacing = 4
        badgesStack.alignment = .centerY
        badgesStack.translatesAutoresizingMaskIntoConstraints = false
        for badge in keyBadges {
            badgesStack.addArrangedSubview(badge)
        }
        capturedBadgesStack = badgesStack

        let actionLabel = NSTextField(labelWithString: action)
        actionLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        actionLabel.textColor = .labelColor
        actionLabel.translatesAutoresizingMaskIntoConstraints = false
        actionLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let hintLabel = NSTextField(labelWithString: hint)
        hintLabel.font = .systemFont(ofSize: 11)
        hintLabel.textColor = .tertiaryLabelColor
        hintLabel.alignment = .right
        hintLabel.translatesAutoresizingMaskIntoConstraints = false
        hintLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)

        row.addSubview(badgesStack)
        row.addSubview(actionLabel)
        row.addSubview(hintLabel)

        NSLayoutConstraint.activate([
            badgesStack.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 14),
            badgesStack.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            badgesStack.widthAnchor.constraint(equalToConstant: 168),

            actionLabel.leadingAnchor.constraint(equalTo: badgesStack.trailingAnchor, constant: 4),
            actionLabel.centerYAnchor.constraint(equalTo: row.centerYAnchor),

            hintLabel.leadingAnchor.constraint(greaterThanOrEqualTo: actionLabel.trailingAnchor, constant: 8),
            hintLabel.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -14),
            hintLabel.centerYAnchor.constraint(equalTo: row.centerYAnchor),

            row.heightAnchor.constraint(equalToConstant: 36),
        ])

        return row
    }

    private func makeBindingRow(
        keyBadges: [NSView],
        action: String,
        hint: String,
        isPrimary: Bool = false
    ) -> NSView {
        var ignored: NSStackView?
        return makeBindingRow(keyBadges: keyBadges, action: action, hint: hint, isPrimary: isPrimary, capturedBadgesStack: &ignored)
    }

    private func makeReleaseModifiersRow() -> NSView {
        let row = NSView()
        row.wantsLayer = true

        // Dashed badge
        let badge = NSView()
        badge.wantsLayer = true
        badge.layer?.cornerRadius = 6
        badge.layer?.borderWidth = 1
        badge.layer?.borderColor = NSColor.tertiaryLabelColor.cgColor
        badge.layer?.backgroundColor = NSColor.clear.cgColor
        // Dashed border via CAShapeLayer
        let dashLayer = CAShapeLayer()
        dashLayer.fillColor = nil
        dashLayer.strokeColor = NSColor.tertiaryLabelColor.cgColor
        dashLayer.lineWidth = 1
        dashLayer.lineDashPattern = [4, 3]
        badge.layer?.addSublayer(dashLayer)
        badge.translatesAutoresizingMaskIntoConstraints = false

        let badgeStack = NSStackView()
        badgeStack.orientation = .horizontal
        badgeStack.spacing = 4
        badgeStack.translatesAutoresizingMaskIntoConstraints = false

        // Chevron-up icon
        let chevron = NSImageView()
        chevron.image = NSImage(systemSymbolName: "chevron.up", accessibilityDescription: nil)
        chevron.contentTintColor = .secondaryLabelColor
        chevron.translatesAutoresizingMaskIntoConstraints = false
        chevron.widthAnchor.constraint(equalToConstant: 10).isActive = true
        chevron.heightAnchor.constraint(equalToConstant: 10).isActive = true

        let badgeLabel = NSTextField(labelWithString: "Release modifiers")
        badgeLabel.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        badgeLabel.textColor = .secondaryLabelColor
        badgeLabel.translatesAutoresizingMaskIntoConstraints = false

        badgeStack.addArrangedSubview(chevron)
        badgeStack.addArrangedSubview(badgeLabel)
        badge.addSubview(badgeStack)

        NSLayoutConstraint.activate([
            badgeStack.topAnchor.constraint(equalTo: badge.topAnchor, constant: 4),
            badgeStack.bottomAnchor.constraint(equalTo: badge.bottomAnchor, constant: -4),
            badgeStack.leadingAnchor.constraint(equalTo: badge.leadingAnchor, constant: 7),
            badgeStack.trailingAnchor.constraint(equalTo: badge.trailingAnchor, constant: -7),
        ])

        let actionLabel = NSTextField(labelWithString: "Confirm")
        actionLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        actionLabel.textColor = .labelColor
        actionLabel.translatesAutoresizingMaskIntoConstraints = false
        actionLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let hintLabel = NSTextField(labelWithString: "release modifiers")
        hintLabel.font = .systemFont(ofSize: 11)
        hintLabel.textColor = .tertiaryLabelColor
        hintLabel.alignment = .right
        hintLabel.translatesAutoresizingMaskIntoConstraints = false
        hintLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)

        row.addSubview(badge)
        row.addSubview(actionLabel)
        row.addSubview(hintLabel)

        NSLayoutConstraint.activate([
            badge.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 14),
            badge.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            badge.widthAnchor.constraint(lessThanOrEqualToConstant: 168),

            actionLabel.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 14 + 168 + 4),
            actionLabel.centerYAnchor.constraint(equalTo: row.centerYAnchor),

            hintLabel.leadingAnchor.constraint(greaterThanOrEqualTo: actionLabel.trailingAnchor, constant: 8),
            hintLabel.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -14),
            hintLabel.centerYAnchor.constraint(equalTo: row.centerYAnchor),

            row.heightAnchor.constraint(equalToConstant: 36),
        ])

        // Update dashed layer on layout
        badge.postsFrameChangedNotifications = true
        return row
    }

    private func makeTableDivider() -> NSView {
        let line = NSView()
        line.wantsLayer = true
        line.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.06).cgColor
        line.translatesAutoresizingMaskIntoConstraints = false
        line.heightAnchor.constraint(equalToConstant: 0.5).isActive = true
        return line
    }

    // MARK: - Display Mode Cards

    private func makeDisplayModeCards() -> NSView {
        let container = NSStackView()
        container.orientation = .horizontal
        container.spacing = 12
        container.distribution = .fillEqually

        let cards: [(Int, String, String)] = [
            (0, "Switcher + Preview", "Cmd-Tab style row with a live preview of each session."),
            (1, "Preview only", "Just the latest output. Faster, less to read."),
        ]

        for (tag, title, desc) in cards {
            var radioDot: NSView?
            let card = makeDisplayModeCard(tag: tag, title: title, description: desc, radioDot: &radioDot)
            displayModeCards[tag] = card
            displayModeRadioDots[tag] = radioDot
            container.addArrangedSubview(card)
        }

        updateDisplayModeCardBorders()
        return container
    }

    private func makeDisplayModeCard(tag: Int, title: String, description: String, radioDot outDot: inout NSView?) -> NSView {
        let card = makeCard()

        let click = NSClickGestureRecognizer(target: self, action: #selector(displayModeCardClicked(_:)))
        card.addGestureRecognizer(click)

        // Radio dot top-right
        let radioDot = NSView()
        radioDot.wantsLayer = true
        radioDot.layer?.cornerRadius = 6
        radioDot.layer?.borderWidth = 1.5
        radioDot.translatesAutoresizingMaskIntoConstraints = false
        radioDot.widthAnchor.constraint(equalToConstant: 12).isActive = true
        radioDot.heightAnchor.constraint(equalToConstant: 12).isActive = true
        outDot = radioDot
        card.addSubview(radioDot)

        let innerStack = NSStackView()
        innerStack.orientation = .vertical
        innerStack.alignment = .leading
        innerStack.spacing = 8
        innerStack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(innerStack)

        NSLayoutConstraint.activate([
            radioDot.topAnchor.constraint(equalTo: card.topAnchor, constant: 10),
            radioDot.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -10),

            innerStack.topAnchor.constraint(equalTo: card.topAnchor, constant: 12),
            innerStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
            innerStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),
            innerStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -12),
        ])

        let thumbnail = makeThumbnail(tag: tag)
        thumbnail.translatesAutoresizingMaskIntoConstraints = false
        thumbnail.heightAnchor.constraint(equalToConstant: 96).isActive = true
        thumbnail.leadingAnchor.constraint(equalTo: innerStack.leadingAnchor).isActive = true

        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        titleLabel.textColor = .labelColor

        let descLabel = NSTextField(wrappingLabelWithString: description)
        descLabel.font = .systemFont(ofSize: 11)
        descLabel.textColor = .secondaryLabelColor

        innerStack.addArrangedSubview(thumbnail)
        innerStack.addArrangedSubview(titleLabel)
        innerStack.addArrangedSubview(descLabel)

        thumbnail.trailingAnchor.constraint(equalTo: innerStack.trailingAnchor).isActive = true

        return card
    }

    private func updateDisplayModeCardBorders() {
        let selectedTag = config.displayMode == .listAndPreview ? 0 : 1
        for (tag, card) in displayModeCards {
            let isSelected = tag == selectedTag
            card.layer?.borderColor = isSelected
                ? NSColor.systemCyan.cgColor
                : NSColor.black.withAlphaComponent(0.08).cgColor
            card.layer?.borderWidth = isSelected ? 2 : 1
            if isSelected {
                card.layer?.shadowColor = NSColor.systemCyan.cgColor
                card.layer?.shadowOpacity = 0.25
                card.layer?.shadowRadius = 6
                card.layer?.shadowOffset = .zero
            } else {
                card.layer?.shadowOpacity = 0
            }
            if let dot = displayModeRadioDots[tag] {
                dot.layer?.borderColor = isSelected
                    ? NSColor.systemCyan.cgColor
                    : NSColor.black.withAlphaComponent(0.15).cgColor
                dot.layer?.backgroundColor = isSelected
                    ? NSColor.systemCyan.cgColor
                    : NSColor.clear.cgColor
            }
        }
    }

    // MARK: - Permissions

    private func makePermissionsHeader() -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 8

        let textStack = NSStackView()
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 4

        let titleLabel = NSTextField(labelWithString: "Permissions")
        titleLabel.font = .systemFont(ofSize: 13, weight: .bold)
        titleLabel.textColor = .labelColor

        let subtitleLabel = NSTextField(labelWithString: "What macOS lets Fizzy do.")
        subtitleLabel.font = .systemFont(ofSize: 11)
        subtitleLabel.textColor = .secondaryLabelColor

        textStack.addArrangedSubview(titleLabel)
        textStack.addArrangedSubview(subtitleLabel)

        let openBtn = NSButton(title: "Open System Settings ↗", target: self, action: #selector(openSystemSettings))
        openBtn.bezelStyle = .rounded
        openBtn.font = .systemFont(ofSize: 11)
        openBtn.setContentHuggingPriority(.defaultHigh, for: .horizontal)

        row.addArrangedSubview(textStack)
        row.addArrangedSubview(NSView()) // spacer
        row.addArrangedSubview(openBtn)
        return row
    }

    private func refreshPermissions() {
        permissionCardStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        let accessStatus: PermissionStatus = AXIsProcessTrusted() ? .granted : .denied
        let items: [(String, String, PermissionStatus, String)] = [
            ("Accessibility", "Global keyboard shortcut", accessStatus, "SYSTEM"),
        ]

        let targets: [(String, String, String, String)] = [
            ("System Events", "com.apple.systemevents", "Raise terminal window", "SYSTEM"),
            ("Ghostty", "com.mitchellh.ghostty", "Switch terminal tabs", "TERMINAL"),
            ("iTerm2", "com.googlecode.iterm2", "Switch terminal tabs", "TERMINAL"),
            ("Terminal", "com.apple.Terminal", "Switch terminal tabs", "TERMINAL"),
        ]

        var allItems = items
        for (name, bundleId, action, category) in targets {
            let status = checkAutomationPermission(bundleId: bundleId)
            allItems.append((name, action, status, category))
        }

        for (i, (name, action, status, category)) in allItems.enumerated() {
            if i > 0 {
                permissionCardStack.addArrangedSubview(makePermissionDivider())
            }
            let row = makePermissionRow(name: name, action: action, status: status, category: category)
            permissionCardStack.addArrangedSubview(row)
        }

        // Pin permission rows to card width
        for view in permissionCardStack.arrangedSubviews {
            view.translatesAutoresizingMaskIntoConstraints = false
            view.widthAnchor.constraint(equalTo: permissionCardStack.widthAnchor).isActive = true
        }
    }

    private func checkAutomationPermission(bundleId: String) -> PermissionStatus {
        let target = NSAppleEventDescriptor(bundleIdentifier: bundleId)
        guard let aeDesc = target.aeDesc else { return .notRunning }
        let status = AEDeterminePermissionToAutomateTarget(aeDesc, typeWildCard, typeWildCard, false)
        return Self.permissionStatus(for: status)
    }

    private func makePermissionRow(name: String, action: String, status: PermissionStatus, category: String) -> NSView {
        let row = NSView()

        let dot = NSView()
        dot.wantsLayer = true
        dot.layer?.cornerRadius = 4
        dot.layer?.backgroundColor = statusColor(status).cgColor
        dot.layer?.shadowColor = statusColor(status).cgColor
        dot.layer?.shadowOpacity = 0.4
        dot.layer?.shadowRadius = 3
        dot.layer?.shadowOffset = .zero
        dot.translatesAutoresizingMaskIntoConstraints = false
        dot.widthAnchor.constraint(equalToConstant: 8).isActive = true
        dot.heightAnchor.constraint(equalToConstant: 8).isActive = true

        let nameLabel = NSTextField(labelWithString: name)
        nameLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)

        let statusPill = makeStatusPill(status)

        let categoryLabel = NSTextField(labelWithString: category)
        categoryLabel.font = .systemFont(ofSize: 10, weight: .semibold)
        categoryLabel.textColor = .tertiaryLabelColor
        categoryLabel.alignment = .right
        categoryLabel.translatesAutoresizingMaskIntoConstraints = false
        categoryLabel.setContentHuggingPriority(.required, for: .horizontal)

        let descLabel = NSTextField(labelWithString: action)
        descLabel.font = .systemFont(ofSize: 11)
        descLabel.textColor = .secondaryLabelColor
        descLabel.translatesAutoresizingMaskIntoConstraints = false

        row.addSubview(dot)
        row.addSubview(nameLabel)
        row.addSubview(statusPill)
        row.addSubview(categoryLabel)
        row.addSubview(descLabel)

        NSLayoutConstraint.activate([
            dot.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 14),
            dot.topAnchor.constraint(equalTo: row.topAnchor, constant: 13),

            nameLabel.leadingAnchor.constraint(equalTo: dot.trailingAnchor, constant: 8),
            nameLabel.topAnchor.constraint(equalTo: row.topAnchor, constant: 10),

            statusPill.leadingAnchor.constraint(equalTo: nameLabel.trailingAnchor, constant: 8),
            statusPill.centerYAnchor.constraint(equalTo: nameLabel.centerYAnchor),

            categoryLabel.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -14),
            categoryLabel.topAnchor.constraint(equalTo: row.topAnchor, constant: 10),
            categoryLabel.leadingAnchor.constraint(greaterThanOrEqualTo: statusPill.trailingAnchor, constant: 8),

            descLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            descLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 2),
            descLabel.bottomAnchor.constraint(equalTo: row.bottomAnchor, constant: -10),
        ])

        return row
    }

    private func makePermissionDivider() -> NSView {
        let line = NSView()
        line.wantsLayer = true
        line.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.06).cgColor
        line.translatesAutoresizingMaskIntoConstraints = false
        line.heightAnchor.constraint(equalToConstant: 0.5).isActive = true
        return line
    }

    private func makeStatusPill(_ status: PermissionStatus) -> NSView {
        let pill = NSView()
        pill.wantsLayer = true
        pill.layer?.cornerRadius = 999
        pill.translatesAutoresizingMaskIntoConstraints = false

        let (bgColor, textColor, labelText): (NSColor, NSColor, String)
        switch status {
        case .granted:
            bgColor = NSColor(red: 34/255, green: 160/255, blue: 107/255, alpha: 0.12)
            textColor = NSColor(red: 20/255, green: 130/255, blue: 80/255, alpha: 1)
            labelText = "Granted"
        case .denied:
            bgColor = NSColor.systemRed.withAlphaComponent(0.12)
            textColor = .systemRed
            labelText = "Denied"
        case .notAsked:
            bgColor = NSColor.systemOrange.withAlphaComponent(0.12)
            textColor = .systemOrange
            labelText = "Not Asked"
        case .notRunning:
            bgColor = NSColor.black.withAlphaComponent(0.05)
            textColor = .secondaryLabelColor
            labelText = "Not Running"
        }

        pill.layer?.backgroundColor = bgColor.cgColor

        let label = NSTextField(labelWithString: labelText)
        label.font = .systemFont(ofSize: 10, weight: .medium)
        label.textColor = textColor
        label.translatesAutoresizingMaskIntoConstraints = false
        pill.addSubview(label)

        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: pill.topAnchor, constant: 2),
            label.bottomAnchor.constraint(equalTo: pill.bottomAnchor, constant: -2),
            label.leadingAnchor.constraint(equalTo: pill.leadingAnchor, constant: 7),
            label.trailingAnchor.constraint(equalTo: pill.trailingAnchor, constant: -7),
        ])

        return pill
    }

    private func statusColor(_ status: PermissionStatus) -> NSColor {
        switch status {
        case .granted: return NSColor(red: 34/255, green: 160/255, blue: 107/255, alpha: 1)
        case .denied: return .systemRed
        case .notAsked: return .systemOrange
        case .notRunning: return .systemGray
        }
    }

    // MARK: - Bottom Bar

    private func makeBottomBar() -> NSView {
        let bar = NSView()
        bar.wantsLayer = true

        let separator = NSView()
        separator.wantsLayer = true
        separator.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.08).cgColor
        separator.translatesAutoresizingMaskIntoConstraints = false
        bar.addSubview(separator)

        let hintLabel = NSTextField(labelWithString: "⌘, to reopen")
        hintLabel.font = .systemFont(ofSize: 11)
        hintLabel.textColor = .tertiaryLabelColor
        hintLabel.translatesAutoresizingMaskIntoConstraints = false
        bar.addSubview(hintLabel)

        let doneBtn = DarkButton(title: "Done", target: self, action: #selector(donePressed))
        doneBtn.keyEquivalent = "\r"
        doneBtn.translatesAutoresizingMaskIntoConstraints = false
        bar.addSubview(doneBtn)

        NSLayoutConstraint.activate([
            separator.topAnchor.constraint(equalTo: bar.topAnchor),
            separator.leadingAnchor.constraint(equalTo: bar.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: bar.trailingAnchor),
            separator.heightAnchor.constraint(equalToConstant: 0.5),

            hintLabel.leadingAnchor.constraint(equalTo: bar.leadingAnchor, constant: 16),
            hintLabel.centerYAnchor.constraint(equalTo: bar.centerYAnchor),

            doneBtn.trailingAnchor.constraint(equalTo: bar.trailingAnchor, constant: -16),
            doneBtn.centerYAnchor.constraint(equalTo: bar.centerYAnchor),

            bar.heightAnchor.constraint(equalToConstant: 44),
        ])

        return bar
    }

    // MARK: - Thumbnails

    private func makeThumbnail(tag: Int) -> NSView {
        let container = NSView()
        container.wantsLayer = true
        container.layer?.cornerRadius = 8
        container.layer?.backgroundColor = NSColor(white: 0.14, alpha: 1).cgColor
        container.layer?.masksToBounds = true

        if tag == 0 {
            let terminal = NSView()
            terminal.wantsLayer = true
            terminal.layer?.cornerRadius = 4
            terminal.layer?.backgroundColor = NSColor(white: 0.08, alpha: 1).cgColor
            terminal.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(terminal)

            for i in 0..<3 {
                let line = NSView()
                line.wantsLayer = true
                line.layer?.backgroundColor = NSColor.systemGreen.withAlphaComponent(0.5).cgColor
                line.layer?.cornerRadius = 1.5
                line.translatesAutoresizingMaskIntoConstraints = false
                terminal.addSubview(line)
                NSLayoutConstraint.activate([
                    line.leadingAnchor.constraint(equalTo: terminal.leadingAnchor, constant: 7),
                    line.widthAnchor.constraint(equalToConstant: CGFloat(56 - i * 14)),
                    line.heightAnchor.constraint(equalToConstant: 3),
                    line.topAnchor.constraint(equalTo: terminal.topAnchor, constant: CGFloat(8 + i * 9)),
                ])
            }

            NSLayoutConstraint.activate([
                terminal.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
                terminal.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 10),
                terminal.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -10),
                terminal.heightAnchor.constraint(equalToConstant: 46),
            ])

            let cardsRow = NSStackView()
            cardsRow.orientation = .horizontal
            cardsRow.spacing = 4
            cardsRow.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(cardsRow)

            for i in 0..<5 {
                let c = NSView()
                c.wantsLayer = true
                c.layer?.cornerRadius = 3
                c.layer?.backgroundColor = (i == 1)
                    ? NSColor.systemCyan.withAlphaComponent(0.65).cgColor
                    : NSColor(white: 0.28, alpha: 1).cgColor
                c.translatesAutoresizingMaskIntoConstraints = false
                c.widthAnchor.constraint(equalToConstant: 18).isActive = true
                c.heightAnchor.constraint(equalToConstant: 18).isActive = true
                cardsRow.addArrangedSubview(c)
            }

            NSLayoutConstraint.activate([
                cardsRow.topAnchor.constraint(equalTo: terminal.bottomAnchor, constant: 8),
                cardsRow.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            ])
        } else {
            let terminal = NSView()
            terminal.wantsLayer = true
            terminal.layer?.cornerRadius = 4
            terminal.layer?.backgroundColor = NSColor(white: 0.08, alpha: 1).cgColor
            terminal.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(terminal)

            for i in 0..<5 {
                let line = NSView()
                line.wantsLayer = true
                line.layer?.backgroundColor = NSColor.systemGreen.withAlphaComponent(0.5).cgColor
                line.layer?.cornerRadius = 1.5
                line.translatesAutoresizingMaskIntoConstraints = false
                terminal.addSubview(line)
                NSLayoutConstraint.activate([
                    line.leadingAnchor.constraint(equalTo: terminal.leadingAnchor, constant: 7),
                    line.widthAnchor.constraint(equalToConstant: CGFloat(68 - i * 10)),
                    line.heightAnchor.constraint(equalToConstant: 3),
                    line.topAnchor.constraint(equalTo: terminal.topAnchor, constant: CGFloat(8 + i * 9)),
                ])
            }

            NSLayoutConstraint.activate([
                terminal.topAnchor.constraint(equalTo: container.topAnchor, constant: 10),
                terminal.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 10),
                terminal.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -10),
                terminal.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -10),
            ])
        }

        return container
    }

    // MARK: - Shared Primitives

    private func makeCard() -> NSView {
        let card = NSView()
        card.wantsLayer = true
        card.layer?.cornerRadius = 10
        card.layer?.borderWidth = 1
        card.layer?.borderColor = NSColor.black.withAlphaComponent(0.08).cgColor
        card.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.6).cgColor
        return card
    }

    // Standard keycap badge (for arrows and non-modifier keys)
    func makeKeycapBadge(_ symbol: String) -> NSView {
        let badge = KeycapBadgeView(symbol: symbol, textColor: .labelColor)
        badge.translatesAutoresizingMaskIntoConstraints = false
        return badge
    }

    // Modifier keycap badge — cyan text
    private func makeModifierKeycapBadge(_ symbol: String) -> NSView {
        let badge = KeycapBadgeView(symbol: symbol, textColor: .systemCyan)
        badge.translatesAutoresizingMaskIntoConstraints = false
        return badge
    }

    // MARK: - Actions

    @objc private func modifierToggled(_ sender: NSButton) {
        guard let (rawValue, _) = modifierToggles.first(where: { $0.value === sender }) else { return }
        let flag = CGEventFlags(rawValue: rawValue)

        var newFlags = config.modifierFlags
        if newFlags.contains(flag) {
            let remaining = newFlags.subtracting(flag)
            let knownModifiers: CGEventFlags = [.maskCommand, .maskShift, .maskAlternate, .maskControl]
            guard !remaining.intersection(knownModifiers).isEmpty else { return }
            newFlags = remaining
        } else {
            newFlags.insert(flag)
        }

        config.modifierFlags = newFlags
        config.save()
        HotkeyManager.updateConfig(config)
        updateModifierToggleAppearance()
        rebuildDynamicBindingRows()
    }

    @objc private func displayModeCardClicked(_ gesture: NSClickGestureRecognizer) {
        guard let clickedCard = gesture.view else { return }
        let tag = displayModeCards.first(where: { $0.value === clickedCard })?.key ?? 0
        config.displayMode = tag == 0 ? .listAndPreview : .previewOnly
        config.save()
        updateDisplayModeCardBorders()
    }

    @objc private func openSystemSettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }

    @objc private func donePressed() {
        orderOut(nil)
    }

    // MARK: - Update Helpers

    private func updateModifierToggleAppearance() {
        for (rawValue, btn) in modifierToggles {
            let flag = CGEventFlags(rawValue: rawValue)
            let isSelected = config.modifierFlags.contains(flag)
            applyModifierButtonStyle(btn, isSelected: isSelected)
            if let innerStack = btn.subviews.first as? NSStackView,
               let checkView = innerStack.arrangedSubviews.first {
                applyCheckboxStyle(checkView, isSelected: isSelected)
            }
        }
    }

    private func rebuildDynamicBindingRows() {
        let arrows = ["→", "←"]
        for (badgesStack, arrow) in zip(dynamicBindingBadgeStacks, arrows) {
            let newBadges = modifierBadges() + [makeKeycapBadge(arrow)]
            badgesStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
            for badge in newBadges {
                badgesStack.addArrangedSubview(badge)
            }
        }
    }

    // MARK: - Public API

    public func show() {
        config = CycleConfig.load()
        updateModifierToggleAppearance()
        updateDisplayModeCardBorders()
        refreshPermissions()
        orderFront(nil)
    }

    public static func permissionStatus(for code: OSStatus) -> PermissionStatus {
        switch code {
        case noErr: return .granted
        case OSStatus(errAEEventNotPermitted): return .denied
        case OSStatus(errAEEventWouldRequireUserConsent): return .notAsked
        case OSStatus(procNotFound): return .notRunning
        default: return .notRunning
        }
    }

    public static func modifierSymbols(for flags: CGEventFlags) -> [String] {
        var symbols: [String] = []
        if flags.contains(.maskCommand) { symbols.append("⌘") }
        if flags.contains(.maskShift) { symbols.append("⇧") }
        if flags.contains(.maskAlternate) { symbols.append("⌥") }
        if flags.contains(.maskControl) { symbols.append("⌃") }
        return symbols
    }
}

// MARK: - DarkButton

private final class DarkButton: NSButton {
    override init(frame: NSRect) {
        super.init(frame: frame)
        setup()
    }

    convenience init(title: String, target: AnyObject?, action: Selector?) {
        self.init(frame: .zero)
        self.title = title
        self.target = target
        self.action = action
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        isBordered = false
        wantsLayer = true
        layer?.cornerRadius = 7
        layer?.backgroundColor = NSColor(white: 0.067, alpha: 1).cgColor
        font = .systemFont(ofSize: 13, weight: .medium)
        contentTintColor = .white
    }

    override var intrinsicContentSize: NSSize {
        let base = super.intrinsicContentSize
        return NSSize(width: base.width + 24, height: 28)
    }

    override func draw(_ dirtyRect: NSRect) {
        layer?.backgroundColor = NSColor(white: 0.067, alpha: 1).cgColor
        super.draw(dirtyRect)
    }
}

// MARK: - KeycapBadgeView

private final class KeycapBadgeView: NSView {
    init(symbol: String, textColor: NSColor) {
        super.init(frame: .zero)
        wantsLayer = true

        let label = NSTextField(labelWithString: symbol)
        label.font = .monospacedSystemFont(ofSize: 11, weight: .bold)
        label.textColor = textColor
        label.alignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)

        heightAnchor.constraint(equalToConstant: 24).isActive = true
        widthAnchor.constraint(greaterThanOrEqualToConstant: 24).isActive = true

        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: topAnchor, constant: 1),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -2),
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 7),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -7),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layout() {
        super.layout()
        let w = bounds.width
        let h = bounds.height
        let t: CGFloat = 1
        let thick: CGFloat = 1.5

        // Clear custom sublayers (keep the label's layer)
        layer?.sublayers?.filter { $0.name != nil }.forEach { $0.removeFromSuperlayer() }

        func makeLayer(color: NSColor, frame: CGRect) -> CALayer {
            let l = CALayer()
            l.name = "border"
            l.backgroundColor = color.cgColor
            l.frame = frame
            return l
        }

        layer?.cornerRadius = 6

        // White inset background
        let bg = CALayer()
        bg.name = "border"
        bg.backgroundColor = NSColor.white.cgColor
        bg.cornerRadius = 5
        bg.frame = CGRect(x: t, y: thick, width: w - 2*t, height: h - t - thick)
        layer?.insertSublayer(bg, at: 0)

        // Side borders
        let sideColor = NSColor.black.withAlphaComponent(0.12)
        let bottomColor = NSColor.black.withAlphaComponent(0.22)
        layer?.addSublayer(makeLayer(color: sideColor, frame: CGRect(x: 0, y: h - t, width: w, height: t)))
        layer?.addSublayer(makeLayer(color: sideColor, frame: CGRect(x: 0, y: 0, width: t, height: h)))
        layer?.addSublayer(makeLayer(color: sideColor, frame: CGRect(x: w - t, y: 0, width: t, height: h)))
        layer?.addSublayer(makeLayer(color: bottomColor, frame: CGRect(x: 0, y: 0, width: w, height: thick)))
    }
}
