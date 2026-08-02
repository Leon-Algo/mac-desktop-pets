import Foundation

struct GeometrySnapshot: Sendable {
    let displays: [WorldRect]
    let obstacles: [Obstacle]
    let ownerPIDs: [Int32]
    let capturedAt: Date

    var obstacleMap: ObstacleMap { ObstacleMap(displays: displays, obstacles: obstacles) }
}

@MainActor
protocol GeometryProvider: AnyObject {
    func snapshot() -> GeometrySnapshot
}
