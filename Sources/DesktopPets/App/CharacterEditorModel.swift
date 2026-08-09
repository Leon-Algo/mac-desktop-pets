import Foundation

final class CharacterEditorModel {
    private(set) var original: CharacterRoster
    private(set) var draft: CharacterRoster
    var selectedIndex = 0

    init(roster: CharacterRoster) {
        original = roster
        draft = roster
    }

    var canAdd: Bool { draft.profiles.count < CharacterRoster.maximumCount }
    var canDelete: Bool { draft.profiles.count > 1 }
    var selectedProfile: CharacterProfile { draft.profiles[selectedIndex] }

    @discardableResult
    func addCharacter() -> Bool {
        guard canAdd else { return false }
        let number = draft.profiles.count + 1
        let avatar = BuiltInAvatarPreset.allCases[(number - 1) % BuiltInAvatarPreset.allCases.count]
        let outfit = OutfitPreset.allCases[(number - 1) % OutfitPreset.allCases.count]
        draft.profiles.append(CharacterProfile(
            id: "user-\(UUID().uuidString.lowercased())",
            displayName: "新人物 \(number)",
            avatarSource: .builtIn(avatar),
            bodyStyle: .plain,
            outfit: outfit,
            personalityPreset: .lively,
            personality: PersonalityPreset.lively.personality
        ))
        selectedIndex = draft.profiles.count - 1
        return true
    }

    @discardableResult
    func deleteSelectedCharacter() -> Bool {
        guard canDelete, draft.profiles.indices.contains(selectedIndex) else { return false }
        draft.profiles.remove(at: selectedIndex)
        selectedIndex = min(selectedIndex, draft.profiles.count - 1)
        return true
    }

    @discardableResult
    func moveSelected(by offset: Int) -> Bool {
        let destination = selectedIndex + offset
        guard draft.profiles.indices.contains(selectedIndex), draft.profiles.indices.contains(destination) else { return false }
        let profile = draft.profiles.remove(at: selectedIndex)
        draft.profiles.insert(profile, at: destination)
        selectedIndex = destination
        return true
    }

    func updateSelected(_ transform: (inout CharacterProfile) -> Void) {
        guard draft.profiles.indices.contains(selectedIndex) else { return }
        transform(&draft.profiles[selectedIndex])
    }

    func updateSelectedName(_ name: String) { updateSelected { $0.displayName = name } }

    func applyPersonalityPreset(_ preset: PersonalityPreset) {
        updateSelected {
            $0.personalityPreset = preset
            $0.personality = preset.personality
        }
    }

    func validatedRoster() throws -> CharacterRoster { try draft.validated() }

    func cancelEdits() {
        draft = original
        selectedIndex = min(selectedIndex, draft.profiles.count - 1)
    }

    func acceptSavedRoster(_ roster: CharacterRoster) {
        original = roster
        draft = roster
        selectedIndex = min(selectedIndex, roster.profiles.count - 1)
    }
}
