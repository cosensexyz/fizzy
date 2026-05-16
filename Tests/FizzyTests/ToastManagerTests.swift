import XCTest
@testable import FizzyKit

final class ToastManagerTests: XCTestCase {
    func testBestDirectionPicksMaxSpace() {
        let screenFrame = NSRect(x: 0, y: 0, width: 1440, height: 900)

        // Pet in top-right corner → most space is below
        let topRight = NSRect(x: 1350, y: 800, width: 80, height: 80)
        let dir1 = ToastManager.bestDirection(petFrame: topRight, screenFrame: screenFrame)
        XCTAssertEqual(dir1, .below)

        // Pet in bottom-left corner → most space is above
        let bottomLeft = NSRect(x: 10, y: 10, width: 80, height: 80)
        let dir2 = ToastManager.bestDirection(petFrame: bottomLeft, screenFrame: screenFrame)
        XCTAssertEqual(dir2, .above)

        // Pet centered → below wins (tie-break priority)
        let center = NSRect(x: 680, y: 410, width: 80, height: 80)
        let dir3 = ToastManager.bestDirection(petFrame: center, screenFrame: screenFrame)
        XCTAssertEqual(dir3, .below)
    }

    func testToastOriginStacksInDirection() {
        let screenFrame = NSRect(x: 0, y: 0, width: 1440, height: 900)
        let petFrame = NSRect(x: 1350, y: 800, width: 80, height: 80)
        let toastSize = NSSize(width: 260, height: 60)

        let origin0 = ToastManager.toastOrigin(
            petFrame: petFrame, screenFrame: screenFrame,
            toastSize: toastSize, index: 0, direction: .below
        )
        let origin1 = ToastManager.toastOrigin(
            petFrame: petFrame, screenFrame: screenFrame,
            toastSize: toastSize, index: 1, direction: .below
        )

        // First toast directly below pet
        XCTAssertEqual(origin0.y, petFrame.minY - toastSize.height - 8)
        // Second toast further below
        XCTAssertLessThan(origin1.y, origin0.y)
    }

    func testHorizontalStackingUsesWidth() {
        let screenFrame = NSRect(x: 0, y: 0, width: 1440, height: 900)
        let petFrame = NSRect(x: 100, y: 100, width: 80, height: 80)
        let toastSize = NSSize(width: 260, height: 60)

        let origin0 = ToastManager.toastOrigin(
            petFrame: petFrame, screenFrame: screenFrame,
            toastSize: toastSize, index: 0, direction: .right
        )
        let origin1 = ToastManager.toastOrigin(
            petFrame: petFrame, screenFrame: screenFrame,
            toastSize: toastSize, index: 1, direction: .right
        )

        // Toasts must not overlap: gap between them >= toast width
        XCTAssertGreaterThanOrEqual(origin1.x - origin0.x, toastSize.width)
    }
}
