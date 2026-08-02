import Foundation

enum PetInteraction: Equatable, Sendable {
    case react(id: String)
    case gatherAndPlay(leaderID: String)
    case beginDrag(id: String, position: WorldPoint)
    case drag(id: String, position: WorldPoint)
    case release(id: String, position: WorldPoint)
    case togglePause(id: String)
    case recall(id: String)
    case hide(id: String)
}

enum PetInteractionResult: Equatable, Sendable {
    case handled
    case pauseChanged(id: String, paused: Bool)
    case hide(id: String)
    case show(id: String)
    case ignored
}
