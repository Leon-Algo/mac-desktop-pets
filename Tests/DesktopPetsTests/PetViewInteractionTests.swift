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
        XCTAssertTrue(titles.contains("召回全部人物"))
        XCTAssertTrue(titles.contains("打开总台"))
        XCTAssertTrue(titles.contains("退出桌面伙伴"))
    }

    @MainActor
    func testPetContextMenuExposesTypedDiscoverableActions() throws {
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
        let menu = try XCTUnwrap(view.menu(for: event))
        let actions = try XCTUnwrap(menu.items.first { $0.title == "让他做动作…" }?.submenu)
        XCTAssertEqual(actions.items.map(\.title), PetActionCatalog.individual.map(\.title))
        XCTAssertEqual(
            actions.items.compactMap { $0.representedObject as? PetActionRequest },
            PetActionCatalog.individual.map {
                PetActionRequest(actionID: $0.id, targetID: "person-left")
            }
        )
        XCTAssertFalse(menu.items.contains { $0.title == "做个动作" })

        var received: PetInteraction?
        view.interactionHandler = { received = $0 }
        view.performContextAction(actions.items[0])
        XCTAssertEqual(received, .performAction(PetActionRequest(actionID: .wave, targetID: "person-left")))
    }

    @MainActor
    func testRollUsesDistinctHalfTurnAndFeedbackStaysReadableAtQuarterScale() {
        let view = PetSpriteView(
            frame: NSRect(x: 0, y: 0, width: 180, height: 160),
            character: CharacterCatalog.fallback.characters[0]
        )
        view.apply(PetPose(
            id: "person-left",
            position: WorldPoint(x: 0, y: 0),
            state: .roll,
            facing: .right,
            phase: 0.5,
            supportID: nil
        ))
        XCTAssertEqual(abs(view.currentPetTransform.a), 1, accuracy: 0.08)
        XCTAssertEqual(view.currentPetTransform.d, -1, accuracy: 0.08)

        view.setRenderScale(0.25)
        view.showFeedback(message: "第一条", duration: 10)
        view.showFeedback(message: "第二条", duration: 10)
        XCTAssertEqual(view.activeFeedbackText, "第二条")
        XCTAssertGreaterThanOrEqual(view.feedbackFontSize, 11)
    }
}
