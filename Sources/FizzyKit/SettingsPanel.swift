// Sources/FizzyKit/SettingsPanel.swift
import AppKit
import CoreGraphics

public final class SettingsPanel: NSPanel {
    public enum PermissionStatus: String, Equatable {
        case granted, denied, notAsked, notRunning
    }

    private var permissionRows: NSStackView!

    public init() {
        let size = NSSize(width: 400, height: 600)
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
        backgroundColor = NSColor.windowBackgroundColor
        level = .floating

        setupUI()
    }

    private func setupUI() {
        let container = NSStackView()
        container.orientation = .vertical
        container.alignment = .leading
        container.spacing = 16
        container.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)

        // Display mode section
        let modeHeader = NSTextField(labelWithString: "Display Mode")
        modeHeader.font = .systemFont(ofSize: 13, weight: .semibold)

        let config = CycleConfig.load()

        let listAndPreviewRadio = NSButton(radioButtonWithTitle: "Switcher + Preview", target: self, action: #selector(displayModeChanged(_:)))
        listAndPreviewRadio.tag = 0

        let previewOnlyRadio = NSButton(radioButtonWithTitle: "Preview Only", target: self, action: #selector(displayModeChanged(_:)))
        previewOnlyRadio.tag = 1

        if config.displayMode == .listAndPreview {
            listAndPreviewRadio.state = .on
        } else {
            previewOnlyRadio.state = .on
        }

        // Permissions section
        let permHeader = NSTextField(labelWithString: "Permissions")
        permHeader.font = .systemFont(ofSize: 13, weight: .semibold)

        permissionRows = NSStackView()
        permissionRows.orientation = .vertical
        permissionRows.alignment = .leading
        permissionRows.spacing = 8

        let separator1 = NSBox()
        separator1.boxType = .separator

        let separator2 = NSBox()
        separator2.boxType = .separator

        let openSettingsButton = NSButton(title: "Open System Settings", target: self, action: #selector(openSystemSettings))
        openSettingsButton.bezelStyle = .rounded

        // Key bindings section (read-only)
        let bindingsHeader = NSTextField(labelWithString: "Key Bindings (while cycling)")
        bindingsHeader.font = .systemFont(ofSize: 13, weight: .semibold)

        let bindings: [(String, String)] = [
            ("→  Right Arrow", "Cycle forward"),
            ("←  Left Arrow", "Cycle backward"),
            ("↓  Down Arrow", "Confirm selection"),
            ("↑  Up Arrow", "Cancel"),
            ("Release modifiers", "Confirm selection"),
        ]

        let bindingsStack = NSStackView()
        bindingsStack.orientation = .vertical
        bindingsStack.alignment = .leading
        bindingsStack.spacing = 4

        for (key, action) in bindings {
            let row = NSStackView()
            row.orientation = .horizontal
            row.spacing = 12
            let keyLabel = NSTextField(labelWithString: key)
            keyLabel.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
            keyLabel.textColor = .labelColor
            keyLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)
            let actionLabel = NSTextField(labelWithString: action)
            actionLabel.font = .systemFont(ofSize: 11)
            actionLabel.textColor = .secondaryLabelColor
            row.addArrangedSubview(keyLabel)
            row.addArrangedSubview(actionLabel)
            bindingsStack.addArrangedSubview(row)
        }

        let separator3 = NSBox()
        separator3.boxType = .separator

        container.addArrangedSubview(bindingsHeader)
        container.addArrangedSubview(bindingsStack)
        container.addArrangedSubview(separator3)
        container.addArrangedSubview(modeHeader)
        container.addArrangedSubview(listAndPreviewRadio)
        container.addArrangedSubview(previewOnlyRadio)
        container.addArrangedSubview(separator1)
        container.addArrangedSubview(permHeader)
        container.addArrangedSubview(permissionRows)
        container.addArrangedSubview(separator2)
        container.addArrangedSubview(openSettingsButton)

        contentView = container
    }

    public func show() {
        refreshPermissions()
        orderFront(nil)
    }

    @objc private func displayModeChanged(_ sender: NSButton) {
        var config = CycleConfig.load()
        config.displayMode = sender.tag == 0 ? .listAndPreview : .previewOnly
        config.save()
    }

    @objc private func openSystemSettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }

    // MARK: - Permissions

    private func refreshPermissions() {
        permissionRows.arrangedSubviews.forEach { $0.removeFromSuperview() }

        let accessStatus: PermissionStatus = AXIsProcessTrusted() ? .granted : .denied
        permissionRows.addArrangedSubview(makePermissionRow(
            name: "Accessibility", description: "Global keyboard shortcut", status: accessStatus
        ))

        let targets: [(String, String, String)] = [
            ("System Events", "com.apple.systemevents", "Raise terminal window"),
            ("Ghostty", "com.mitchellh.ghostty", "Switch terminal tabs"),
            ("iTerm2", "com.googlecode.iterm2", "Switch terminal tabs"),
            ("Terminal", "com.apple.Terminal", "Switch terminal tabs"),
        ]

        for (name, bundleId, desc) in targets {
            let status = checkAutomationPermission(bundleId: bundleId)
            permissionRows.addArrangedSubview(makePermissionRow(
                name: name, description: desc, status: status
            ))
        }
    }

    private func checkAutomationPermission(bundleId: String) -> PermissionStatus {
        let target = NSAppleEventDescriptor(bundleIdentifier: bundleId)
        guard let aeDesc = target.aeDesc else { return .notRunning }
        let status = AEDeterminePermissionToAutomateTarget(aeDesc, typeWildCard, typeWildCard, false)
        return Self.permissionStatus(for: status)
    }

    private func makePermissionRow(name: String, description: String, status: PermissionStatus) -> NSView {
        let row = NSStackView()
        row.orientation = .vertical
        row.spacing = 2

        let topRow = NSStackView()
        topRow.orientation = .horizontal
        topRow.spacing = 8

        let dot = NSView(frame: NSRect(x: 0, y: 0, width: 8, height: 8))
        dot.wantsLayer = true
        dot.layer?.cornerRadius = 4
        dot.layer?.backgroundColor = statusColor(status).cgColor
        dot.translatesAutoresizingMaskIntoConstraints = false
        dot.widthAnchor.constraint(equalToConstant: 8).isActive = true
        dot.heightAnchor.constraint(equalToConstant: 8).isActive = true

        let nameLabel = NSTextField(labelWithString: name)
        nameLabel.font = .systemFont(ofSize: 12)

        let statusLabel = NSTextField(labelWithString: status.rawValue.capitalized)
        statusLabel.font = .systemFont(ofSize: 12)
        statusLabel.textColor = .secondaryLabelColor

        topRow.addArrangedSubview(dot)
        topRow.addArrangedSubview(nameLabel)
        topRow.addArrangedSubview(statusLabel)

        let descLabel = NSTextField(labelWithString: "  \(description)")
        descLabel.font = .systemFont(ofSize: 11)
        descLabel.textColor = .tertiaryLabelColor

        row.addArrangedSubview(topRow)
        row.addArrangedSubview(descLabel)
        return row
    }

    private func statusColor(_ status: PermissionStatus) -> NSColor {
        switch status {
        case .granted: return .systemGreen
        case .denied: return .systemRed
        case .notAsked: return .systemYellow
        case .notRunning: return .systemGray
        }
    }

    // MARK: - Public helpers (testable)

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
