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

    init(
        id: String,
        personality: Personality,
        position: WorldPoint,
        state: PetState = .crawl,
        velocity: WorldVector = WorldVector(dx: 0, dy: 0),
        facing: Facing = .right,
        stateTime: Double = 0,
        supportID: String? = nil
    ) {
        self.id = id
        self.personality = personality
        self.position = position
        self.state = state
        self.velocity = velocity
        self.facing = facing
        self.stateTime = stateTime
        self.supportID = supportID
    }

    var pose: PetPose {
        PetPose(
            id: id,
            position: position,
            state: state,
            facing: facing,
            phase: stateTime.truncatingRemainder(dividingBy: 1),
            supportID: supportID
        )
    }
}
