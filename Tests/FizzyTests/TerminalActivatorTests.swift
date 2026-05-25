import XCTest
@testable import FizzyKit

final class TerminalActivatorTests: XCTestCase {
    func testFindTerminalFallbackReturnsSomethingOnDeveloperMachine() {
        let app = TerminalActivator.findTerminalFallback()
        if app != nil {
            XCTAssertFalse(app!.isTerminated)
        }
    }

    func testTmuxPathResolvesOnDeveloperMachine() {
        if let path = TerminalActivator.tmuxPath {
            XCTAssertTrue(FileManager.default.isExecutableFile(atPath: path))
        }
    }

    func testBuildTmuxArgsWithSocket() {
        let args = TerminalActivator.tmuxArgs(pane: "%3", socketPath: "/tmp/tmux-501/default", command: "select-window")
        XCTAssertEqual(args, ["-S", "/tmp/tmux-501/default", "select-window", "-t", "%3"])
    }

    func testBuildTmuxArgsWithoutSocket() {
        let args = TerminalActivator.tmuxArgs(pane: "%0", socketPath: nil, command: "select-pane")
        XCTAssertEqual(args, ["select-pane", "-t", "%0"])
    }

    func testResolveTerminalAppFallsBackWhenPidInvalid() {
        let item = NotificationItem(
            notification: GenericPayload(message: "test", cwd: "/tmp"),
            env: EnvironmentContext(terminalPid: 99999)
        )
        let app = TerminalActivator.resolveTerminalApp(for: item)
        XCTAssertEqual(app != nil, TerminalActivator.findTerminalFallback() != nil,
                       "Invalid PID must fall through to fallback chain")
    }

    func testResolveTerminalAppReturnsNilWhenNothingAvailable() {
        let item = NotificationItem(
            notification: GenericPayload(message: "test", cwd: "/tmp"),
            env: EnvironmentContext(terminalPid: 99999)
        )
        let app = TerminalActivator.resolveTerminalApp(for: item)
        if TerminalActivator.findTerminalFallback() == nil {
            XCTAssertNil(app)
        }
    }

    func testExitPreviewSafeWithoutPriorPreview() {
        TerminalActivator.exitPreview()
        XCTAssertFalse(TerminalActivator.inPreview)
    }

    func testEnterPreviewSetsInPreview() {
        let item = NotificationItem(
            notification: GenericPayload(message: "test", cwd: "/tmp"),
            env: EnvironmentContext(terminalPid: 99999)
        )
        if TerminalActivator.findTerminalFallback() != nil {
            XCTAssertTrue(TerminalActivator.enterPreview(for: item))
            XCTAssertTrue(TerminalActivator.inPreview)
            TerminalActivator.exitPreview()
        }
    }

    func testEnterPreviewRejectsReEntry() {
        let item = NotificationItem(
            notification: GenericPayload(message: "test", cwd: "/tmp"),
            env: EnvironmentContext(terminalPid: 99999)
        )
        if TerminalActivator.findTerminalFallback() != nil {
            XCTAssertTrue(TerminalActivator.enterPreview(for: item))
            XCTAssertFalse(TerminalActivator.enterPreview(for: item))
            TerminalActivator.exitPreview()
        }
    }

    func testClearPreviewStateResetsInPreview() {
        let item = NotificationItem(
            notification: GenericPayload(message: "test", cwd: "/tmp"),
            env: EnvironmentContext(terminalPid: 99999)
        )
        if TerminalActivator.findTerminalFallback() != nil {
            _ = TerminalActivator.enterPreview(for: item)
            TerminalActivator.clearPreviewState()
            XCTAssertFalse(TerminalActivator.inPreview)
        }
    }

    func testClearPreviewStateHidesOverlay() {
        guard NSScreen.main != nil else { return }
        addTeardownBlock { PreviewOverlay.hide() }

        PreviewOverlay.show(paneRect: NSRect(x: 100, y: 100, width: 400, height: 300))
        XCTAssertTrue(PreviewOverlay.isVisible)

        TerminalActivator.clearPreviewState()

        let hidden = XCTNSPredicateExpectation(
            predicate: NSPredicate(block: { _, _ in !PreviewOverlay.isVisible }),
            object: nil
        )
        wait(for: [hidden], timeout: 2.0)
    }

    func testTabScriptGhosttyMatchesByName() {
        let script = TerminalActivator.tabSwitchScript(
            bundleId: "com.mitchellh.ghostty",
            sessionName: "dev",
            clientTty: nil,
            dirName: "project"
        )
        XCTAssertNotNil(script)
        XCTAssertTrue(script!.contains("tell application \"Ghostty\""))
        XCTAssertTrue(script!.contains("name of t contains \"dev\""))
        XCTAssertTrue(script!.contains("select tab t"))
    }

    func testTabScriptGhosttyFallsToDirName() {
        let script = TerminalActivator.tabSwitchScript(
            bundleId: "com.mitchellh.ghostty",
            sessionName: nil,
            clientTty: nil,
            dirName: "fizzy"
        )
        XCTAssertNotNil(script)
        XCTAssertTrue(script!.contains("name of t contains \"fizzy\""))
    }

    func testTabScriptIterm2MatchesBySessionName() {
        let script = TerminalActivator.tabSwitchScript(
            bundleId: "com.googlecode.iterm2",
            sessionName: "work",
            clientTty: "/dev/ttys003",
            dirName: "project"
        )
        XCTAssertNotNil(script)
        XCTAssertTrue(script!.contains("tell application \"iTerm2\""))
        XCTAssertTrue(script!.contains("name of current session of aTab contains \"work\""))
    }

    func testTabScriptIterm2FallsToTty() {
        let script = TerminalActivator.tabSwitchScript(
            bundleId: "com.googlecode.iterm2",
            sessionName: nil,
            clientTty: "/dev/ttys007",
            dirName: "project"
        )
        XCTAssertNotNil(script)
        XCTAssertTrue(script!.contains("tty of aSession is \"/dev/ttys007\""))
    }

    func testTabScriptIterm2FallsToDirName() {
        let script = TerminalActivator.tabSwitchScript(
            bundleId: "com.googlecode.iterm2",
            sessionName: nil,
            clientTty: nil,
            dirName: "myproject"
        )
        XCTAssertNotNil(script)
        XCTAssertTrue(script!.contains("name of current session of aTab contains \"myproject\""))
    }

    func testTabScriptTerminalMatchesByTty() {
        let script = TerminalActivator.tabSwitchScript(
            bundleId: "com.apple.Terminal",
            sessionName: nil,
            clientTty: "/dev/ttys005",
            dirName: "project"
        )
        XCTAssertNotNil(script)
        XCTAssertTrue(script!.contains("tell application \"Terminal\""))
        XCTAssertTrue(script!.contains("tty of aTab is \"/dev/ttys005\""))
    }

    func testTabScriptTerminalReturnsNilWithoutTty() {
        let script = TerminalActivator.tabSwitchScript(
            bundleId: "com.apple.Terminal",
            sessionName: "dev",
            clientTty: nil,
            dirName: "project"
        )
        XCTAssertNil(script)
    }

    func testTabScriptUnknownBundleReturnsNil() {
        let script = TerminalActivator.tabSwitchScript(
            bundleId: "com.example.unknown",
            sessionName: "dev",
            clientTty: "/dev/ttys001",
            dirName: "project"
        )
        XCTAssertNil(script)
    }

    func testTabScriptEscapesSpecialCharacters() {
        let script = TerminalActivator.tabSwitchScript(
            bundleId: "com.mitchellh.ghostty",
            sessionName: "has\"quotes\\and\nnewlines",
            clientTty: nil,
            dirName: "project"
        )
        XCTAssertNotNil(script)
        XCTAssertTrue(script!.contains(#"has\"quotes\\and"#))
        XCTAssertFalse(script!.contains("\n\" then"))
    }

    // MARK: - currentTabScript

    func testCurrentTabScriptGhostty() {
        let script = TerminalActivator.currentTabScript(bundleId: "com.mitchellh.ghostty")
        XCTAssertNotNil(script)
        XCTAssertTrue(script!.contains("tell application \"Ghostty\""))
        XCTAssertTrue(script!.contains("index of selected tab of front window"))
    }

    func testCurrentTabScriptIterm2() {
        let script = TerminalActivator.currentTabScript(bundleId: "com.googlecode.iterm2")
        XCTAssertNotNil(script)
        XCTAssertTrue(script!.contains("tell application \"iTerm2\""))
        XCTAssertTrue(script!.contains("current tab"))
    }

    func testCurrentTabScriptTerminal() {
        let script = TerminalActivator.currentTabScript(bundleId: "com.apple.Terminal")
        XCTAssertNotNil(script)
        XCTAssertTrue(script!.contains("tell application \"Terminal\""))
        XCTAssertTrue(script!.contains("tty of selected tab"))
    }

    func testCurrentTabScriptUnknownReturnsNil() {
        XCTAssertNil(TerminalActivator.currentTabScript(bundleId: "com.example.unknown"))
    }

    // MARK: - tabRestoreScript

    func testTabRestoreScriptGhostty() {
        let script = TerminalActivator.tabRestoreScript(bundleId: "com.mitchellh.ghostty", tabId: "3")
        XCTAssertNotNil(script)
        XCTAssertTrue(script!.contains("tell application \"Ghostty\""))
        XCTAssertTrue(script!.contains("tab 3 of front window"))
    }

    func testTabRestoreScriptIterm2() {
        let script = TerminalActivator.tabRestoreScript(bundleId: "com.googlecode.iterm2", tabId: "2")
        XCTAssertNotNil(script)
        XCTAssertTrue(script!.contains("tell application \"iTerm2\""))
        XCTAssertTrue(script!.contains("item 2 of tabs"))
    }

    func testTabRestoreScriptTerminal() {
        let script = TerminalActivator.tabRestoreScript(bundleId: "com.apple.Terminal", tabId: "/dev/ttys005")
        XCTAssertNotNil(script)
        XCTAssertTrue(script!.contains("tell application \"Terminal\""))
        XCTAssertTrue(script!.contains("tty of aTab is \"/dev/ttys005\""))
    }

    func testTabRestoreScriptRejectsInvalidIndex() {
        XCTAssertNil(TerminalActivator.tabRestoreScript(bundleId: "com.mitchellh.ghostty", tabId: "not-a-number"))
        XCTAssertNil(TerminalActivator.tabRestoreScript(bundleId: "com.googlecode.iterm2", tabId: "abc"))
    }

    func testTabRestoreScriptUnknownReturnsNil() {
        XCTAssertNil(TerminalActivator.tabRestoreScript(bundleId: "com.example.unknown", tabId: "1"))
    }
}
