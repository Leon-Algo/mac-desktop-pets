import Foundation

enum ObstacleKind: String, Codable, Equatable, Sendable {
    case window
    case screenFloor
}

struct Obstacle: Codable, Equatable, Sendable {
    let id: String
    let kind: ObstacleKind
    let rect: WorldRect
}

struct SupportSurface: Equatable, Sendable {
    let obstacleID: String
    let kind: ObstacleKind
    let y: Double
    let minX: Double
    let maxX: Double
}

enum EdgeSide: String, Codable, Equatable, Sendable {
    case left
    case right
}

struct ClimbableEdge: Equatable, Sendable {
    let obstacleID: String
    let x: Double
    let minY: Double
    let maxY: Double
    let side: EdgeSide
}
