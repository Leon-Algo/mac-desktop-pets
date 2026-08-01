import XCTest
@testable import DesktopPets

final class CommandRoutingTests: XCTestCase {
    func testMenuLabelsReflectRunningVisibleState() {
        let state = MenuState(preferences: .defaults)
        XCTAssertEqual(state.pauseTitle, "暂停活动")
        XCTAssertEqual(state.visibilityTitle, "隐藏宠物")
        XCTAssertEqual(state.clickThroughTitle, "关闭点击穿透")
    }

    func testMenuLabelsReflectPausedHiddenInteractiveState() {
        let preferences = AppPreferences(paused: true, petsHidden: true, clickThrough: false, launchAtLogin: false)
        let state = MenuState(preferences: preferences)
        XCTAssertEqual(state.pauseTitle, "继续活动")
        XCTAssertEqual(state.visibilityTitle, "显示宠物")
        XCTAssertEqual(state.clickThroughTitle, "开启点击穿透")
    }
}
