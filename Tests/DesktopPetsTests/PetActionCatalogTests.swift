import XCTest
@testable import DesktopPets

final class PetActionCatalogTests: XCTestCase {
    func testCatalogExposesStableDiscoverableActions() {
        XCTAssertEqual(PetActionCatalog.individual.map(\.id), [.wave, .hop, .roll, .sleep])
        XCTAssertEqual(PetActionCatalog.group.map(\.id), [.gatherPlay])
        XCTAssertEqual(PetActionCatalog.individual.map(\.title), [
            "👋 打个招呼",
            "⬆️ 原地跳一下",
            "🙈 翻个跟头",
            "💤 趴下睡觉",
        ])
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
