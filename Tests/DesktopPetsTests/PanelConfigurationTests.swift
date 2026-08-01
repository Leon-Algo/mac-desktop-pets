import AppKit
import XCTest
@testable import DesktopPets

@MainActor
final class PanelConfigurationTests: XCTestCase {
    func testPanelIsTransparentNonactivatingAndClickThrough() {
        let panel = PetPanel(identifier: "test", size: CGSize(width: 180, height: 160))

        XCTAssertFalse(panel.isOpaque)
        XCTAssertEqual(panel.backgroundColor, .clear)
        XCTAssertTrue(panel.styleMask.contains(.borderless))
        XCTAssertTrue(panel.styleMask.contains(.nonactivatingPanel))
        XCTAssertFalse(panel.canBecomeKey)
        XCTAssertFalse(panel.canBecomeMain)
        XCTAssertTrue(panel.ignoresMouseEvents)
        XCTAssertTrue(panel.collectionBehavior.contains(.canJoinAllSpaces))
    }

    func testCoordinatorCreatesFourStablePanelsAndMapsPoseToFrame() throws {
        let coordinator = PetWindowCoordinator(characters: CharacterCatalog.fallback.characters)
        XCTAssertEqual(coordinator.panelIdentifiers, ["person-left", "person-center-left", "person-center-right", "person-right"])

        let pose = PetPose(id: "person-left", position: WorldPoint(x: 300, y: 250), state: .crawl, facing: .right, phase: 0.25, supportID: nil)
        coordinator.apply(poses: [pose])

        let frame = try XCTUnwrap(coordinator.frame(for: "person-left"))
        XCTAssertEqual(frame.midX, 300, accuracy: 0.001)
        XCTAssertEqual(frame.minY, 230, accuracy: 0.001)
    }

    func testClickThroughCanBeToggledForEveryPanel() {
        let coordinator = PetWindowCoordinator(characters: CharacterCatalog.fallback.characters)
        coordinator.setClickThrough(false)
        XCTAssertTrue(coordinator.allPanels.allSatisfy { !$0.ignoresMouseEvents })
    }

    func testPetViewDoesNotRequireSpriteKitDisplayLink() {
        XCTAssertFalse(PetSpriteView.requiresDisplayLink)
    }
}
