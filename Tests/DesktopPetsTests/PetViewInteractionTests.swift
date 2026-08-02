import AppKit
import XCTest
@testable import DesktopPets

final class PetViewInteractionTests: XCTestCase {
    func testAlphaMaskAcceptsOpaquePixelAndRejectsTransparentPixels() {
        let mask = PetAlphaMask(width: 2, height: 2, alpha: [0, 255, 255, 0])

        XCTAssertFalse(mask.containsOpaquePixel(normalizedPoint: CGPoint(x: 0.25, y: 0.25)))
        XCTAssertTrue(mask.containsOpaquePixel(normalizedPoint: CGPoint(x: 0.75, y: 0.25)))
        XCTAssertFalse(mask.containsOpaquePixel(normalizedPoint: CGPoint(x: 1.1, y: 0.5)))
    }

    func testSecondClickCancelsPendingSingleAndEmitsDouble() {
        var interpreter = ClickInterpreter()
        let first = interpreter.register(clickCount: 1)
        let second = interpreter.register(clickCount: 2)

        guard case let .scheduleSingle(token) = first else {
            return XCTFail("First click must schedule a delayed single")
        }
        XCTAssertEqual(second, .emitDouble)
        XCTAssertFalse(interpreter.resolveSingle(token: token))
    }

    func testUninterruptedSingleClickResolvesOnce() {
        var interpreter = ClickInterpreter()
        guard case let .scheduleSingle(token) = interpreter.register(clickCount: 1) else {
            return XCTFail("Expected delayed single click")
        }

        XCTAssertTrue(interpreter.resolveSingle(token: token))
        XCTAssertFalse(interpreter.resolveSingle(token: token))
    }
}
