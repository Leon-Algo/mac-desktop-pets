import Foundation

struct PetControlState: Equatable, Sendable {
    let id: String
    let displayName: String
    let isHidden: Bool
    let isPaused: Bool

    var visibilityTitle: String { isHidden ? "显示" : "隐藏" }
    var pauseTitle: String { isPaused ? "继续" : "暂停" }
}

enum ControlCenterVisibilityPolicy {
    static func mustShowFallback(globalHidden: Bool, characters: [PetControlState]) -> Bool {
        globalHidden || (!characters.isEmpty && characters.allSatisfy(\.isHidden))
    }
}
