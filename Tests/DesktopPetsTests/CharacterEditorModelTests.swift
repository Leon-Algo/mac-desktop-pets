import XCTest
@testable import DesktopPets

final class CharacterEditorModelTests: XCTestCase {
    func testAddStopsAtEightAndDeleteStopsAtOne() throws {
        let model = CharacterEditorModel(roster: .default)
        XCTAssertTrue(model.canAdd)
        for _ in 0..<4 { XCTAssertTrue(model.addCharacter()) }
        XCTAssertEqual(model.draft.profiles.count, 8)
        XCTAssertFalse(model.canAdd)
        XCTAssertFalse(model.addCharacter())

        while model.draft.profiles.count > 1 { XCTAssertTrue(model.deleteSelectedCharacter()) }
        XCTAssertFalse(model.canDelete)
        XCTAssertFalse(model.deleteSelectedCharacter())
    }

    func testMoveRenameAndPersonalityTemplateUpdateSelectedProfile() throws {
        let model = CharacterEditorModel(roster: .default)
        model.selectedIndex = 1
        XCTAssertTrue(model.moveSelected(by: -1))
        XCTAssertEqual(model.selectedIndex, 0)
        XCTAssertEqual(model.draft.profiles[0].displayName, "蓝豆")

        model.updateSelectedName("  小蓝  ")
        model.applyPersonalityPreset(.sleepy)
        let validated = try model.validatedRoster()

        XCTAssertEqual(validated.profiles[0].displayName, "小蓝")
        XCTAssertEqual(validated.profiles[0].personalityPreset, .sleepy)
        XCTAssertEqual(validated.profiles[0].personality, PersonalityPreset.sleepy.personality)
    }

    func testCancelRestoresOriginalDraft() {
        let model = CharacterEditorModel(roster: .default)
        model.updateSelectedName("临时名称")
        model.cancelEdits()
        XCTAssertEqual(model.draft, .default)
    }
}
