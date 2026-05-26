import XCTest
@testable import FizzyKit

final class SingleInstanceGuardTests: XCTestCase {
    func testNoBundleIdSkipsGuard() {
        let result = SingleInstanceGuard.shouldExit(bundleId: nil, otherInstanceCount: 5)
        XCTAssertFalse(result)
    }

    func testNoDuplicateAllowsLaunch() {
        let result = SingleInstanceGuard.shouldExit(bundleId: "xyz.cosense.fizzy", otherInstanceCount: 0)
        XCTAssertFalse(result)
    }

    func testDuplicateDetectedShouldExit() {
        let result = SingleInstanceGuard.shouldExit(bundleId: "xyz.cosense.fizzy", otherInstanceCount: 1)
        XCTAssertTrue(result)
    }

    func testNotificationName() {
        XCTAssertEqual(
            SingleInstanceGuard.activateNotificationName,
            NSNotification.Name("xyz.cosense.fizzy.activate")
        )
    }
}
