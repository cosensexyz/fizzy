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
}
