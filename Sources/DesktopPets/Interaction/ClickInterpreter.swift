import Foundation

enum ClickDisposition: Equatable, Sendable {
    case scheduleSingle(token: Int)
    case emitDouble
    case ignore
}

struct ClickInterpreter: Sendable {
    private var nextToken = 0
    private var pendingSingleToken: Int?

    mutating func register(clickCount: Int) -> ClickDisposition {
        guard clickCount > 0 else { return .ignore }
        if clickCount >= 2 {
            pendingSingleToken = nil
            return .emitDouble
        }
        nextToken &+= 1
        pendingSingleToken = nextToken
        return .scheduleSingle(token: nextToken)
    }

    mutating func resolveSingle(token: Int) -> Bool {
        guard pendingSingleToken == token else { return false }
        pendingSingleToken = nil
        return true
    }

    mutating func cancelPendingSingle() {
        pendingSingleToken = nil
    }
}
