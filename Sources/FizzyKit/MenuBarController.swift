import AppKit

public final class MenuBarController {
    private var statusItem: NSStatusItem?
    public var onSettingsClicked: (() -> Void)?
    public let menu: NSMenu

    public init() {
        menu = NSMenu()
        menu.addItem(withTitle: "Fizzy — localhost:7319", action: nil, keyEquivalent: "")
        menu.addItem(.separator())
        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(settingsClicked), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        menu.addItem(withTitle: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
    }

    /// Registers the tray icon with NSStatusBar. Call this from the app delegate,
    /// not from tests (requires a live window server connection).
    public func install() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        let size = NSSize(width: 18, height: 22)
        let image = NSImage(size: size, flipped: true) { _ in
            let color = NSColor.controlTextColor

            let mainRect = NSRect(x: 3, y: 2, width: 12, height: 12)
            let mainPath = NSBezierPath(ovalIn: mainRect)
            color.withAlphaComponent(0.85).setStroke()
            mainPath.lineWidth = 1.5
            mainPath.stroke()

            let s1Rect = NSRect(x: 9.5, y: 15, width: 5, height: 5)
            let s1Path = NSBezierPath(ovalIn: s1Rect)
            color.withAlphaComponent(0.55).setStroke()
            s1Path.lineWidth = 1.2
            s1Path.stroke()

            let s2Rect = NSRect(x: 4.5, y: 17.5, width: 3, height: 3)
            let s2Path = NSBezierPath(ovalIn: s2Rect)
            color.withAlphaComponent(0.35).setStroke()
            s2Path.lineWidth = 1.0
            s2Path.stroke()

            return true
        }
        image.isTemplate = true
        item.button?.image = image
        item.menu = menu
        statusItem = item
    }

    @objc private func settingsClicked() {
        onSettingsClicked?()
    }
}
