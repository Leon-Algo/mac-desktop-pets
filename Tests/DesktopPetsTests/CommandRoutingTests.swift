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

        XCTAssertEqual(controller.statusButtonTitle, "🐾")
        XCTAssertEqual(controller.statusItem.length, NSStatusItem.squareLength)
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

    @MainActor
    func testGlobalVisibilityMenuOffersShowWhenAllCharactersIndividuallyHidden() {
        let controller = StatusMenuController(target: AppController())
        controller.refresh(
            preferences: .defaults,
            characters: CharacterCatalog.fallback.characters.map {
                PetControlState(id: $0.id, displayName: $0.displayName, isHidden: true, isPaused: false)
            }
        )

        XCTAssertTrue(controller.controlMenu.items.map(\.title).contains("显示宠物"))
    }

    @MainActor
    func testFallbackHideCommandIsDisabledDuringFullClickThrough() {
        let controller = StatusMenuController(target: AppController())
        controller.refresh(
            preferences: AppPreferences(paused: false, petsHidden: false, clickThrough: true, launchAtLogin: false),
            characters: CharacterCatalog.fallback.characters.map {
                PetControlState(id: $0.id, displayName: $0.displayName, isHidden: false, isPaused: false)
            },
            isFallbackVisible: true,
            canHideFallback: false
        )

        let item = controller.controlMenu.items.first { $0.title == "备用总台保持显示" }
        XCTAssertNotNil(item)
        XCTAssertFalse(item?.isEnabled ?? true)
    }

    @MainActor
    func testStatusContextChangeNotifiesFallbackOwner() {
        let controller = StatusMenuController(target: AppController())
        var changeCount = 0
        controller.onStatusContextChanged = { changeCount += 1 }

        controller.handleStatusContextChange()

        XCTAssertEqual(changeCount, 1)
    }

    @MainActor
    func testStatusItemRepairPreservesCompactSquareControl() {
        let controller = StatusMenuController(target: AppController())
        controller.statusItem.isVisible = false

        XCTAssertEqual(controller.checkHealth(), .recreate)
        XCTAssertEqual(controller.statusButtonTitle, "🐾")
        XCTAssertEqual(controller.statusItem.length, NSStatusItem.squareLength)
    }

    @MainActor
    func testSharedMenuOffersThreePetSizesAndChecksCurrentPreset() throws {
        let controller = StatusMenuController(target: AppController())
        var preferences = AppPreferences.defaults
        preferences.petScale = .half

        controller.refresh(preferences: preferences, characters: [])

        let sizeMenu = try XCTUnwrap(
            controller.controlMenu.items.first { $0.title == "人物大小" }?.submenu
        )
        XCTAssertEqual(sizeMenu.items.map(\.title), ["25%（最小）", "50%（推荐）", "100%（原样）"])
        XCTAssertEqual(sizeMenu.items.map(\.state), [.off, .on, .off])
        XCTAssertEqual(sizeMenu.items.map { $0.representedObject as? String }, ["quarter", "half", "original"])
    }

    @MainActor
    func testSharedMenuExposesDiscoverableActionCenter() throws {
        let controller = StatusMenuController(target: AppController())
        controller.refresh(
            preferences: .defaults,
            characters: CharacterCatalog.fallback.characters.map {
                PetControlState(id: $0.id, displayName: $0.displayName, isHidden: false, isPaused: false)
            }
        )

        let center = try XCTUnwrap(
            controller.controlMenu.items.first { $0.title == "动作中心" }?.submenu
        )
        XCTAssertEqual(Array(center.items.prefix(4)).map(\.title), ["格子衫", "黑背心", "薄荷衫", "黑外套"])
        let firstActions = try XCTUnwrap(center.items.first?.submenu)
        XCTAssertEqual(firstActions.items.map(\.title), [
            "👋 打个招呼", "⬆️ 原地跳一下", "🙈 翻个跟头", "📣 叫爸爸",
        ])
        XCTAssertEqual(
            firstActions.items.compactMap { ($0.representedObject as? PetActionRequest)?.targetID },
            Array(repeating: "person-left", count: 4)
        )
        XCTAssertEqual(firstActions.items.map(\.toolTip), PetActionCatalog.individual.map(\.explanation))
        let group = try XCTUnwrap(center.items.first { $0.title == "📣 四人一起喊爸爸" })
        XCTAssertEqual(group.representedObject as? PetActionRequest, PetActionRequest(actionID: .groupCallDad, targetID: nil))

        let management = try XCTUnwrap(
            controller.controlMenu.items.first { $0.title == "四人管理" }?.submenu?.items.first?.submenu
        )
        XCTAssertNotNil(management.items.first { $0.title == "让他做动作…" }?.submenu)
        XCTAssertFalse(management.items.contains { $0.title == "做个动作" })
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
