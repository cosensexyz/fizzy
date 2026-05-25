import AppKit

enum TerminalActivator {
    private static let queue = DispatchQueue(label: "com.fizzy.terminal-activator")
    private static var _inPreview = false
    private static var _savedApp: NSRunningApplication?
    private static var _savedPaneId: String?
    private static var _savedPaneSocket: String?

    static var inPreview: Bool {
        queue.sync { _inPreview }
    }

    static func resolveTerminalApp(for item: NotificationItem) -> NSRunningApplication? {
        if let pid = item.env.terminalPid,
           let app = NSRunningApplication(processIdentifier: pid_t(pid)),
           !app.isTerminated {
            return app
        }
        guard let app = findTerminalFallback(), !app.isTerminated else { return nil }
        return app
    }

    @discardableResult
    static func enterPreview(for item: NotificationItem) -> Bool {
        guard let app = resolveTerminalApp(for: item) else { return false }

        let frontmost = NSWorkspace.shared.frontmostApplication
        let entered = queue.sync { () -> Bool in
            guard !_inPreview else { return false }
            _inPreview = true
            _savedApp = frontmost
            return true
        }
        guard entered else { return false }

        let env = item.env
        let cwd = item.notification.cwd
        let appName = app.localizedName
        let pid = app.processIdentifier

        queue.async {

            if let pane = env.tmuxPane {
                _savedPaneId = currentTmuxPane(socketPath: env.tmuxSocketPath)
                _savedPaneSocket = env.tmuxSocketPath
                selectTmuxPane(pane, socketPath: env.tmuxSocketPath)
            } else {
                let dirName = URL(fileURLWithPath: cwd).lastPathComponent
                if let appName {
                    raiseWindow(matching: dirName, appName: appName)
                }
            }
            let paneRect = PreviewOverlay.resolvePaneRect(for: item, pid: pid)
            DispatchQueue.main.async {
                guard queue.sync(execute: { _inPreview }) else { return }
                NSRunningApplication(processIdentifier: pid)?.activate(options: [])
                if let paneRect { PreviewOverlay.show(paneRect: paneRect) }
            }
        }
        return true
    }

    static func switchPreview(to item: NotificationItem) {
        let env = item.env
        let cwd = item.notification.cwd
        let app = resolveTerminalApp(for: item)
        let appName = app?.localizedName
        let pid = app?.processIdentifier ?? 0

        queue.async {
            if let pane = env.tmuxPane {
                selectTmuxPane(pane, socketPath: env.tmuxSocketPath)
            } else {
                let dirName = URL(fileURLWithPath: cwd).lastPathComponent
                if let appName {
                    raiseWindow(matching: dirName, appName: appName)
                }
            }
            let paneRect = PreviewOverlay.resolvePaneRect(for: item, pid: pid)
            DispatchQueue.main.async {
                if let paneRect { PreviewOverlay.update(paneRect: paneRect) }
            }
        }
    }

    static func exitPreview() {
        queue.async {
            guard _inPreview else { return }
            let appToRestore = _savedApp
            _savedApp = nil
            _inPreview = false

            if let paneId = _savedPaneId {
                selectTmuxPane(paneId, socketPath: _savedPaneSocket)
                _savedPaneId = nil
                _savedPaneSocket = nil
            }
            DispatchQueue.main.async {
                PreviewOverlay.hide()
                appToRestore?.activate(options: [])
            }
        }
    }

    static func clearPreviewState() {
        queue.async {
            _savedApp = nil
            _savedPaneId = nil
            _savedPaneSocket = nil
            _inPreview = false
            DispatchQueue.main.async {
                PreviewOverlay.hide()
            }
        }
    }

    static func activate(for item: NotificationItem) {
        guard let app = resolveTerminalApp(for: item) else { return }
        let appName = app.localizedName
        let env = item.env
        let cwd = item.notification.cwd
        let pid = app.processIdentifier

        queue.async {
            if let pane = env.tmuxPane {
                selectTmuxPane(pane, socketPath: env.tmuxSocketPath)
            } else {
                let dirName = URL(fileURLWithPath: cwd).lastPathComponent
                if let appName {
                    raiseWindow(matching: dirName, appName: appName)
                }
            }

            DispatchQueue.main.async {
                NSRunningApplication(processIdentifier: pid)?.activate(options: [])
            }
        }
    }

    static func findTerminalFallback() -> NSRunningApplication? {
        let bundleIds = [
            "com.mitchellh.ghostty",
            "com.googlecode.iterm2",
            "com.apple.Terminal",
        ]
        let running = NSWorkspace.shared.runningApplications
        for bundleId in bundleIds {
            if let app = running.first(where: { $0.bundleIdentifier == bundleId && !$0.isTerminated }) {
                return app
            }
        }
        return nil
    }

    static func tmuxArgs(pane: String, socketPath: String?, command: String) -> [String] {
        var args = ["tmux"]
        if let socket = socketPath {
            args += ["-S", socket]
        }
        args += [command, "-t", pane]
        return args
    }

    private static func selectTmuxPane(_ pane: String, socketPath: String?) {
        guard pane.range(of: #"^%\d+$"#, options: .regularExpression) != nil else { return }
        for command in ["select-window", "select-pane"] {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = tmuxArgs(pane: pane, socketPath: socketPath, command: command)
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            try? process.run()
            process.waitUntilExit()
        }
    }

    private static func currentTmuxPane(socketPath: String?) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        var args = ["tmux"]
        if let socket = socketPath {
            args += ["-S", socket]
        }
        args += ["display-message", "-p", "#{pane_id}"]
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
        guard let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
              output.range(of: #"^%\d+$"#, options: .regularExpression) != nil else { return nil }
        return output
    }

    private static func raiseWindow(matching dirName: String, appName: String) {
        let safeDirName = dirName
            .components(separatedBy: .newlines).joined()
            .components(separatedBy: .controlCharacters).joined()
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let safeAppName = appName
            .components(separatedBy: .newlines).joined()
            .components(separatedBy: .controlCharacters).joined()
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")

        let script = """
        tell application "System Events"
            tell process "\(safeAppName)"
                repeat with w in windows
                    if name of w contains "\(safeDirName)" then
                        perform action "AXRaise" of w
                        exit repeat
                    end if
                end repeat
            end tell
        end tell
        """

        guard let appleScript = NSAppleScript(source: script) else { return }
        appleScript.executeAndReturnError(nil)
    }
}
