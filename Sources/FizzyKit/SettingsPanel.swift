// Sources/FizzyKit/SettingsPanel.swift
import AppKit
import CoreGraphics

public final class SettingsPanel: NSPanel {
    public enum PermissionStatus: String, Equatable {
        case granted, denied, notAsked, notRunning
    }

    // MARK: - State

    private var config = CycleConfig.load()
    // Keyed by rawValue since CGEventFlags is not Hashable
    private var modifierToggles: [UInt64: NSButton] = [:]
    private var displayModeCards: [Int: NSView] = [:]
    private var dynamicBindingRows: [NSStackView] = []
    private var permissionRows: NSStackView!

    // MARK: - Init

    public init() {
        let size = NSSize(width: 500, height: 700)
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let origin = NSPoint(
            x: screen.frame.midX - size.width / 2,
            y: screen.frame.midY - size.height / 2
        )

        super.init(
            contentRect: NSRect(origin: origin, size: size),
            styleMask: [.titled, .closable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        title = "Settings"
        subtitle = "Fizzy 1.0"
        isOpaque = false
        backgroundColor = NSColor.windowBackgroundColor
        level = .floating

        setupUI()
    }

    // MARK: - UI Setup

    private func setupUI() {
        let outerContainer = NSView()
        outerContainer.translatesAutoresizingMaskIntoConstraints = false
        contentView = outerContainer

        // Scroll view (fills all but bottom bar)
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
        contentStack.edgeInsets = NSEdgeInsets(top: 24, left: 20, bottom: 24, right: 20)
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        let clipView = scrollView.contentView
        scrollView.documentView = contentStack

        // Bottom bar
        let bottomBar = makeBottomBar()
        bottomBar.translatesAutoresizingMaskIntoConstraints = false
        outerContainer.addSubview(bottomBar)

        // Layout constraints
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
        permissionRows = NSStackView()
        permissionRows.orientation = .vertical
        permissionRows.alignment = .leading
        permissionRows.spacing = 8
        permissionRows.translatesAutoresizingMaskIntoConstraints = false
        contentStack.addArrangedSubview(permissionRows)

        // Make content stack fill scroll width
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
        let cardStack = NSStackView()
        cardStack.orientation = .vertical
        cardStack.alignment = .leading
        cardStack.spacing = 10
        cardStack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(cardStack)

        NSLayoutConstraint.activate([
            cardStack.topAnchor.constraint(equalTo: card.topAnchor, constant: 12),
            cardStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
            cardStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),
            cardStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -12),
        ])

        let label = NSTextField(labelWithString: "MODIFIERS")
        label.font = .systemFont(ofSize: 10, weight: .semibold)
        label.textColor = .secondaryLabelColor
        cardStack.addArrangedSubview(label)

        let togglesRow = NSStackView()
        togglesRow.orientation = .horizontal
        togglesRow.spacing = 8

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

        cardStack.addArrangedSubview(togglesRow)
        return card
    }

    private func makeModifierToggleButton(flag: CGEventFlags, symbol: String, name: String) -> NSButton {
        let btn = NSButton()
        btn.bezelStyle = .regularSquare
        btn.isBordered = false
        btn.wantsLayer = true
        btn.layer?.cornerRadius = 8
        btn.layer?.borderWidth = 2
        btn.tag = Int(flag.rawValue & 0xFFFF)
        btn.target = self
        btn.action = #selector(modifierToggled(_:))

        let isSelected = config.modifierFlags.contains(flag)
        btn.layer?.borderColor = isSelected
            ? NSColor.systemCyan.cgColor
            : NSColor.separatorColor.cgColor
        btn.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor

        let innerStack = NSStackView()
        innerStack.orientation = .horizontal
        innerStack.spacing = 6
        innerStack.translatesAutoresizingMaskIntoConstraints = false

        let checkbox = NSImageView()
        checkbox.image = NSImage(systemSymbolName: isSelected ? "checkmark.square.fill" : "square", accessibilityDescription: nil)
        checkbox.contentTintColor = isSelected ? .systemCyan : .secondaryLabelColor
        checkbox.translatesAutoresizingMaskIntoConstraints = false
        checkbox.widthAnchor.constraint(equalToConstant: 14).isActive = true
        checkbox.heightAnchor.constraint(equalToConstant: 14).isActive = true

        let keycap = makeKeycapBadge(symbol)
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
            tableStack.topAnchor.constraint(equalTo: card.topAnchor, constant: 4),
            tableStack.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            tableStack.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            tableStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -4),
        ])

        // Dynamic rows (first 2: use current modifiers + arrow)
        let forwardRow = makeBindingRow(
            keyBadges: modifierBadges() + [makeKeycapBadge("→")],
            action: "Enter cycling",
            context: "forward"
        )
        let backwardRow = makeBindingRow(
            keyBadges: modifierBadges() + [makeKeycapBadge("←")],
            action: "Enter cycling",
            context: "backward"
        )
        dynamicBindingRows = [forwardRow, backwardRow]
        tableStack.addArrangedSubview(forwardRow)
        tableStack.addArrangedSubview(makeDivider())
        tableStack.addArrangedSubview(backwardRow)
        tableStack.addArrangedSubview(makeDivider())

        // Fixed rows
        let fixedRows: [([NSView], String, String)] = [
            ([makeKeycapBadge("→")], "Cycle forward", "while cycling"),
            ([makeKeycapBadge("←")], "Cycle backward", "while cycling"),
            ([makeKeycapBadge("↓")], "Confirm", "while cycling"),
            ([makeKeycapBadge("↑")], "Cancel", "while cycling"),
            ([makeTextBadge("Release modifiers")], "Confirm", "release modifiers"),
        ]

        for (i, (badges, action, context)) in fixedRows.enumerated() {
            let row = makeBindingRow(keyBadges: badges, action: action, context: context)
            tableStack.addArrangedSubview(row)
            if i < fixedRows.count - 1 {
                tableStack.addArrangedSubview(makeDivider())
            }
        }

        return card
    }

    private func modifierBadges() -> [NSView] {
        return SettingsPanel.modifierSymbols(for: config.modifierFlags).map { makeKeycapBadge($0) }
    }

    private func makeBindingRow(keyBadges: [NSView], action: String, context: String) -> NSStackView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 8
        row.edgeInsets = NSEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
        row.distribution = .fill

        // Left: key badges
        let badgesStack = NSStackView()
        badgesStack.orientation = .horizontal
        badgesStack.spacing = 4
        for badge in keyBadges {
            badgesStack.addArrangedSubview(badge)
        }
        badgesStack.setContentHuggingPriority(.defaultHigh, for: .horizontal)

        // Center: action name
        let actionLabel = NSTextField(labelWithString: action)
        actionLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        actionLabel.textColor = .labelColor
        actionLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)

        // Right: context
        let contextLabel = NSTextField(labelWithString: context)
        contextLabel.font = .systemFont(ofSize: 11)
        contextLabel.textColor = .tertiaryLabelColor
        contextLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)

        row.addArrangedSubview(badgesStack)
        row.addArrangedSubview(actionLabel)
        row.addArrangedSubview(contextLabel)
        return row
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
            let card = makeDisplayModeCard(tag: tag, title: title, description: desc)
            displayModeCards[tag] = card
            container.addArrangedSubview(card)
        }

        updateDisplayModeCardBorders()
        return container
    }

    private func makeDisplayModeCard(tag: Int, title: String, description: String) -> NSView {
        let card = makeCard()

        let click = NSClickGestureRecognizer(target: self, action: #selector(displayModeCardClicked(_:)))
        card.addGestureRecognizer(click)

        let innerStack = NSStackView()
        innerStack.orientation = .vertical
        innerStack.alignment = .leading
        innerStack.spacing = 8
        innerStack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(innerStack)

        NSLayoutConstraint.activate([
            innerStack.topAnchor.constraint(equalTo: card.topAnchor, constant: 12),
            innerStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
            innerStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),
            innerStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -12),
        ])

        // Thumbnail placeholder
        let thumbnail = NSView()
        thumbnail.wantsLayer = true
        thumbnail.layer?.backgroundColor = NSColor.controlColor.cgColor
        thumbnail.layer?.cornerRadius = 6
        thumbnail.translatesAutoresizingMaskIntoConstraints = false
        thumbnail.heightAnchor.constraint(equalToConstant: 90).isActive = true

        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        titleLabel.textColor = .labelColor

        let descLabel = NSTextField(wrappingLabelWithString: description)
        descLabel.font = .systemFont(ofSize: 11)
        descLabel.textColor = .secondaryLabelColor

        innerStack.addArrangedSubview(thumbnail)
        innerStack.addArrangedSubview(titleLabel)
        innerStack.addArrangedSubview(descLabel)

        // Thumbnail fills width
        thumbnail.leadingAnchor.constraint(equalTo: innerStack.leadingAnchor).isActive = true
        thumbnail.trailingAnchor.constraint(equalTo: innerStack.trailingAnchor).isActive = true

        return card
    }

    private func updateDisplayModeCardBorders() {
        let selectedTag = config.displayMode == .listAndPreview ? 0 : 1
        for (tag, card) in displayModeCards {
            card.layer?.borderColor = tag == selectedTag
                ? NSColor.systemCyan.cgColor
                : NSColor.separatorColor.cgColor
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
        permissionRows.arrangedSubviews.forEach { $0.removeFromSuperview() }

        let accessStatus: PermissionStatus = AXIsProcessTrusted() ? .granted : .denied
        permissionRows.addArrangedSubview(makePermissionRow(
            name: "Accessibility",
            action: "Global keyboard shortcut",
            status: accessStatus,
            category: "SYSTEM"
        ))

        let targets: [(String, String, String, String)] = [
            ("System Events", "com.apple.systemevents", "Raise terminal window", "SYSTEM"),
            ("Ghostty", "com.mitchellh.ghostty", "Switch terminal tabs", "TERMINAL"),
            ("iTerm2", "com.googlecode.iterm2", "Switch terminal tabs", "TERMINAL"),
            ("Terminal", "com.apple.Terminal", "Switch terminal tabs", "TERMINAL"),
        ]

        for (name, bundleId, action, category) in targets {
            let status = checkAutomationPermission(bundleId: bundleId)
            permissionRows.addArrangedSubview(makePermissionRow(
                name: name, action: action, status: status, category: category
            ))
        }

        // Width constraint for permission rows
        for view in permissionRows.arrangedSubviews {
            view.translatesAutoresizingMaskIntoConstraints = false
            if let width = permissionRows.superview?.superview?.frame.width {
                _ = width // accessed only to avoid warning
            }
        }
    }

    private func checkAutomationPermission(bundleId: String) -> PermissionStatus {
        let target = NSAppleEventDescriptor(bundleIdentifier: bundleId)
        guard let aeDesc = target.aeDesc else { return .notRunning }
        let status = AEDeterminePermissionToAutomateTarget(aeDesc, typeWildCard, typeWildCard, false)
        return Self.permissionStatus(for: status)
    }

    private func makePermissionRow(name: String, action: String, status: PermissionStatus, category: String) -> NSView {
        let card = makeCard()

        let innerStack = NSStackView()
        innerStack.orientation = .vertical
        innerStack.alignment = .leading
        innerStack.spacing = 4
        innerStack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(innerStack)

        NSLayoutConstraint.activate([
            innerStack.topAnchor.constraint(equalTo: card.topAnchor, constant: 10),
            innerStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
            innerStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),
            innerStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -10),
        ])

        // Top row: dot + name + status badge + spacer + category
        let topRow = NSStackView()
        topRow.orientation = .horizontal
        topRow.spacing = 8

        let dot = NSView()
        dot.wantsLayer = true
        dot.layer?.cornerRadius = 4
        dot.layer?.backgroundColor = statusColor(status).cgColor
        dot.translatesAutoresizingMaskIntoConstraints = false
        dot.widthAnchor.constraint(equalToConstant: 8).isActive = true
        dot.heightAnchor.constraint(equalToConstant: 8).isActive = true

        let nameLabel = NSTextField(labelWithString: name)
        nameLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        nameLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)

        let statusPill = makeStatusPill(status)

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let categoryLabel = NSTextField(labelWithString: category)
        categoryLabel.font = .systemFont(ofSize: 10, weight: .semibold)
        categoryLabel.textColor = .tertiaryLabelColor
        categoryLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)

        topRow.addArrangedSubview(dot)
        topRow.addArrangedSubview(nameLabel)
        topRow.addArrangedSubview(statusPill)
        topRow.addArrangedSubview(spacer)
        topRow.addArrangedSubview(categoryLabel)

        let descLabel = NSTextField(labelWithString: action)
        descLabel.font = .systemFont(ofSize: 11)
        descLabel.textColor = .secondaryLabelColor

        innerStack.addArrangedSubview(topRow)
        innerStack.addArrangedSubview(descLabel)

        return card
    }

    private func makeStatusPill(_ status: PermissionStatus) -> NSView {
        let pill = NSView()
        pill.wantsLayer = true
        pill.layer?.cornerRadius = 8
        pill.layer?.borderWidth = 1.5
        pill.layer?.borderColor = statusColor(status).cgColor
        pill.translatesAutoresizingMaskIntoConstraints = false

        let label = NSTextField(labelWithString: status.rawValue.capitalized)
        label.font = .systemFont(ofSize: 10, weight: .medium)
        label.textColor = statusColor(status)
        label.translatesAutoresizingMaskIntoConstraints = false
        pill.addSubview(label)

        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: pill.topAnchor, constant: 2),
            label.bottomAnchor.constraint(equalTo: pill.bottomAnchor, constant: -2),
            label.leadingAnchor.constraint(equalTo: pill.leadingAnchor, constant: 8),
            label.trailingAnchor.constraint(equalTo: pill.trailingAnchor, constant: -8),
        ])

        return pill
    }

    private func statusColor(_ status: PermissionStatus) -> NSColor {
        switch status {
        case .granted: return .systemGreen
        case .denied: return .systemRed
        case .notAsked: return .systemYellow
        case .notRunning: return .systemGray
        }
    }

    // MARK: - Bottom Bar

    private func makeBottomBar() -> NSView {
        let bar = NSView()
        bar.wantsLayer = true
        bar.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        let separator = NSBox()
        separator.boxType = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false
        bar.addSubview(separator)

        let hintLabel = NSTextField(labelWithString: "⌘, to reopen")
        hintLabel.font = .systemFont(ofSize: 11)
        hintLabel.textColor = .tertiaryLabelColor
        hintLabel.translatesAutoresizingMaskIntoConstraints = false
        bar.addSubview(hintLabel)

        let doneBtn = NSButton(title: "Done", target: self, action: #selector(donePressed))
        doneBtn.bezelStyle = .rounded
        doneBtn.keyEquivalent = "\r"
        doneBtn.translatesAutoresizingMaskIntoConstraints = false
        bar.addSubview(doneBtn)

        NSLayoutConstraint.activate([
            separator.topAnchor.constraint(equalTo: bar.topAnchor),
            separator.leadingAnchor.constraint(equalTo: bar.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: bar.trailingAnchor),

            hintLabel.leadingAnchor.constraint(equalTo: bar.leadingAnchor, constant: 16),
            hintLabel.centerYAnchor.constraint(equalTo: bar.centerYAnchor, constant: 1),

            doneBtn.trailingAnchor.constraint(equalTo: bar.trailingAnchor, constant: -16),
            doneBtn.centerYAnchor.constraint(equalTo: bar.centerYAnchor, constant: 1),

            bar.heightAnchor.constraint(equalToConstant: 44),
        ])

        return bar
    }

    // MARK: - Shared Primitives

    private func makeCard() -> NSView {
        let card = NSView()
        card.wantsLayer = true
        card.layer?.cornerRadius = 10
        card.layer?.borderWidth = 1.5
        card.layer?.borderColor = NSColor.separatorColor.cgColor
        card.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        return card
    }

    private func makeDivider() -> NSView {
        let line = NSView()
        line.wantsLayer = true
        line.layer?.backgroundColor = NSColor.separatorColor.cgColor
        line.translatesAutoresizingMaskIntoConstraints = false
        line.heightAnchor.constraint(equalToConstant: 0.5).isActive = true
        return line
    }

    func makeKeycapBadge(_ symbol: String) -> NSView {
        let badge = NSView()
        badge.wantsLayer = true
        badge.layer?.cornerRadius = 5
        badge.layer?.borderWidth = 1
        badge.layer?.borderColor = NSColor.separatorColor.cgColor
        badge.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        badge.translatesAutoresizingMaskIntoConstraints = false

        let label = NSTextField(labelWithString: symbol)
        label.font = .systemFont(ofSize: 12)
        label.alignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        badge.addSubview(label)

        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: badge.topAnchor, constant: 2),
            label.bottomAnchor.constraint(equalTo: badge.bottomAnchor, constant: -2),
            label.leadingAnchor.constraint(equalTo: badge.leadingAnchor, constant: 6),
            label.trailingAnchor.constraint(equalTo: badge.trailingAnchor, constant: -6),
        ])

        return badge
    }

    private func makeTextBadge(_ text: String) -> NSView {
        let badge = NSView()
        badge.wantsLayer = true
        badge.layer?.cornerRadius = 5
        badge.layer?.borderWidth = 1
        badge.layer?.borderColor = NSColor.separatorColor.cgColor
        badge.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        badge.translatesAutoresizingMaskIntoConstraints = false

        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 11)
        label.alignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        badge.addSubview(label)

        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: badge.topAnchor, constant: 2),
            label.bottomAnchor.constraint(equalTo: badge.bottomAnchor, constant: -2),
            label.leadingAnchor.constraint(equalTo: badge.leadingAnchor, constant: 6),
            label.trailingAnchor.constraint(equalTo: badge.trailingAnchor, constant: -6),
        ])

        return badge
    }

    // MARK: - Actions

    @objc private func modifierToggled(_ sender: NSButton) {
        // Find which flag this button represents
        guard let (rawValue, _) = modifierToggles.first(where: { $0.value === sender }) else { return }
        let flag = CGEventFlags(rawValue: rawValue)

        var newFlags = config.modifierFlags
        if newFlags.contains(flag) {
            // Don't deselect if it would leave no modifiers
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

    // MARK: - Update helpers

    private func updateModifierToggleAppearance() {
        for (rawValue, btn) in modifierToggles {
            let flag = CGEventFlags(rawValue: rawValue)
            let isSelected = config.modifierFlags.contains(flag)
            btn.layer?.borderColor = isSelected
                ? NSColor.systemCyan.cgColor
                : NSColor.separatorColor.cgColor
            // Update checkbox image inside button
            if let innerStack = btn.subviews.first as? NSStackView,
               let checkView = innerStack.arrangedSubviews.first as? NSImageView {
                checkView.image = NSImage(systemSymbolName: isSelected ? "checkmark.square.fill" : "square", accessibilityDescription: nil)
                checkView.contentTintColor = isSelected ? .systemCyan : .secondaryLabelColor
            }
        }
    }

    private func rebuildDynamicBindingRows() {
        guard dynamicBindingRows.count == 2 else { return }

        let newBadgesForward = modifierBadges() + [makeKeycapBadge("→")]
        let newBadgesBackward = modifierBadges() + [makeKeycapBadge("←")]
        let newBadgeSets = [newBadgesForward, newBadgesBackward]

        for (row, badges) in zip(dynamicBindingRows, newBadgeSets) {
            guard let badgesStack = (row.arrangedSubviews.first as? NSStackView) else { continue }
            badgesStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
            for badge in badges {
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
