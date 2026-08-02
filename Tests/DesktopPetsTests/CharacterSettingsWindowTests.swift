import XCTest
@testable import DesktopPets

@MainActor
final class CharacterSettingsWindowTests: XCTestCase {
    func testWindowShowsRosterPreviewAndEnforcesButtonLimits() throws {
        let controller = CharacterSettingsWindowController(roster: .default)

        XCTAssertEqual(controller.window?.title, "人物设置")
        XCTAssertEqual(controller.tableView.numberOfRows, 4)
        XCTAssertNotNil(controller.previewImageView.image)
        XCTAssertTrue(controller.addButton.isEnabled)
        XCTAssertTrue(controller.deleteButton.isEnabled)

        for _ in 0..<4 { controller.addCharacter(nil) }
        XCTAssertEqual(controller.tableView.numberOfRows, 8)
        XCTAssertFalse(controller.addButton.isEnabled)
    }

    func testControlsEditAndSaveValidatedRoster() throws {
        var saved: CharacterRoster?
        let controller = CharacterSettingsWindowController(roster: .default)
        controller.onSave = { saved = $0 }
        controller.nameField.stringValue = "  新橙仔  "
        controller.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification, object: controller.nameField))
        controller.personalityPopUp.selectItem(withTitle: "慵懒")
        controller.personalityChanged(controller.personalityPopUp)
        controller.save(nil)

        XCTAssertEqual(saved?.profiles[0].displayName, "新橙仔")
    }

    func testCancelDoesNotSaveDraft() {
        var saveCount = 0
        let controller = CharacterSettingsWindowController(roster: .default)
        controller.onSave = { _ in saveCount += 1 }
        controller.nameField.stringValue = "不要保存"
        controller.cancel(nil)
        XCTAssertEqual(saveCount, 0)
    }
}
