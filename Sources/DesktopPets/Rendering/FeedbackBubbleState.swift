import Foundation

struct FeedbackBubbleState: Equatable, Sendable {
    private(set) var message: String?
    private(set) var generation: UInt64 = 0

    mutating func show(message: String) -> UInt64 {
        generation &+= 1
        self.message = message
        return generation
    }

    mutating func dismiss(generation: UInt64) {
        guard generation == self.generation else { return }
        message = nil
    }
}
