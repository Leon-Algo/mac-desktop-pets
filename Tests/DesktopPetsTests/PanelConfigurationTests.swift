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

    func testFullClickThroughOverrideIgnoresMouseForEveryPanel() {
        let coordinator = PetWindowCoordinator(characters: CharacterCatalog.fallback.characters)
        coordinator.updateMouseAcceptance(at: CGPoint(x: 0, y: 0), fullyClickThrough: true)
        XCTAssertTrue(coordinator.allPanels.allSatisfy(\.ignoresMouseEvents))
    }

    func testPetViewDoesNotRequireSpriteKitDisplayLink() {
        XCTAssertFalse(PetSpriteView.requiresDisplayLink)
    }

    func testGlobalShowRestoresIndividuallyHiddenPet() {
        let coordinator = PetWindowCoordinator(characters: CharacterCatalog.fallback.characters)
        coordinator.show()
        coordinator.hide(identifier: "person-left")
        XCTAssertFalse(coordinator.allPanels.first { $0.petIdentifier == "person-left" }!.isVisible)

        coordinator.show()

        XCTAssertTrue(coordinator.allPanels.allSatisfy(\.isVisible))
        coordinator.hide()
    }

    func testControlCenterPlacementStaysInsideVisibleFrame() {
        let visibleFrame = NSRect(x: 100, y: 50, width: 1200, height: 800)
        let frame = ControlCenterPanelController.frame(in: visibleFrame)

        XCTAssertTrue(visibleFrame.contains(frame))
        XCTAssertEqual(frame.maxX, visibleFrame.maxX - 16, accuracy: 0.001)
        XCTAssertEqual(frame.maxY, visibleFrame.maxY - 16, accuracy: 0.001)
    }

    @MainActor
    func testControlPanelIsNonactivatingAvailableOnAllSpacesAndAccessible() {
        let controller = ControlCenterPanelController(menu: NSMenu())

        XCTAssertTrue(controller.panel.styleMask.contains(.nonactivatingPanel))
        XCTAssertTrue(controller.panel.styleMask.contains(.borderless))
        XCTAssertTrue(controller.panel.collectionBehavior.contains(.canJoinAllSpaces))
        XCTAssertTrue(controller.panel.collectionBehavior.contains(.fullScreenAuxiliary))
        XCTAssertEqual(controller.button.title, "🐾 总台")
        XCTAssertEqual(controller.button.accessibilityLabel(), "桌面伙伴总台")
        XCTAssertEqual(controller.panel.title, "桌面伙伴总台")
        XCTAssertFalse(controller.panel.canBecomeKey)
        XCTAssertFalse(controller.panel.canBecomeMain)
    }
}
