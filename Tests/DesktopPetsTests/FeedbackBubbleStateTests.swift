import XCTest
@testable import DesktopPets

final class FeedbackBubbleStateTests: XCTestCase {
    func testOlderDismissalCannotHideNewerFeedback() {
        var state = FeedbackBubbleState()
        let first = state.show(message: "第一条")
        let second = state.show(message: "第二条")

        state.dismiss(generation: first)
        XCTAssertEqual(state.message, "第二条")

        state.dismiss(generation: second)
        XCTAssertNil(state.message)
    }
}
