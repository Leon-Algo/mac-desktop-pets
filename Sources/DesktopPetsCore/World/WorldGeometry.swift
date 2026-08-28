import Foundation

public struct WorldPoint: Codable, Equatable, Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    public var isFinite: Bool { x.isFinite && y.isFinite }
}

public struct WorldVector: Codable, Equatable, Sendable {
    public var dx: Double
    public var dy: Double

    public init(dx: Double, dy: Double) {
        self.dx = dx
        self.dy = dy
    }
}

public struct WorldRect: Codable, Equatable, Sendable {
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double

    public init?(x: Double, y: Double, width: Double, height: Double) {
        guard x.isFinite, y.isFinite, width.isFinite, height.isFinite,
              width > 0, height > 0 else { return nil }
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    public var minX: Double { x }
    public var maxX: Double { x + width }
    public var minY: Double { y }
    public var maxY: Double { y + height }
    public var center: WorldPoint { WorldPoint(x: x + width / 2, y: y + height / 2) }

    public func contains(_ point: WorldPoint) -> Bool {
        point.x >= minX && point.x <= maxX && point.y >= minY && point.y <= maxY
    }

    public func intersects(_ other: WorldRect) -> Bool {
        minX < other.maxX && maxX > other.minX && minY < other.maxY && maxY > other.minY
    }

    public func clamped(_ point: WorldPoint, margin: Double) -> WorldPoint {
        let safeMargin = max(0, min(margin, min(width, height) / 2))
        return WorldPoint(
            x: min(max(point.x, minX + safeMargin), maxX - safeMargin),
            y: min(max(point.y, minY + safeMargin), maxY - safeMargin)
        )
    }

    public func squaredDistance(to point: WorldPoint) -> Double {
        let clamped = clamped(point, margin: 0)
        let dx = point.x - clamped.x
        let dy = point.y - clamped.y
        return dx * dx + dy * dy
    }
}
