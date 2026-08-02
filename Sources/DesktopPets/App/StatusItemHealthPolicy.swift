import Foundation

struct StatusItemHealthSnapshot: Equatable, Sendable {
    let isMarkedVisible: Bool
    let hasButton: Bool
    let hasWindow: Bool

    static let healthy = StatusItemHealthSnapshot(
        isMarkedVisible: true,
        hasButton: true,
        hasWindow: true
    )

    var isHealthy: Bool { isMarkedVisible && hasButton && hasWindow }
}

enum StatusItemHealthAction: Equatable, Sendable {
    case none
    case recreate
    case showFallback
}

struct StatusItemHealthPolicy: Sendable {
    private var attemptedRepair = false

    mutating func observe(_ snapshot: StatusItemHealthSnapshot) -> StatusItemHealthAction {
        if snapshot.isHealthy {
            attemptedRepair = false
            return .none
        }
        if !attemptedRepair {
            attemptedRepair = true
            return .recreate
        }
        return .showFallback
    }
}
