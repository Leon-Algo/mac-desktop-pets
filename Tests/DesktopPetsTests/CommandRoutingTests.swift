import XCTest
@testable import DesktopPets

final class CommandRoutingTests: XCTestCase {
    func testMenuLabelsReflectRunningVisibleState() {
        let state = MenuState(preferences: .defaults)
        XCTAssertEqual(state.pauseTitle, "暂停活动")
        XCTAssertEqual(state.visibilityTitle, "隐藏宠物")
        XCTAssertEqual(state.clickThroughTitle, "完全点击穿透")
    }

    func testMenuLabelsReflectPausedHiddenFullPassThroughState() {
        let preferences = AppPreferences(paused: true, petsHidden: true, clickThrough: true, launchAtLogin: false)
        let state = MenuState(preferences: preferences)
        XCTAssertEqual(state.pauseTitle, "继续活动")
        XCTAssertEqual(state.visibilityTitle, "显示宠物")
        XCTAssertEqual(state.clickThroughTitle, "启用人物交互")
    }

    func testCharacterMenuStateUsesDisplayNameAndCurrentLabels() {
        let state = PetControlState(
            id: "person-left",
            displayName: "格子衫",
            isHidden: true,
            isPaused: true
        )

        XCTAssertEqual(state.displayName, "格子衫")
        XCTAssertEqual(state.visibilityTitle, "显示")
        XCTAssertEqual(state.pauseTitle, "继续")
    }

    @MainActor
    func testSharedMenuContainsGlobalAndFourCharacterControls() {
        let controller = StatusMenuController(target: AppController())
        controller.refresh(
            preferences: .defaults,
            characters: CharacterCatalog.fallback.characters.map {
                PetControlState(id: $0.id, displayName: $0.displayName, isHidden: false, isPaused: false)
            }
        )

        XCTAssertEqual(controller.statusButtonTitle, "🐾 桌宠")
        XCTAssertTrue(controller.controlMenu.items.map(\.title).contains("四人管理"))
        let people = controller.controlMenu.items.first { $0.title == "四人管理" }?.submenu?.items ?? []
        XCTAssertEqual(people.map(\.title), ["格子衫", "黑背心", "薄荷衫", "黑外套"])
    }

    @MainActor
    func testWorldRunnerDelegatesUICommands() {
        let runner = WorldRunner(
            characters: CharacterCatalog.fallback.characters,
            geometryProvider: CommandRoutingFixedGeometryProvider()
        )
        var received: ControlCenterCommand?
        runner.onUICommand = { received = $0 }

        runner.handle(.openControlCenter)

        XCTAssertEqual(received, .openControlCenter)
        runner.stop()
    }
}

@MainActor
private final class CommandRoutingFixedGeometryProvider: GeometryProvider {
    func snapshot() -> GeometrySnapshot {
        GeometrySnapshot(
            displays: [WorldRect(x: 0, y: 0, width: 1200, height: 800)!],
            obstacles: [],
            ownerPIDs: [],
            capturedAt: Date()
        )
    }
}
