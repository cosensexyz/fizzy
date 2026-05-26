import AppKit

enum TerminalActivator {
    private static let queue = DispatchQueue(label: "com.fizzy.terminal-activator")
    private static let scriptQueue = DispatchQueue(label: "com.fizzy.applescript")
    private static var _inPreview = false
    private static var _savedApp: NSRunningApplication?
    private static var _savedPaneId: String?
    private static var _savedPaneSocket: String?
    private static var _savedSessionName: String?
    private static var _savedTabBundleId: String?
    private static var _savedTabId: String?

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
        let bundleId = app.bundleIdentifier
        let pid = app.processIdentifier

        queue.async {

            if let pane = env.tmuxPane {
                if let bundleId {
                    _savedTabBundleId = bundleId
                    scriptQueue.async {
                        _savedTabId = queryCurrentTab(bundleId: bundleId)
                        selectTerminalTab(bundleId: bundleId, env: env, cwd: cwd)
                    }
                }
                _savedSessionName = currentTmuxSession(socketPath: env.tmuxSocketPath)
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
        let bundleId = app?.bundleIdentifier
        let pid = app?.processIdentifier ?? 0

        queue.async {
            if let pane = env.tmuxPane {
                if let bundleId {
                    scriptQueue.async {
                        selectTerminalTab(bundleId: bundleId, env: env, cwd: cwd)
                    }
                }
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

            if let bundleId = _savedTabBundleId, let tabId = _savedTabId {
                _savedTabBundleId = nil
                _savedTabId = nil
                scriptQueue.async {
                    restoreTerminalTab(bundleId: bundleId, tabId: tabId)
                }
            }
            if let sessionName = _savedSessionName {
                _savedSessionName = nil
                switchTmuxSession(sessionName, socketPath: _savedPaneSocket)
            }
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
            _savedSessionName = nil
            _savedTabBundleId = nil
            _savedTabId = nil
            _inPreview = false
            DispatchQueue.main.async {
                PreviewOverlay.hide()
            }
        }
    }

    static func activate(for item: NotificationItem) {
        guard let app = resolveTerminalApp(for: item) else { return }
        let appName = app.localizedName
        let bundleId = app.bundleIdentifier
        let env = item.env
        let cwd = item.notification.cwd
        let pid = app.processIdentifier

        queue.async {
            if let pane = env.tmuxPane {
                if let bundleId {
                    scriptQueue.async {
                        selectTerminalTab(bundleId: bundleId, env: env, cwd: cwd)
                    }
                }
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

    static let tmuxPath: String? = {
        for path in ["/usr/local/bin/tmux", "/opt/homebrew/bin/tmux"] {
            if FileManager.default.isExecutableFile(atPath: path) { return path }
        }
        return nil
    }()

    static func tmuxArgs(pane: String, socketPath: String?, command: String) -> [String] {
        var args = [String]()
        if let socket = socketPath {
            args += ["-S", socket]
        }
        args += [command, "-t", pane]
        return args
    }

    private static func selectTmuxPane(_ pane: String, socketPath: String?) {
        guard pane.range(of: #"^%\d+$"#, options: .regularExpression) != nil,
              let tmux = tmuxPath else { return }
        for command in ["select-window", "select-pane"] {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: tmux)
            process.arguments = tmuxArgs(pane: pane, socketPath: socketPath, command: command)
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            try? process.run()
            process.waitUntilExit()
        }
    }

    private static func switchTmuxSession(_ session: String, socketPath: String?) {
        guard let tmux = tmuxPath else { return }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tmux)
        var args = [String]()
        if let socket = socketPath {
            args += ["-S", socket]
        }
        args += ["switch-client", "-t", session]
        process.arguments = args
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try? process.run()
        process.waitUntilExit()
    }

    private static func tmuxQuery(socketPath: String?, format: String, validate: ((String) -> Bool)? = nil) -> String? {
        guard let tmux = tmuxPath else { return nil }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tmux)
        var args = [String]()
        if let socket = socketPath {
            args += ["-S", socket]
        }
        args += ["display-message", "-p", format]
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
              !output.isEmpty else { return nil }
        if let validate, !validate(output) { return nil }
        return output
    }

    private static func currentTmuxPane(socketPath: String?) -> String? {
        tmuxQuery(socketPath: socketPath, format: "#{pane_id}") {
            $0.range(of: #"^%\d+$"#, options: .regularExpression) != nil
        }
    }

    private static func currentTmuxSession(socketPath: String?) -> String? {
        tmuxQuery(socketPath: socketPath, format: "#{client_session}")
    }

    static func tabIndexForClientTty(_ targetTty: String, socketPath: String?) -> Int? {
        guard let tmux = tmuxPath else { return nil }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tmux)
        var args = [String]()
        if let socket = socketPath {
            args += ["-S", socket]
        }
        args += ["list-clients", "-F", "#{client_tty}"]
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
        // tmux list-clients returns clients in creation order, matching Ghostty's tab order.
        let ttys = output.split(separator: "\n").map(String.init)
        return Self.indexOfTty(targetTty, in: ttys)
    }

    static func indexOfTty(_ target: String, in ttys: [String]) -> Int? {
        guard let position = ttys.firstIndex(of: target) else { return nil }
        return position + 1
    }

    private static func raiseWindow(matching dirName: String, appName: String) {
        let safeDirName = sanitizeForAppleScript(dirName)
        let safeAppName = sanitizeForAppleScript(appName)

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

    static func tabSwitchScript(
        bundleId: String,
        sessionName: String?,
        clientTty: String?,
        dirName: String,
        tabIndex: Int? = nil
    ) -> String? {
        let matchName = sessionName ?? dirName
        let safeName = sanitizeForAppleScript(matchName)

        switch bundleId {
        case "com.mitchellh.ghostty":
            guard let index = tabIndex else { return nil }
            return """
            tell application "Ghostty"
                activate
                select tab (tab \(index) of front window)
            end tell
            """

        case "com.googlecode.iterm2":
            // Priority: sessionName > clientTty > dirName
            if let safeTty = clientTty.map(sanitizeForAppleScript), sessionName == nil {
                return """
                tell application "iTerm2"
                    activate
                    repeat with aWindow in windows
                        tell aWindow
                            repeat with aTab in tabs
                                repeat with aSession in sessions of aTab
                                    if tty of aSession is "\(safeTty)" then
                                        tell aTab to select
                                        select aWindow
                                        return
                                    end if
                                end repeat
                            end repeat
                        end tell
                    end repeat
                end tell
                """
            }
            return """
            tell application "iTerm2"
                activate
                repeat with aWindow in windows
                    tell aWindow
                        repeat with aTab in tabs
                            if name of current session of aTab contains "\(safeName)" then
                                tell aTab to select
                                select aWindow
                                return
                            end if
                        end repeat
                    end tell
                end repeat
            end tell
            """

        case "com.apple.Terminal":
            guard let safeTty = clientTty.map(sanitizeForAppleScript) else { return nil }
            return """
            tell application "Terminal"
                activate
                repeat with aWindow in windows
                    repeat with aTab in tabs of aWindow
                        if tty of aTab is "\(safeTty)" then
                            set selected of aTab to true
                            set index of aWindow to 1
                            return
                        end if
                    end repeat
                end repeat
            end tell
            """

        default:
            return nil
        }
    }

    private static func sanitizeForAppleScript(_ value: String) -> String {
        value
            .components(separatedBy: .newlines).joined()
            .components(separatedBy: .controlCharacters).joined()
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }

    static func currentTabScript(bundleId: String) -> String? {
        switch bundleId {
        case "com.mitchellh.ghostty":
            return """
            tell application "Ghostty"
                return (index of selected tab of front window) as text
            end tell
            """
        case "com.googlecode.iterm2":
            return """
            tell application "iTerm2"
                tell current window
                    set ct to current tab
                    repeat with i from 1 to count of tabs
                        if item i of tabs is ct then
                            return i as text
                        end if
                    end repeat
                end tell
            end tell
            """
        case "com.apple.Terminal":
            return """
            tell application "Terminal"
                return tty of selected tab of front window
            end tell
            """
        default:
            return nil
        }
    }

    static func tabRestoreScript(bundleId: String, tabId: String) -> String? {
        switch bundleId {
        case "com.mitchellh.ghostty":
            guard let index = Int(tabId) else { return nil }
            return """
            tell application "Ghostty"
                select tab (tab \(index) of front window)
            end tell
            """
        case "com.googlecode.iterm2":
            guard let index = Int(tabId) else { return nil }
            return """
            tell application "iTerm2"
                tell current window
                    select item \(index) of tabs
                end tell
            end tell
            """
        case "com.apple.Terminal":
            let safeTty = sanitizeForAppleScript(tabId)
            return """
            tell application "Terminal"
                repeat with aWindow in windows
                    repeat with aTab in tabs of aWindow
                        if tty of aTab is "\(safeTty)" then
                            set selected of aTab to true
                            set index of aWindow to 1
                            return
                        end if
                    end repeat
                end repeat
            end tell
            """
        default:
            return nil
        }
    }

    private static func queryCurrentTab(bundleId: String) -> String? {
        guard let script = currentTabScript(bundleId: bundleId),
              let appleScript = NSAppleScript(source: script) else { return nil }
        var error: NSDictionary?
        let result = appleScript.executeAndReturnError(&error)
        guard error == nil else { return nil }
        return result.stringValue
    }

    private static func restoreTerminalTab(bundleId: String, tabId: String) {
        guard let script = tabRestoreScript(bundleId: bundleId, tabId: tabId),
              let appleScript = NSAppleScript(source: script) else { return }
        appleScript.executeAndReturnError(nil)
    }

    private static func selectTerminalTab(bundleId: String, env: EnvironmentContext, cwd: String) {
        let dirName = URL(fileURLWithPath: cwd).lastPathComponent
        let tabIndex = env.tmuxClientTty.flatMap {
            tabIndexForClientTty($0, socketPath: env.tmuxSocketPath)
        }
        guard let script = tabSwitchScript(
            bundleId: bundleId,
            sessionName: env.tmuxSessionName,
            clientTty: env.tmuxClientTty,
            dirName: dirName,
            tabIndex: tabIndex
        ) else { return }
        guard let appleScript = NSAppleScript(source: script) else { return }
        appleScript.executeAndReturnError(nil)
    }
}
