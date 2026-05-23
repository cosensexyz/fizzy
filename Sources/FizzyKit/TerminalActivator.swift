import AppKit

enum TerminalActivator {
    static func activate(for item: NotificationItem) {
        let env = item.env
        let cwd = item.notification.cwd

        let app: NSRunningApplication?
        if let pid = env.terminalPid {
            app = NSRunningApplication(processIdentifier: pid_t(pid))
        } else {
            app = findTerminalFallback()
        }
        guard let app, !app.isTerminated else { return }
        let appName = app.localizedName

        DispatchQueue.global(qos: .userInitiated).async {
            if let pane = env.tmuxPane {
                selectTmuxPane(pane, socketPath: env.tmuxSocketPath)
            } else {
                let dirName = URL(fileURLWithPath: cwd).lastPathComponent
                if let appName {
                    raiseWindow(matching: dirName, appName: appName)
                }
            }

            DispatchQueue.main.async {
                app.activate(options: [])
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
