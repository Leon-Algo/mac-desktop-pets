import Foundation

public enum ObstacleKind: String, Codable, Equatable, Sendable {
    case window
    case screenFloor
}

public struct Obstacle: Codable, Equatable, Sendable {
    public let id: String
    public let kind: ObstacleKind
    public let rect: WorldRect

    public init(id: String, kind: ObstacleKind, rect: WorldRect) {
        self.id = id
        self.kind = kind
        self.rect = rect
    }
}

public struct SupportSurface: Equatable, Sendable {
    public let obstacleID: String
    public let kind: ObstacleKind
    public let y: Double
    public let minX: Double
    public let maxX: Double
}

public enum EdgeSide: String, Codable, Equatable, Sendable {
    case left
    case right
}

public struct ClimbableEdge: Equatable, Sendable {
    public let obstacleID: String
    public let x: Double
    public let minY: Double
    public let maxY: Double
    public let side: EdgeSide
}
