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

    @MainActor
    func testPetContextMenuContainsGlobalRecoveryControlCenterAndQuit() throws {
        let view = PetSpriteView(
            frame: NSRect(x: 0, y: 0, width: 180, height: 160),
            character: CharacterCatalog.fallback.characters[0]
        )
        let event = try XCTUnwrap(NSEvent.mouseEvent(
            with: .rightMouseDown,
            location: .zero,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            eventNumber: 1,
            clickCount: 1,
            pressure: 0
        ))

        let titles = try XCTUnwrap(view.menu(for: event)).items.map(\.title)
        XCTAssertTrue(titles.contains("召回四人"))
        XCTAssertTrue(titles.contains("打开总台"))
        XCTAssertTrue(titles.contains("退出桌面伙伴"))
    }
}
