import Foundation

enum PetState: String, Codable, CaseIterable, Sendable {
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
}

enum Facing: Int, Codable, Sendable {
    case left = -1
    case right = 1
}

struct PetPose: Codable, Equatable, Sendable {
    let id: String
    let position: WorldPoint
    let state: PetState
    let facing: Facing
    let phase: Double
    let supportID: String?
}
