import Foundation

struct WorldPoint: Codable, Equatable, Sendable {
    var x: Double
    var y: Double

    var isFinite: Bool { x.isFinite && y.isFinite }
}

struct WorldVector: Codable, Equatable, Sendable {
    var dx: Double
    var dy: Double
}

struct WorldRect: Codable, Equatable, Sendable {
    let x: Double
    let y: Double
    let width: Double
    let height: Double

    init?(x: Double, y: Double, width: Double, height: Double) {
        guard x.isFinite, y.isFinite, width.isFinite, height.isFinite,
              width > 0, height > 0 else { return nil }
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    var minX: Double { x }
    var maxX: Double { x + width }
    var minY: Double { y }
    var maxY: Double { y + height }
    var center: WorldPoint { WorldPoint(x: x + width / 2, y: y + height / 2) }

    func contains(_ point: WorldPoint) -> Bool {
        point.x >= minX && point.x <= maxX && point.y >= minY && point.y <= maxY
    }

    func clamped(_ point: WorldPoint, margin: Double) -> WorldPoint {
        let safeMargin = max(0, min(margin, min(width, height) / 2))
        return WorldPoint(
            x: min(max(point.x, minX + safeMargin), maxX - safeMargin),
            y: min(max(point.y, minY + safeMargin), maxY - safeMargin)
        )
    }

    func squaredDistance(to point: WorldPoint) -> Double {
        let clamped = clamped(point, margin: 0)
        let dx = point.x - clamped.x
        let dy = point.y - clamped.y
        return dx * dx + dy * dy
    }
}
