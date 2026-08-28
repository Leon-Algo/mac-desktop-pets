import Foundation

public enum PetState: String, Codable, CaseIterable, Sendable {
    case idle
    case crawl
    case turn
    case climb
    case hang
    case jump
    case fall
    case sleep
    case chase
    case greet
    case play
    case roll
}

public enum Facing: Int, Codable, Sendable {
    case left = -1
    case right = 1
}

public struct PetPose: Codable, Equatable, Sendable {
    public let id: String
    public let position: WorldPoint
    public let state: PetState
    public let facing: Facing
    public let phase: Double
    public let supportID: String?

    public init(
        id: String,
        position: WorldPoint,
        state: PetState,
        facing: Facing,
        phase: Double,
        supportID: String?
    ) {
        self.id = id
        self.position = position
        self.state = state
        self.facing = facing
        self.phase = phase
        self.supportID = supportID
    }
}
