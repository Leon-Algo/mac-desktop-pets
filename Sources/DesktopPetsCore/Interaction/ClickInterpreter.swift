import Foundation

public enum ClickDisposition: Equatable, Sendable {
    case scheduleSingle(token: Int)
    case emitDouble
    case ignore
}

public struct ClickInterpreter: Sendable {
    private var nextToken = 0
    private var pendingSingleToken: Int?

    public init() {}

    public mutating func register(clickCount: Int) -> ClickDisposition {
        guard clickCount > 0 else { return .ignore }
        if clickCount >= 2 {
            pendingSingleToken = nil
            return .emitDouble
        }
        nextToken &+= 1
        pendingSingleToken = nextToken
        return .scheduleSingle(token: nextToken)
    }

    public mutating func resolveSingle(token: Int) -> Bool {
        guard pendingSingleToken == token else { return false }
        pendingSingleToken = nil
        return true
    }

    public mutating func cancelPendingSingle() {
        pendingSingleToken = nil
    }
}
