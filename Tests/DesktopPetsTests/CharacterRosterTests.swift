import XCTest
@testable import DesktopPets

final class CharacterRosterTests: XCTestCase {
    func testDefaultsContainFourSafeDistinctCharactersAndTwelveAvatarChoices() throws {
        let roster = try CharacterRoster.default.validated()

        XCTAssertEqual(roster.profiles.map(\.displayName), ["橙仔", "蓝豆", "薄荷", "紫团"])
        XCTAssertEqual(roster.profiles.count, 4)
        XCTAssertEqual(BuiltInAvatarPreset.allCases.count, 12)
        XCTAssertEqual(Set(roster.profiles.map(\.id)).count, 4)
        XCTAssertTrue(roster.profiles.allSatisfy {
            if case .builtIn = $0.avatarSource { return true }
            return false
        })
    }

    func testValidationTrimsNamesAndAcceptsOneThroughEightProfiles() throws {
        let one = CharacterRoster(version: 1, profiles: [profile(id: "one", name: "  小一  ")])
        XCTAssertEqual(try one.validated().profiles[0].displayName, "小一")

        let eight = CharacterRoster(
            version: 1,
            profiles: (1...8).map { profile(id: "p\($0)", name: "人物\($0)") }
        )
        XCTAssertEqual(try eight.validated().profiles.count, 8)
    }

    func testValidationRejectsEmptyNineDuplicateAndUnsafeImportedProfiles() {
        XCTAssertThrowsError(try CharacterRoster(version: 1, profiles: []).validated())
        XCTAssertThrowsError(try CharacterRoster(
            version: 1,
            profiles: (1...9).map { profile(id: "p\($0)", name: "人物\($0)") }
        ).validated())
        XCTAssertThrowsError(try CharacterRoster(
            version: 1,
            profiles: [profile(id: "same", name: "甲"), profile(id: "same", name: "乙")]
        ).validated())
        XCTAssertThrowsError(try CharacterRoster(
            version: 1,
            profiles: [profile(id: "bad", name: "越界", avatar: .imported(filename: "../photo.png"))]
        ).validated())
    }

    func testFivePersonalityTemplatesProduceValidDistinctValues() {
        XCTAssertEqual(PersonalityPreset.allCases.count, 5)
        XCTAssertTrue(PersonalityPreset.allCases.allSatisfy { $0.personality.isValid })
        XCTAssertEqual(Set(PersonalityPreset.allCases.map(\.personality)).count, 5)
    }

    private func profile(
        id: String,
        name: String,
        avatar: AvatarSource = .builtIn(.sunny)
    ) -> CharacterProfile {
        CharacterProfile(
            id: id,
            displayName: name,
            avatarSource: avatar,
            bodyStyle: .plain,
            outfit: .orange,
            personalityPreset: .lively,
            personality: PersonalityPreset.lively.personality
        )
    }
}
