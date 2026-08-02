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
}
