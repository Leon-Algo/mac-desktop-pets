import XCTest
@testable import DesktopPets

final class PetActionCatalogTests: XCTestCase {
    func testCatalogExposesStableDiscoverableActions() {
        XCTAssertEqual(PetActionCatalog.individual.map(\.id), [.wave, .hop, .roll, .callDad])
        XCTAssertEqual(PetActionCatalog.group.map(\.id), [.groupCallDad])
        XCTAssertEqual(PetActionCatalog.individual.map(\.title), [
            "👋 打个招呼",
            "⬆️ 原地跳一下",
            "🙈 翻个跟头",
            "📣 叫爸爸",
        ])
        XCTAssertEqual(PetActionCatalog.individual.last?.feedback, "爸爸！")
        XCTAssertEqual(PetActionCatalog.group.first?.title, "📣 四人一起喊爸爸")
        XCTAssertEqual(PetActionCatalog.group.first?.feedback, "爸爸！")
        XCTAssertTrue(PetActionCatalog.all.allSatisfy {
            !$0.explanation.isEmpty && !$0.feedback.isEmpty && $0.duration > 0
        })
        XCTAssertEqual(Set(PetActionCatalog.all.map(\.id)).count, PetActionCatalog.all.count)
    }

    func testRequestsAndOutcomesCarryTypedActionData() {
        let request = PetActionRequest(actionID: .wave, targetID: "person-left")
        XCTAssertEqual(request.actionID, .wave)
        XCTAssertEqual(request.targetID, "person-left")
        XCTAssertEqual(
            PetActionOutcome.performed(affectedIDs: ["person-left"], feedback: "嗨！", duration: 1.8),
            .performed(affectedIDs: ["person-left"], feedback: "嗨！", duration: 1.8)
        )
    }
}
