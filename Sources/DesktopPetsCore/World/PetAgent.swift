import Foundation

public struct PetAgent: Sendable {
    public let id: String
    public let personality: Personality
    public var position: WorldPoint
    public var state: PetState
    public var velocity: WorldVector
    public var facing: Facing
    public var stateTime: Double
    public var supportID: String?
    public var manualActionID: PetActionID?

    public init(
        id: String,
        personality: Personality,
        position: WorldPoint,
        state: PetState = .crawl,
        velocity: WorldVector = WorldVector(dx: 0, dy: 0),
        facing: Facing = .right,
        stateTime: Double = 0,
        supportID: String? = nil,
        manualActionID: PetActionID? = nil
    ) {
        self.id = id
        self.personality = personality
        self.position = position
        self.state = state
        self.velocity = velocity
        self.facing = facing
        self.stateTime = stateTime
        self.supportID = supportID
        self.manualActionID = manualActionID
    }

    public var pose: PetPose {
        PetPose(
            id: id,
            position: position,
            state: state,
            facing: facing,
            phase: manualActionID == .roll
                ? min(stateTime / (PetActionCatalog.definition(for: .roll)?.duration ?? 1.4), 1)
                : stateTime.truncatingRemainder(dividingBy: 1),
            supportID: supportID
        )
    }
}
