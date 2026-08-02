import Foundation

struct ObstacleMap: Sendable {
    let displays: [WorldRect]
    let obstacles: [Obstacle]

    init(displays: [WorldRect], obstacles: [Obstacle]) {
        self.displays = displays
        self.obstacles = obstacles.sorted {
            if $0.rect.maxY == $1.rect.maxY { return $0.id < $1.id }
            return $0.rect.maxY > $1.rect.maxY
        }
    }

    func supportingSurface(below point: WorldPoint, within maxDrop: Double) -> SupportSurface? {
        guard point.isFinite, maxDrop >= 0 else { return nil }
        var candidates = obstacles.compactMap { obstacle -> SupportSurface? in
            let top = obstacle.rect.maxY
            guard point.x >= obstacle.rect.minX,
                  point.x <= obstacle.rect.maxX,
                  top <= point.y,
                  point.y - top <= maxDrop else { return nil }
            return SupportSurface(
                obstacleID: obstacle.id,
                kind: obstacle.kind,
                y: top,
                minX: obstacle.rect.minX,
                maxX: obstacle.rect.maxX
            )
        }

        candidates.append(contentsOf: displays.compactMap { display in
            guard point.x >= display.minX,
                  point.x <= display.maxX,
                  display.minY <= point.y,
                  point.y - display.minY <= maxDrop else { return nil }
            return SupportSurface(
                obstacleID: "screen-floor-\(display.x)-\(display.y)",
                kind: .screenFloor,
                y: display.minY,
                minX: display.minX,
                maxX: display.maxX
            )
        })

        return candidates.max {
            if $0.y == $1.y { return $0.obstacleID > $1.obstacleID }
            return $0.y < $1.y
        }
    }

    func nearestClimbableEdge(to point: WorldPoint, within maxDistance: Double) -> ClimbableEdge? {
        guard point.isFinite, maxDistance >= 0 else { return nil }
        return obstacles
            .flatMap { obstacle in
                [
                    ClimbableEdge(
                        obstacleID: obstacle.id,
                        x: obstacle.rect.minX,
                        minY: obstacle.rect.minY,
                        maxY: obstacle.rect.maxY,
                        side: .left
                    ),
                    ClimbableEdge(
                        obstacleID: obstacle.id,
                        x: obstacle.rect.maxX,
                        minY: obstacle.rect.minY,
                        maxY: obstacle.rect.maxY,
                        side: .right
                    ),
                ]
            }
            .filter { point.y >= $0.minY && point.y <= $0.maxY && abs(point.x - $0.x) <= maxDistance }
            .min {
                let lhsDistance = abs(point.x - $0.x)
                let rhsDistance = abs(point.x - $1.x)
                if lhsDistance == rhsDistance { return $0.obstacleID < $1.obstacleID }
                return lhsDistance < rhsDistance
            }
    }

    func crossedClimbableEdge(fromX: Double, toX: Double, atY y: Double) -> ClimbableEdge? {
        guard fromX.isFinite, toX.isFinite, y.isFinite, fromX != toX else { return nil }
        let movingRight = toX > fromX
        return obstacles.compactMap { obstacle -> ClimbableEdge? in
            guard y >= obstacle.rect.minY, y <= obstacle.rect.maxY else { return nil }
            let edgeX = movingRight ? obstacle.rect.minX : obstacle.rect.maxX
            guard movingRight
                    ? (fromX < edgeX && toX >= edgeX)
                    : (fromX > edgeX && toX <= edgeX) else { return nil }
            return ClimbableEdge(
                obstacleID: obstacle.id,
                x: edgeX,
                minY: obstacle.rect.minY,
                maxY: obstacle.rect.maxY,
                side: movingRight ? .left : .right
            )
        }
        .min { abs(fromX - $0.x) < abs(fromX - $1.x) }
    }

    func clamped(_ point: WorldPoint, margin: Double) -> WorldPoint {
        guard let display = displays.min(by: {
            $0.squaredDistance(to: point) < $1.squaredDistance(to: point)
        }) else { return point }
        return display.clamped(point, margin: margin)
    }

    func clampedPetAnchor(_ point: WorldPoint, halfWidth: Double, topClearance: Double) -> WorldPoint {
        guard let display = displays.min(by: {
            $0.squaredDistance(to: point) < $1.squaredDistance(to: point)
        }) else { return point }
        let safeHalfWidth = max(0, min(halfWidth, display.width / 2))
        let safeTop = max(0, min(topClearance, display.height))
        return WorldPoint(
            x: min(max(point.x, display.minX + safeHalfWidth), display.maxX - safeHalfWidth),
            y: min(max(point.y, display.minY), display.maxY - safeTop)
        )
    }
}
