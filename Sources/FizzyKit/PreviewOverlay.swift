import AppKit

final class DimView: NSView {
    var paneRect: NSRect = .zero {
        didSet { needsDisplay = true }
    }

    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(rect: bounds)
        path.append(NSBezierPath(rect: paneRect))
        path.windingRule = .evenOdd
        NSColor.black.withAlphaComponent(0.4).setFill()
        path.fill()

        NSColor.cyan.setStroke()
        let border = NSBezierPath(rect: paneRect)
        border.lineWidth = 3
        border.stroke()
    }
}

enum PreviewOverlay {
    struct TmuxGeometry {
        let paneTop: Int
        let paneLeft: Int
        let paneWidth: Int
        let paneHeight: Int
        let windowWidth: Int
        let windowHeight: Int
    }

    private static var overlayWindow: NSWindow?
    private static var dimView: DimView?

    static var isVisible: Bool {
        overlayWindow?.isVisible ?? false
    }

    static func parseTmuxGeometry(_ output: String) -> TmuxGeometry? {
        let parts = output.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: " ")
        guard parts.count == 6,
              let paneTop = Int(parts[0]),
              let paneLeft = Int(parts[1]),
              let paneWidth = Int(parts[2]),
              let paneHeight = Int(parts[3]),
              let windowWidth = Int(parts[4]),
              let windowHeight = Int(parts[5]) else { return nil }
        return TmuxGeometry(
            paneTop: paneTop, paneLeft: paneLeft,
            paneWidth: paneWidth, paneHeight: paneHeight,
            windowWidth: windowWidth, windowHeight: windowHeight
        )
    }

    static func calculatePaneRect(geometry geo: TmuxGeometry, terminalFrame: NSRect) -> NSRect? {
        guard geo.windowWidth > 0, geo.windowHeight > 0 else { return nil }
        let cellWidth = terminalFrame.width / CGFloat(geo.windowWidth)
        let cellHeight = terminalFrame.height / CGFloat(geo.windowHeight)

        let paneX = terminalFrame.origin.x + CGFloat(geo.paneLeft) * cellWidth
        let paneY = terminalFrame.origin.y + terminalFrame.height
            - CGFloat(geo.paneTop + geo.paneHeight) * cellHeight
        let paneW = CGFloat(geo.paneWidth) * cellWidth
        let paneH = CGFloat(geo.paneHeight) * cellHeight

        return NSRect(x: paneX, y: paneY, width: paneW, height: paneH)
    }

    static func queryTerminalFrame(pid: pid_t) -> NSRect? {
        guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else { return nil }
        for entry in list {
            guard let ownerPID = entry[kCGWindowOwnerPID as String] as? pid_t,
                  ownerPID == pid,
                  let boundsDict = entry[kCGWindowBounds as String] as? NSDictionary else { continue }
            var cgRect = CGRect.zero
            guard CGRectMakeWithDictionaryRepresentation(boundsDict as CFDictionary, &cgRect),
                  cgRect.width > 100, cgRect.height > 100 else { continue }
            let screenHeight = NSScreen.main?.frame.height ?? 0
            return NSRect(x: cgRect.origin.x, y: screenHeight - cgRect.origin.y - cgRect.height,
                          width: cgRect.width, height: cgRect.height)
        }
        return nil
    }

    static func queryTmuxGeometry(pane: String, socketPath: String?) -> TmuxGeometry? {
        guard pane.range(of: #"^%\d+$"#, options: .regularExpression) != nil,
              let tmux = TerminalActivator.tmuxPath else { return nil }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tmux)
        var args = [String]()
        if let socket = socketPath {
            args += ["-S", socket]
        }
        args += ["display-message", "-t", pane, "-p",
                 "#{pane_top} #{pane_left} #{pane_width} #{pane_height} #{window_width} #{window_height}"]
        process.arguments = args
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return nil
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return nil }
        return parseTmuxGeometry(output)
    }

    static func resolveRect(terminalFrame: NSRect, tmuxPaneRect: NSRect?) -> NSRect {
        tmuxPaneRect ?? terminalFrame
    }

    static func resolvePaneRect(for item: NotificationItem, pid: pid_t) -> NSRect? {
        guard let terminalFrame = queryTerminalFrame(pid: pid) else { return nil }
        let tmuxPaneRect: NSRect? = item.env.tmuxPane.flatMap { pane in
            queryTmuxGeometry(pane: pane, socketPath: item.env.tmuxSocketPath)
                .flatMap { calculatePaneRect(geometry: $0, terminalFrame: terminalFrame) }
        }
        return resolveRect(terminalFrame: terminalFrame, tmuxPaneRect: tmuxPaneRect)
    }

    private static func localPaneRect(_ paneRect: NSRect, in screenFrame: NSRect) -> NSRect {
        NSRect(
            x: paneRect.origin.x - screenFrame.origin.x,
            y: paneRect.origin.y - screenFrame.origin.y,
            width: paneRect.width,
            height: paneRect.height
        )
    }

    static func show(paneRect: NSRect) {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.frame

        let window: NSWindow
        if let existing = overlayWindow {
            window = existing
        } else {
            window = NSWindow(
                contentRect: screenFrame,
                styleMask: .borderless,
                backing: .buffered,
                defer: false
            )
            window.isOpaque = false
            window.backgroundColor = .clear
            window.level = NSWindow.Level(rawValue: NSWindow.Level.floating.rawValue - 1)
            window.collectionBehavior = [.canJoinAllSpaces, .stationary]
            window.ignoresMouseEvents = true
            window.hasShadow = false
            overlayWindow = window
        }

        window.setFrame(screenFrame, display: false)

        let view: DimView
        if let existing = dimView {
            view = existing
            view.frame = NSRect(origin: .zero, size: screenFrame.size)
        } else {
            view = DimView(frame: NSRect(origin: .zero, size: screenFrame.size))
            dimView = view
            window.contentView = view
        }

        view.paneRect = localPaneRect(paneRect, in: screenFrame)
        window.orderFront(nil)
    }

    static func update(paneRect: NSRect) {
        guard let window = overlayWindow, let view = dimView else { return }
        view.paneRect = localPaneRect(paneRect, in: window.frame)
    }

    static func hide() {
        overlayWindow?.orderOut(nil)
    }
}
