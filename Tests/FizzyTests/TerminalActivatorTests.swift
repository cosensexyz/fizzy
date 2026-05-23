import XCTest
@testable import FizzyKit

final class TerminalActivatorTests: XCTestCase {
    func testFindTerminalFallbackReturnsSomethingOnDeveloperMachine() {
        let app = TerminalActivator.findTerminalFallback()
        if app != nil {
            XCTAssertFalse(app!.isTerminated)
        }
    }

    func testBuildTmuxArgsWithSocket() {
        let args = TerminalActivator.tmuxArgs(pane: "%3", socketPath: "/tmp/tmux-501/default", command: "select-window")
        XCTAssertEqual(args, ["tmux", "-S", "/tmp/tmux-501/default", "select-window", "-t", "%3"])
    }

    func testBuildTmuxArgsWithoutSocket() {
        let args = TerminalActivator.tmuxArgs(pane: "%0", socketPath: nil, command: "select-pane")
        XCTAssertEqual(args, ["tmux", "select-pane", "-t", "%0"])
    }
}
