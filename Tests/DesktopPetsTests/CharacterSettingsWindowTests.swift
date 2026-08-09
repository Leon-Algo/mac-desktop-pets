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
        XCTAssertEqual(controller.tableView.selectedRow, 7)
        XCTAssertEqual(controller.nameField.stringValue, "新人物 8")
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

    func testLegacyAvatarIsDescribedAsCurrentOriginalInsteadOfBuiltInPreset() {
        let legacy = CharacterRoster.legacy(from: CharacterCatalog.fallback.characters)
        let controller = CharacterSettingsWindowController(roster: legacy)
        XCTAssertEqual(controller.avatarPopUp.titleOfSelectedItem, "当前：原头像")
    }

    func testAvatarCropEditorProvidesZoomPositionPreviewAndActions() throws {
        let source = NSImage(size: NSSize(width: 120, height: 80))
        source.lockFocus(); NSColor.systemOrange.setFill(); NSRect(x: 0, y: 0, width: 120, height: 80).fill(); source.unlockFocus()
        let editor = try AvatarCropWindowController(imageData: XCTUnwrap(source.tiffRepresentation))

        XCTAssertEqual(editor.window?.title, "调整头像")
        XCTAssertEqual(editor.zoomSlider.minValue, 1)
        XCTAssertEqual(editor.zoomSlider.maxValue, 3)
        XCTAssertNotNil(editor.previewImageView.image)
        XCTAssertEqual(editor.useButton.title, "使用这个头像")
        XCTAssertEqual(editor.cancelButton.title, "取消")
    }
}
