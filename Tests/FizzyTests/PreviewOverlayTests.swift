import XCTest
@testable import FizzyKit

final class PreviewOverlayTests: XCTestCase {
    func testParseTmuxGeometry() {
        let output = "5 10 80 24 160 48"
        let geo = PreviewOverlay.parseTmuxGeometry(output)

        XCTAssertEqual(geo?.paneTop, 5)
        XCTAssertEqual(geo?.paneLeft, 10)
        XCTAssertEqual(geo?.paneWidth, 80)
        XCTAssertEqual(geo?.paneHeight, 24)
        XCTAssertEqual(geo?.windowWidth, 160)
        XCTAssertEqual(geo?.windowHeight, 48)
    }

    func testParseTmuxGeometryInvalidInput() {
        XCTAssertNil(PreviewOverlay.parseTmuxGeometry("bad input"))
        XCTAssertNil(PreviewOverlay.parseTmuxGeometry("1 2 3"))
        XCTAssertNil(PreviewOverlay.parseTmuxGeometry(""))
    }

    func testCalculatePaneRect() {
        let geo = PreviewOverlay.TmuxGeometry(
            paneTop: 0, paneLeft: 0, paneWidth: 80, paneHeight: 24,
            windowWidth: 80, windowHeight: 24
        )
        let terminalFrame = NSRect(x: 100, y: 200, width: 800, height: 600)
        let rect = PreviewOverlay.calculatePaneRect(geometry: geo, terminalFrame: terminalFrame)

        XCTAssertNotNil(rect)
        XCTAssertEqual(rect!.origin.x, 100, accuracy: 1)
        XCTAssertEqual(rect!.origin.y, 200, accuracy: 1)
        XCTAssertEqual(rect!.width, 800, accuracy: 1)
        XCTAssertEqual(rect!.height, 600, accuracy: 1)
    }

    func testCalculatePaneRectWithSplit() {
        let geo = PreviewOverlay.TmuxGeometry(
            paneTop: 0, paneLeft: 0, paneWidth: 80, paneHeight: 24,
            windowWidth: 161, windowHeight: 24
        )
        let terminalFrame = NSRect(x: 100, y: 200, width: 966, height: 600)
        let rect = PreviewOverlay.calculatePaneRect(geometry: geo, terminalFrame: terminalFrame)

        XCTAssertNotNil(rect)
        XCTAssertEqual(rect!.width, 966 * 80.0 / 161.0, accuracy: 1)
    }

    func testDimViewStoresPaneRect() {
        let view = DimView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        view.paneRect = NSRect(x: 100, y: 100, width: 200, height: 200)
        XCTAssertEqual(view.paneRect, NSRect(x: 100, y: 100, width: 200, height: 200))
    }
}
