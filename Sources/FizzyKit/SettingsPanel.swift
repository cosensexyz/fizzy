import AppKit
import CoreGraphics

public final class SettingsPanel: NSPanel {
    public enum PermissionStatus: String, Equatable {
        case granted, denied, notAsked, notRunning
    }

    private var config = FizzyConfig.load()
    private var modifierCheckboxes: [(flag: CGEventFlags, button: NSButton)] = []
    private var bindingModifierLabels: [NSTextField] = []
    private var displayModeRow: NSStackView!
    private var permissionGrid: NSGridView!

    public var onBubbleColorChanged: ((NSColor) -> Void)?
    private var colorSwatches: [NSView] = []
    private var swatchUnselectedBorders: [CGColor] = []
    private var selectedColorIndex: Int = 0
    private var colorSaveWork: DispatchWorkItem?
    private var ownsColorPanel = false

    static let presetColors: [(name: String, color: NSColor)] = [
        ("White", NSColor(colorSpace: .sRGB, components: [1.0, 1.0, 1.0, 1.0], count: 4)),
        ("Blue", NSColor(colorSpace: .sRGB, components: [0.0, 0.75, 1.0, 1.0], count: 4)),
        ("Green", NSColor(colorSpace: .sRGB, components: [0.0, 0.9, 0.4, 1.0], count: 4)),
        ("Pink", NSColor(colorSpace: .sRGB, components: [1.0, 0.3, 0.5, 1.0], count: 4)),
        ("Orange", NSColor(colorSpace: .sRGB, components: [1.0, 0.6, 0.0, 1.0], count: 4)),
        ("Purple", NSColor(colorSpace: .sRGB, components: [0.7, 0.3, 1.0, 1.0], count: 4)),
    ]

    public init() {
        let size = NSSize(width: 480, height: 640)
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
        isOpaque = false
        backgroundColor = .windowBackgroundColor
        level = .floating

        setupUI()
    }

    private func setupUI() {
        let outer = NSView()
        outer.translatesAutoresizingMaskIntoConstraints = false
        contentView = outer

        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        outer.addSubview(scrollView)

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 20
        stack.edgeInsets = NSEdgeInsets(top: 16, left: 24, bottom: 16, right: 24)
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = stack

        let bottomBar = makeBottomBar()
        bottomBar.translatesAutoresizingMaskIntoConstraints = false
        outer.addSubview(bottomBar)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: outer.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: outer.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: outer.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomBar.topAnchor),
            bottomBar.leadingAnchor.constraint(equalTo: outer.leadingAnchor),
            bottomBar.trailingAnchor.constraint(equalTo: outer.trailingAnchor),
            bottomBar.bottomAnchor.constraint(equalTo: outer.bottomAnchor),
            stack.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor),
            stack.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scrollView.contentView.trailingAnchor),
            stack.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor),
        ])

        stack.addArrangedSubview(makeSectionLabel("Appearance"))
        stack.addArrangedSubview(makeAppearanceRow())
        stack.addArrangedSubview(makeSeparator())

        stack.addArrangedSubview(makeSectionLabel("Cycle Shortcut"))
        stack.addArrangedSubview(makeSecondaryLabel(
            "Hold your modifiers, then use arrow keys to switch between Claude Code sessions."
        ))
        stack.addArrangedSubview(makeModifierRow())
        stack.addArrangedSubview(makeSeparator())
        stack.addArrangedSubview(makeBindingsGrid())

        stack.addArrangedSubview(makeSeparator())
        stack.addArrangedSubview(makeSectionLabel("Display Mode"))
        stack.addArrangedSubview(makeSecondaryLabel("What appears when you trigger the shortcut."))
        stack.addArrangedSubview(makeDisplayModeRadios())

        stack.addArrangedSubview(makeSeparator())
        stack.addArrangedSubview(makeSectionLabel("Notification List"))
        stack.addArrangedSubview(makeSecondaryLabel("How the notification list opens when you interact with the bubble."))
        stack.addArrangedSubview(makeListTriggerRadios())

        stack.addArrangedSubview(makeSeparator())
        stack.addArrangedSubview(makePermissionsHeader())
        permissionGrid = makePermissionGrid()
        permissionGrid.translatesAutoresizingMaskIntoConstraints = false
        populatePermissionGrid(permissionGrid)
        stack.addArrangedSubview(permissionGrid)

        for view in stack.arrangedSubviews {
            view.translatesAutoresizingMaskIntoConstraints = false
            view.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -48).isActive = true
        }
    }

    // MARK: - Helpers

    private func makeSectionLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 13, weight: .semibold)
        return label
    }

    private func makeSecondaryLabel(_ text: String) -> NSTextField {
        let label = NSTextField(wrappingLabelWithString: text)
        label.font = .systemFont(ofSize: 11)
        label.textColor = .secondaryLabelColor
        return label
    }

    private func makeSeparator() -> NSBox {
        let sep = NSBox()
        sep.boxType = .separator
        return sep
    }

    // MARK: - Appearance

    private func makeAppearanceRow() -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 8
        row.alignment = .centerY

        let label = NSTextField(labelWithString: "Bubble Color")
        label.font = .systemFont(ofSize: 12)
        label.textColor = .secondaryLabelColor
        label.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        row.addArrangedSubview(label)

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        spacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        row.addArrangedSubview(spacer)

        let savedHex = config.bubbleColorHex
        selectedColorIndex = Self.presetColors.firstIndex(where: { $0.color.hexString == savedHex }) ?? -1

        for (i, preset) in Self.presetColors.enumerated() {
            let swatch = makeColorSwatch(color: preset.color, selected: i == selectedColorIndex)
            colorSwatches.append(swatch)
            row.addArrangedSubview(swatch)
        }

        let customSwatch = makeCustomSwatch(selected: selectedColorIndex == -1)
        if selectedColorIndex == -1, let customColor = NSColor(hex: savedHex) {
            customSwatch.wantsLayer = true
            customSwatch.layer?.backgroundColor = customColor.cgColor
        }
        colorSwatches.append(customSwatch)
        row.addArrangedSubview(customSwatch)

        return row
    }

    private func makeColorSwatch(color: NSColor, selected: Bool) -> NSView {
        let size: CGFloat = 20
        let swatch = NSView(frame: NSRect(x: 0, y: 0, width: size, height: size))
        swatch.wantsLayer = true
        swatch.layer?.cornerRadius = size / 2
        swatch.layer?.backgroundColor = color.cgColor
        let isWhite = color.usingColorSpace(.sRGB).map { $0.redComponent > 0.95 && $0.greenComponent > 0.95 && $0.blueComponent > 0.95 } ?? false
        let unselectedBorder = isWhite ? NSColor.gray.cgColor : NSColor.separatorColor.cgColor
        swatchUnselectedBorders.append(unselectedBorder)
        swatch.layer?.borderWidth = selected ? 2.5 : 1.5
        swatch.layer?.borderColor = selected ? NSColor.controlAccentColor.cgColor : unselectedBorder
        swatch.translatesAutoresizingMaskIntoConstraints = false
        swatch.widthAnchor.constraint(equalToConstant: size).isActive = true
        swatch.heightAnchor.constraint(equalToConstant: size).isActive = true

        let click = NSClickGestureRecognizer(target: self, action: #selector(swatchClicked(_:)))
        swatch.addGestureRecognizer(click)

        return swatch
    }

    private func makeCustomSwatch(selected: Bool) -> NSView {
        let size: CGFloat = 20
        let swatch = NSView(frame: NSRect(x: 0, y: 0, width: size, height: size))
        swatch.wantsLayer = true
        swatch.layer?.cornerRadius = size / 2
        let unselectedBorder = NSColor.separatorColor.cgColor
        swatchUnselectedBorders.append(unselectedBorder)
        swatch.layer?.borderWidth = selected ? 2.5 : 1.5
        swatch.layer?.borderColor = selected ? NSColor.controlAccentColor.cgColor : unselectedBorder
        swatch.translatesAutoresizingMaskIntoConstraints = false
        swatch.widthAnchor.constraint(equalToConstant: size).isActive = true
        swatch.heightAnchor.constraint(equalToConstant: size).isActive = true

        let gradient = CAGradientLayer()
        gradient.type = .conic
        gradient.colors = [
            NSColor.red.cgColor, NSColor.yellow.cgColor,
            NSColor.green.cgColor, NSColor.cyan.cgColor,
            NSColor.blue.cgColor, NSColor.magenta.cgColor,
            NSColor.red.cgColor,
        ]
        gradient.startPoint = CGPoint(x: 0.5, y: 0.5)
        gradient.endPoint = CGPoint(x: 0.5, y: 0)
        gradient.frame = NSRect(x: 0, y: 0, width: size, height: size)
        gradient.cornerRadius = size / 2

        let mask = CAShapeLayer()
        mask.path = CGPath(ellipseIn: NSRect(x: 1, y: 1, width: size - 2, height: size - 2), transform: nil)
        gradient.mask = mask

        swatch.layer?.addSublayer(gradient)

        let click = NSClickGestureRecognizer(target: self, action: #selector(customSwatchClicked(_:)))
        swatch.addGestureRecognizer(click)

        return swatch
    }

    private func updateSwatchSelection(_ index: Int) {
        selectedColorIndex = index
        for (i, swatch) in colorSwatches.enumerated() {
            let selected = i == index
            swatch.layer?.borderWidth = selected ? 2.5 : 1.5
            let unselected = i < swatchUnselectedBorders.count ? swatchUnselectedBorders[i] : NSColor.separatorColor.cgColor
            swatch.layer?.borderColor = selected ? NSColor.controlAccentColor.cgColor : unselected
        }
        let customIndex = colorSwatches.count - 1
        if index != customIndex, let gradient = colorSwatches[customIndex].layer?.sublayers?.first {
            gradient.opacity = 1
        }
    }

    // MARK: - Modifier checkboxes

    private func makeModifierRow() -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 4

        let label = NSTextField(labelWithString: "Modifiers")
        label.font = .systemFont(ofSize: 12)
        label.textColor = .secondaryLabelColor
        label.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        row.addArrangedSubview(label)

        let spacer = NSView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.widthAnchor.constraint(equalToConstant: 8).isActive = true
        row.addArrangedSubview(spacer)

        let modifiers: [(CGEventFlags, String)] = [
            (.maskCommand, "⌘ Cmd"),
            (.maskShift, "⇧ Shift"),
            (.maskAlternate, "⌥ Opt"),
            (.maskControl, "⌃ Ctrl"),
        ]

        for (flag, title) in modifiers {
            let cb = NSButton(checkboxWithTitle: title, target: self, action: #selector(modifierChanged(_:)))
            cb.state = config.cycle.modifierFlags.contains(flag) ? .on : .off
            cb.font = .systemFont(ofSize: 12)
            modifierCheckboxes.append((flag: flag, button: cb))
            row.addArrangedSubview(cb)
        }

        return row
    }

    // MARK: - Key bindings grid

    private func makeBindingsGrid() -> NSView {
        let modStr = currentModifierString()

        let rows: [(String, String, String)] = [
            ("\(modStr) + →", "Enter cycling (forward)", ""),
            ("\(modStr) + ←", "Enter cycling (backward)", ""),
            ("→", "Cycle forward", "while cycling"),
            ("←", "Cycle backward", "while cycling"),
            ("↓", "Confirm", "while cycling"),
            ("↑", "Cancel", "while cycling"),
            ("Release modifiers", "Confirm", ""),
        ]

        let grid = NSGridView(numberOfColumns: 3, rows: 0)
        grid.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        grid.column(at: 0).width = 160
        grid.column(at: 1).xPlacement = .leading
        grid.column(at: 2).xPlacement = .trailing
        grid.rowSpacing = 4
        grid.columnSpacing = 12

        for (i, (keys, action, hint)) in rows.enumerated() {
            let keysLabel = NSTextField(labelWithString: keys)
            keysLabel.font = .systemFont(ofSize: 12)
            keysLabel.textColor = .secondaryLabelColor

            let actionLabel = NSTextField(labelWithString: action)
            actionLabel.font = .systemFont(ofSize: 12, weight: .medium)

            let hintLabel = NSTextField(labelWithString: hint)
            hintLabel.font = .systemFont(ofSize: 11)
            hintLabel.textColor = .tertiaryLabelColor

            grid.addRow(with: [keysLabel, actionLabel, hintLabel])

            if i < 2 {
                bindingModifierLabels.append(keysLabel)
            }
        }

        return grid
    }

    private func currentModifierString() -> String {
        Self.modifierSymbols(for: config.cycle.modifierFlags).joined(separator: " + ")
    }

    private func updateBindingLabels() {
        let modStr = currentModifierString()
        let arrows = ["→", "←"]
        for (i, label) in bindingModifierLabels.enumerated() {
            label.stringValue = "\(modStr) + \(arrows[i])"
        }
    }

    // MARK: - Display mode

    private func makeDisplayModeRadios() -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 12
        row.distribution = .fillEqually
        displayModeRow = row

        row.addArrangedSubview(makeDisplayModeCard(
            tag: 0, title: "Switcher + Preview",
            desc: "Cmd-Tab style row with a live preview of each session.",
            thumbnail: makeSwitcherThumbnail(),
            selected: config.cycle.displayMode == .listAndPreview
        ))
        row.addArrangedSubview(makeDisplayModeCard(
            tag: 1, title: "Preview only",
            desc: "Just the latest output. Faster, less to read.",
            thumbnail: makePreviewOnlyThumbnail(),
            selected: config.cycle.displayMode == .previewOnly
        ))

        return row
    }

    private func makeDisplayModeCard(tag: Int, title: String, desc: String, thumbnail: NSView, selected: Bool) -> NSView {
        let card = NSView()
        card.wantsLayer = true
        card.layer?.cornerRadius = 8
        card.layer?.borderWidth = selected ? 2 : 1
        card.layer?.borderColor = selected ? NSColor.systemCyan.cgColor : NSColor.separatorColor.cgColor
        card.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.edgeInsets = NSEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor),
        ])

        thumbnail.translatesAutoresizingMaskIntoConstraints = false
        thumbnail.heightAnchor.constraint(equalToConstant: 80).isActive = true
        stack.addArrangedSubview(thumbnail)
        thumbnail.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -20).isActive = true

        let radio = NSButton(radioButtonWithTitle: title, target: self, action: #selector(displayModeChanged(_:)))
        radio.font = .systemFont(ofSize: 12, weight: .medium)
        radio.tag = tag
        radio.state = selected ? .on : .off
        stack.addArrangedSubview(radio)

        let descLabel = NSTextField(wrappingLabelWithString: desc)
        descLabel.font = .systemFont(ofSize: 11)
        descLabel.textColor = .secondaryLabelColor
        stack.addArrangedSubview(descLabel)

        return card
    }

    private func updateDisplayModeCards() {
        guard let row = displayModeRow else { return }
        for (i, card) in row.arrangedSubviews.enumerated() {
            let selected = (i == 0 && config.cycle.displayMode == .listAndPreview) ||
                           (i == 1 && config.cycle.displayMode == .previewOnly)
            card.layer?.borderWidth = selected ? 2 : 1
            card.layer?.borderColor = selected ? NSColor.systemCyan.cgColor : NSColor.separatorColor.cgColor
            if let stack = card.subviews.first as? NSStackView,
               let radio = stack.arrangedSubviews.compactMap({ $0 as? NSButton }).first {
                radio.state = selected ? .on : .off
            }
        }
    }

    private func makeSwitcherThumbnail() -> NSView { ThumbnailView(mode: .switcher) }
    private func makePreviewOnlyThumbnail() -> NSView { ThumbnailView(mode: .previewOnly) }

    // MARK: - List trigger

    private func makeListTriggerRadios() -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6

        let r1 = NSButton(radioButtonWithTitle: "Click to open", target: self, action: #selector(listTriggerChanged(_:)))
        r1.font = .systemFont(ofSize: 12)
        r1.tag = 0

        let r2 = NSButton(radioButtonWithTitle: "Hover to open", target: self, action: #selector(listTriggerChanged(_:)))
        r2.font = .systemFont(ofSize: 12)
        r2.tag = 1

        if config.listTrigger == .click { r1.state = .on } else { r2.state = .on }

        stack.addArrangedSubview(r1)
        stack.addArrangedSubview(r2)
        return stack
    }

    // MARK: - Permissions

    private func makePermissionsHeader() -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 8

        let textStack = NSStackView()
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 2
        textStack.addArrangedSubview(makeSectionLabel("Permissions"))
        textStack.addArrangedSubview(makeSecondaryLabel("What macOS lets Fizzy do."))
        textStack.setContentHuggingPriority(.defaultHigh, for: .horizontal)

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        spacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let btn = NSButton(title: "Open System Settings ↗", target: self, action: #selector(openSystemSettings))
        btn.bezelStyle = .rounded
        btn.controlSize = .small
        btn.font = .systemFont(ofSize: 11)
        btn.setContentHuggingPriority(.required, for: .horizontal)

        row.addArrangedSubview(textStack)
        row.addArrangedSubview(spacer)
        row.addArrangedSubview(btn)
        return row
    }

    private func refreshPermissions() {
        guard let parent = permissionGrid.superview as? NSStackView else { return }
        guard let idx = parent.arrangedSubviews.firstIndex(of: permissionGrid) else { return }
        permissionGrid.removeFromSuperview()
        permissionGrid = makePermissionGrid()
        permissionGrid.translatesAutoresizingMaskIntoConstraints = false
        parent.insertArrangedSubview(permissionGrid, at: idx)
        permissionGrid.widthAnchor.constraint(equalTo: parent.widthAnchor, constant: -48).isActive = true
        populatePermissionGrid(permissionGrid)
    }

    private func populatePermissionGrid(_ grid: NSGridView) {
        let accessStatus: PermissionStatus = AXIsProcessTrusted() ? .granted : .denied
        addPermissionRow(to: grid, name: "Accessibility", desc: "Global keyboard shortcut",
                         status: accessStatus, category: "SYSTEM")

        let targets: [(String, String, String, String)] = [
            ("System Events", "com.apple.systemevents", "Raise terminal window", "SYSTEM"),
            ("Ghostty", "com.mitchellh.ghostty", "Switch terminal tabs", "TERMINAL"),
            ("iTerm2", "com.googlecode.iterm2", "Switch terminal tabs", "TERMINAL"),
            ("Terminal", "com.apple.Terminal", "Switch terminal tabs", "TERMINAL"),
        ]

        for (name, bundleId, desc, cat) in targets {
            let target = NSAppleEventDescriptor(bundleIdentifier: bundleId)
            let status: PermissionStatus
            if let aeDesc = target.aeDesc {
                status = Self.permissionStatus(for: AEDeterminePermissionToAutomateTarget(
                    aeDesc, typeWildCard, typeWildCard, false
                ))
            } else {
                status = .notRunning
            }
            addPermissionRow(to: grid, name: name, desc: desc, status: status, category: cat)
        }
    }

    private func makePermissionGrid() -> NSGridView {
        let grid = NSGridView(numberOfColumns: 5, rows: 0)
        grid.column(at: 0).width = 16
        grid.column(at: 1).width = 110
        grid.column(at: 2).width = 80
        grid.column(at: 3).xPlacement = .leading
        grid.column(at: 4).xPlacement = .trailing
        grid.rowSpacing = 6
        grid.columnSpacing = 8
        return grid
    }

    private func addPermissionRow(to grid: NSGridView, name: String, desc: String, status: PermissionStatus, category: String) {
        let dot = NSTextField(labelWithString: status == .granted ? "●" : "○")
        dot.font = .systemFont(ofSize: 10)
        dot.textColor = statusColor(status)

        let nameLabel = NSTextField(labelWithString: name)
        nameLabel.font = .systemFont(ofSize: 12, weight: .medium)

        let statusLabel = NSTextField(labelWithString: statusText(status))
        statusLabel.font = .systemFont(ofSize: 10, weight: .medium)
        statusLabel.textColor = statusColor(status)

        let descLabel = NSTextField(labelWithString: desc)
        descLabel.font = .systemFont(ofSize: 11)
        descLabel.textColor = .secondaryLabelColor

        let catLabel = NSTextField(labelWithString: category)
        catLabel.font = .monospacedSystemFont(ofSize: 9, weight: .regular)
        catLabel.textColor = .tertiaryLabelColor

        grid.addRow(with: [dot, nameLabel, statusLabel, descLabel, catLabel])
    }

    private func statusText(_ status: PermissionStatus) -> String {
        switch status {
        case .granted: return "Granted"
        case .denied: return "Denied"
        case .notAsked: return "Not Asked"
        case .notRunning: return "Not Running"
        }
    }

    private func statusColor(_ status: PermissionStatus) -> NSColor {
        switch status {
        case .granted: return .systemGreen
        case .denied: return .systemRed
        case .notAsked: return .systemYellow
        case .notRunning: return .systemGray
        }
    }

    // MARK: - Bottom bar

    private func makeBottomBar() -> NSView {
        let bar = NSView()

        let sep = NSBox()
        sep.boxType = .separator
        sep.translatesAutoresizingMaskIntoConstraints = false
        bar.addSubview(sep)

        let hint = NSTextField(labelWithString: "⌘, to reopen")
        hint.font = .systemFont(ofSize: 11)
        hint.textColor = .tertiaryLabelColor
        hint.translatesAutoresizingMaskIntoConstraints = false
        bar.addSubview(hint)

        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
        let versionLabel = NSTextField(labelWithString: "Fizzy \(version)")
        versionLabel.font = .systemFont(ofSize: 11)
        versionLabel.textColor = .tertiaryLabelColor
        versionLabel.translatesAutoresizingMaskIntoConstraints = false
        bar.addSubview(versionLabel)

        let done = NSButton(title: "Done", target: self, action: #selector(doneClicked))
        done.bezelStyle = .rounded
        done.keyEquivalent = "\r"
        done.translatesAutoresizingMaskIntoConstraints = false
        bar.addSubview(done)

        NSLayoutConstraint.activate([
            bar.heightAnchor.constraint(equalToConstant: 44),
            sep.topAnchor.constraint(equalTo: bar.topAnchor),
            sep.leadingAnchor.constraint(equalTo: bar.leadingAnchor),
            sep.trailingAnchor.constraint(equalTo: bar.trailingAnchor),
            hint.leadingAnchor.constraint(equalTo: bar.leadingAnchor, constant: 20),
            hint.centerYAnchor.constraint(equalTo: bar.centerYAnchor),
            versionLabel.leadingAnchor.constraint(equalTo: hint.trailingAnchor, constant: 12),
            versionLabel.centerYAnchor.constraint(equalTo: bar.centerYAnchor),
            done.trailingAnchor.constraint(equalTo: bar.trailingAnchor, constant: -20),
            done.centerYAnchor.constraint(equalTo: bar.centerYAnchor),
        ])

        return bar
    }

    // MARK: - Actions

    @objc private func modifierChanged(_ sender: NSButton) {
        guard let entry = modifierCheckboxes.first(where: { $0.button === sender }) else { return }

        if sender.state == .off {
            guard Self.isValidRemoval(current: config.cycle.modifierFlags, removing: entry.flag) else {
                sender.state = .on
                return
            }
            config.cycle.modifierFlags.remove(entry.flag)
        } else {
            config.cycle.modifierFlags.insert(entry.flag)
        }

        config.save()
        HotkeyManager.updateConfig(config.cycle)
        updateBindingLabels()
    }

    @objc private func displayModeChanged(_ sender: NSButton) {
        config.cycle.displayMode = sender.tag == 0 ? .listAndPreview : .previewOnly
        config.save()
        updateDisplayModeCards()
    }

    @objc private func listTriggerChanged(_ sender: NSButton) {
        config.listTrigger = sender.tag == 0 ? .click : .hover
        config.save()
    }

    @objc private func swatchClicked(_ sender: NSClickGestureRecognizer) {
        guard let swatch = sender.view,
              let index = colorSwatches.firstIndex(of: swatch),
              index < Self.presetColors.count else { return }
        let color = Self.presetColors[index].color
        config.bubbleColorHex = color.hexString
        config.save()
        updateSwatchSelection(index)
        onBubbleColorChanged?(color)
    }

    @objc private func customSwatchClicked(_ sender: NSClickGestureRecognizer) {
        let panel = NSColorPanel.shared
        panel.setTarget(self)
        panel.setAction(#selector(colorPanelChanged(_:)))
        panel.color = NSColor(hex: config.bubbleColorHex) ?? NSColor(white: 1.0, alpha: 1.0)
        ownsColorPanel = true
        panel.orderFront(nil)
    }

    @objc private func colorPanelChanged(_ sender: NSColorPanel) {
        let color = sender.color
        config.bubbleColorHex = color.hexString
        colorSaveWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.config.save() }
        colorSaveWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: work)
        let customIndex = colorSwatches.count - 1
        updateSwatchSelection(customIndex)
        colorSwatches[customIndex].layer?.sublayers?.first?.opacity = 0
        colorSwatches[customIndex].layer?.backgroundColor = color.cgColor
        onBubbleColorChanged?(color)
    }

    @objc private func openSystemSettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }

    private func cleanUpColorPanel() {
        if ownsColorPanel {
            let panel = NSColorPanel.shared
            panel.setTarget(nil)
            panel.setAction(nil)
            panel.orderOut(nil)
            ownsColorPanel = false
        }
    }

    @objc private func doneClicked() {
        cleanUpColorPanel()
        orderOut(nil)
    }

    public override func close() {
        cleanUpColorPanel()
        super.close()
    }

    // MARK: - Public API

    public func show() {
        config = FizzyConfig.load()
        let savedHex = config.bubbleColorHex
        selectedColorIndex = Self.presetColors.firstIndex(where: { $0.color.hexString == savedHex }) ?? -1
        if selectedColorIndex == -1 {
            updateSwatchSelection(colorSwatches.count - 1)
        } else {
            updateSwatchSelection(selectedColorIndex)
        }
        for entry in modifierCheckboxes {
            entry.button.state = config.cycle.modifierFlags.contains(entry.flag) ? .on : .off
        }
        updateBindingLabels()
        refreshPermissions()
        makeKeyAndOrderFront(nil)
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

    public static func isValidRemoval(current: CGEventFlags, removing: CGEventFlags) -> Bool {
        let known: CGEventFlags = [.maskCommand, .maskShift, .maskAlternate, .maskControl]
        return !current.subtracting(removing).intersection(known).isEmpty
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

// MARK: - Thumbnail drawing

private class ThumbnailView: NSView {
    enum Mode { case switcher, previewOnly }
    let mode: Mode

    init(mode: Mode) {
        self.mode = mode
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ dirtyRect: NSRect) {
        let bg = NSBezierPath(roundedRect: bounds, xRadius: 6, yRadius: 6)
        NSColor(white: 0.12, alpha: 1).setFill()
        bg.fill()

        switch mode {
        case .switcher: drawSwitcher()
        case .previewOnly: drawPreviewOnly()
        }
    }

    private func drawSwitcher() {
        drawPreviewOnly()

        let b = bounds
        let scale = min(b.width / 120, b.height / 70)
        let ox = (b.width - 120 * scale) / 2
        let oy = (b.height - 70 * scale) / 2

        func r(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> NSRect {
            NSRect(x: ox + x * scale, y: oy + (70 - y - h) * scale, width: w * scale, height: h * scale)
        }

        // Switcher row overlay — vertically centered
        let rowRect = r(6, 26, 108, 18)
        let row = NSBezierPath(roundedRect: rowRect, xRadius: 5 * scale, yRadius: 5 * scale)
        NSColor(white: 0.08, alpha: 0.85).setFill()
        row.fill()
        NSColor(white: 0.3, alpha: 0.4).setStroke()
        row.lineWidth = 0.5 * scale
        row.stroke()

        let cardXs: [CGFloat] = [12, 28, 44, 60, 76, 92]
        for (i, x) in cardXs.enumerated() {
            let cardRect = r(x, 29, 12, 12)
            let card = NSBezierPath(roundedRect: cardRect, xRadius: 2.5 * scale, yRadius: 2.5 * scale)
            if i == 1 {
                NSColor.systemCyan.withAlphaComponent(0.7).setFill()
                card.fill()
            }
            NSColor(white: 0.5, alpha: i == 1 ? 1 : 0.4).setStroke()
            card.lineWidth = 0.7 * scale
            card.stroke()
        }
    }

    private func drawPreviewOnly() {
        let b = bounds
        let scale = min(b.width / 120, b.height / 70)
        let ox = (b.width - 120 * scale) / 2
        let oy = (b.height - 70 * scale) / 2

        func r(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> NSRect {
            NSRect(x: ox + x * scale, y: oy + (70 - y - h) * scale, width: w * scale, height: h * scale)
        }

        // Terminal window
        let winRect = r(14, 6, 92, 58)
        let win = NSBezierPath(roundedRect: winRect, xRadius: 4 * scale, yRadius: 4 * scale)
        NSColor(white: 0.05, alpha: 1).setFill()
        win.fill()
        NSColor(white: 0.5, alpha: 0.25).setStroke()
        win.lineWidth = 0.6 * scale
        win.stroke()

        // Left pane (dim)
        let leftRect = r(16, 8, 42, 48)
        let left = NSBezierPath(roundedRect: leftRect, xRadius: 2 * scale, yRadius: 2 * scale)
        NSColor(white: 0.05, alpha: 0.7).setFill()
        left.fill()
        NSColor(white: 0.17, alpha: 1).setStroke()
        left.lineWidth = 0.6 * scale
        left.stroke()

        let leftLines: [(CGFloat, CGFloat, CGFloat)] = [
            (19, 13, 33), (19, 18, 27), (19, 23, 31),
            (19, 28, 23), (19, 33, 29), (19, 38, 17), (19, 43, 25),
        ]
        for (x, y, w) in leftLines {
            NSColor(white: 0.35, alpha: 0.6).setFill()
            NSBezierPath(rect: r(x, y, w, 1)).fill()
        }

        // Right pane (active — cyan border)
        let rightRect = r(59, 8, 45, 48)
        let right = NSBezierPath(roundedRect: rightRect, xRadius: 2 * scale, yRadius: 2 * scale)
        NSColor(white: 0.085, alpha: 1).setFill()
        right.fill()
        NSColor.systemCyan.setStroke()
        right.lineWidth = 1 * scale
        right.stroke()

        let rightLines: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
            (63, 13, 33, 1), (63, 18, 29, 0.7), (63, 23, 37, 1),
            (63, 28, 25, 0.6), (63, 33, 31, 0.5), (63, 38, 21, 0.55),
        ]
        for (x, y, w, alpha) in rightLines {
            let isGreen = y == 23
            let color = isGreen ? NSColor.systemGreen : NSColor(white: 0.9, alpha: alpha)
            color.setFill()
            NSBezierPath(rect: r(x, y, w, 1)).fill()
        }
        NSColor.systemGreen.setFill()
        NSBezierPath(rect: r(63, 47, 2.5, 3)).fill()

        // Status bar
        NSColor(white: 0.1, alpha: 1).setFill()
        NSBezierPath(rect: r(14, 57, 92, 7)).fill()
        NSColor.systemGreen.setFill()
        NSBezierPath(rect: r(59, 57, 22, 7)).fill()
        let fizzyStr = "[fizzy]" as NSString
        let fizzyAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 4 * scale, weight: .bold),
            .foregroundColor: NSColor(white: 0.05, alpha: 1),
        ]
        fizzyStr.draw(in: r(60, 57.5, 20, 6), withAttributes: fizzyAttrs)
    }
}
