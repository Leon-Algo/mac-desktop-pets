import Foundation

struct PetControlState: Equatable, Sendable {
    let id: String
    let displayName: String
    let isHidden: Bool
    let isPaused: Bool

    var visibilityTitle: String { isHidden ? L10n.localized("state.show", fallback: "显示") : L10n.localized("state.hide", fallback: "隐藏") }
    var pauseTitle: String { isPaused ? L10n.localized("state.resume", fallback: "继续") : L10n.localized("state.pause", fallback: "暂停") }
}

enum ControlCenterVisibilityPolicy {
    static func isGloballyHidden(globalHidden: Bool, characters: [PetControlState]) -> Bool {
        globalHidden || (!characters.isEmpty && characters.allSatisfy(\.isHidden))
    }

    static func mustShowFallback(globalHidden: Bool, characters: [PetControlState]) -> Bool {
        isGloballyHidden(globalHidden: globalHidden, characters: characters)
    }

    static func nextGlobalHidden(globalHidden: Bool, characters: [PetControlState]) -> Bool {
        !isGloballyHidden(globalHidden: globalHidden, characters: characters)
    }

    static func canHideFallback(
        clickThrough: Bool,
        globalHidden: Bool,
        characters: [PetControlState]
    ) -> Bool {
        !clickThrough && !isGloballyHidden(globalHidden: globalHidden, characters: characters)
    }
}
