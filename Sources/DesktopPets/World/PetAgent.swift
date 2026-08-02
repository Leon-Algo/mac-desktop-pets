import Foundation

struct PetAgent: Sendable {
    let id: String
    let personality: Personality
    var position: WorldPoint
    var state: PetState
    var velocity: WorldVector
    var facing: Facing
    var stateTime: Double
    var supportID: String?
    var manualActionID: PetActionID?

    init(
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

    var pose: PetPose {
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
