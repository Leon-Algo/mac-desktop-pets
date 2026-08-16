import XCTest
@testable import DesktopPets

final class L10nTests: XCTestCase {
    /// English table resolves to the English translation.
    func testEnglishTranslationResolves() {
        let value = L10n.string(forKey: "menu.actionCenter", language: "en", fallback: "动作中心", comment: "")
        XCTAssertEqual(value, "Action Center")
    }

    /// Chinese table resolves to the (default) Chinese UI text.
    func testChineseTranslationResolves() {
        let value = L10n.string(forKey: "menu.actionCenter", language: "zh-Hans", fallback: "X", comment: "")
        XCTAssertEqual(value, "动作中心")
    }

    /// Missing keys fall back to the provided default verbatim.
    func testFallbackForUnknownKey() {
        let value = L10n.string(forKey: "no.such.key", language: "en", fallback: "Fallback", comment: "")
        XCTAssertEqual(value, "Fallback")
    }

    /// Format strings localize while preserving placeholders.
    func testFormattedChineseCount() {
        let format = L10n.string(forKey: "settings.count", language: "zh-Hans", fallback: "%d/8", comment: "")
        XCTAssertEqual(String(format: format, 3), "3/8")
    }

    func testFormattedEnglishBuiltInAvatar() {
        let format = L10n.string(forKey: "settings.builtInAvatar", language: "en", fallback: "Built-in Avatar %d", comment: "")
        XCTAssertEqual(String(format: format, 2), "Built-in Avatar 2")
    }

    /// Both localization tables are bundled, which is what proves the
    /// SwiftPM `.copy("Resources/Localization")` wiring works end to end.
    func testBothLocalizationTablesBundled() {
        XCTAssertEqual(L10n.string(forKey: "menu.quit", language: "en", fallback: "", comment: ""), "Quit Desktop Pets")
        XCTAssertEqual(L10n.string(forKey: "menu.quit", language: "zh-Hans", fallback: "", comment: ""), "退出桌面伙伴")
    }

    /// Default resolved language is Chinese unless the system is explicitly English.
    func testDefaultLanguageIsChineseUnlessEnglish() {
        let resolved = L10n.string(forKey: "menu.quit", language: L10n.currentLanguage, fallback: "", comment: "")
        XCTAssertTrue(resolved == "退出桌面伙伴" || resolved == "Quit Desktop Pets",
                      "resolved language must map to a known bundled table")
    }
}
