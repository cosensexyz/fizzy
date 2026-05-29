import XCTest
@testable import FizzyKit

final class NSColorHexTests: XCTestCase {
    func testWhiteToHex() {
        let color = NSColor(white: 1.0, alpha: 1.0)
        XCTAssertEqual(color.hexString, "#FFFFFF")
    }

    func testBlackToHex() {
        let color = NSColor(red: 0, green: 0, blue: 0, alpha: 1)
        XCTAssertEqual(color.hexString, "#000000")
    }

    func testHexToColor() {
        let color = NSColor(hex: "#FF8000")!
        let rgb = color.usingColorSpace(.sRGB)!
        XCTAssertEqual(rgb.redComponent, 1.0, accuracy: 0.01)
        XCTAssertEqual(rgb.greenComponent, 0.5, accuracy: 0.01)
        XCTAssertEqual(rgb.blueComponent, 0.0, accuracy: 0.01)
    }

    func testRoundTrip() {
        let original = NSColor(red: 0.2, green: 0.6, blue: 0.8, alpha: 1)
        let hex = original.hexString
        let restored = NSColor(hex: hex)!
        let a = original.usingColorSpace(.sRGB)!
        let b = restored.usingColorSpace(.sRGB)!
        XCTAssertEqual(a.redComponent, b.redComponent, accuracy: 0.01)
        XCTAssertEqual(a.greenComponent, b.greenComponent, accuracy: 0.01)
        XCTAssertEqual(a.blueComponent, b.blueComponent, accuracy: 0.01)
    }

    func testInvalidHexReturnsNil() {
        XCTAssertNil(NSColor(hex: "not-a-color"))
        XCTAssertNil(NSColor(hex: "#GG0000"))
        XCTAssertNil(NSColor(hex: "#FF"))
    }
}
