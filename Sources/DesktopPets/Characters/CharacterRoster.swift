import Foundation

enum CharacterRosterError: Error, Equatable {
    case unsupportedVersion(Int)
    case invalidCount(Int)
    case duplicateIdentifier(String)
    case invalidIdentifier(String)
    case invalidName(String)
    case invalidAvatar(String)
    case invalidPersonality(String)
}

struct CharacterRoster: Codable, Equatable, Sendable {
    static let currentVersion = 1
    static let maximumCount = 8

    var version: Int
    var profiles: [CharacterProfile]

    func validated() throws -> CharacterRoster {
        guard version == Self.currentVersion else { throw CharacterRosterError.unsupportedVersion(version) }
        guard (1...Self.maximumCount).contains(profiles.count) else {
            throw CharacterRosterError.invalidCount(profiles.count)
        }
        var ids = Set<String>()
        var normalized: [CharacterProfile] = []
        for var profile in profiles {
            guard !profile.id.isEmpty,
                  profile.id.range(of: #"^[A-Za-z0-9_-]+$"#, options: .regularExpression) != nil else {
                throw CharacterRosterError.invalidIdentifier(profile.id)
            }
            guard ids.insert(profile.id).inserted else {
                throw CharacterRosterError.duplicateIdentifier(profile.id)
            }
            profile.displayName = profile.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard (1...20).contains(profile.displayName.count) else {
                throw CharacterRosterError.invalidName(profile.id)
            }
            guard profile.avatarSource.isValid else { throw CharacterRosterError.invalidAvatar(profile.id) }
            guard profile.personality.isValid else { throw CharacterRosterError.invalidPersonality(profile.id) }
            normalized.append(profile)
        }
        return CharacterRoster(version: version, profiles: normalized)
    }

    static let `default` = CharacterRoster(version: currentVersion, profiles: [
        profile(id: "default-orange", name: "橙仔", avatar: .sunny, outfit: .orange, personality: .lively),
        profile(id: "default-blue", name: "蓝豆", avatar: .ocean, outfit: .blue, personality: .calm),
        profile(id: "default-mint", name: "薄荷", avatar: .mint, outfit: .mint, personality: .social),
        profile(id: "default-violet", name: "紫团", avatar: .violet, outfit: .violet, personality: .curious),
    ])

    private static func profile(
        id: String,
        name: String,
        avatar: BuiltInAvatarPreset,
        outfit: OutfitPreset,
        personality: PersonalityPreset
    ) -> CharacterProfile {
        CharacterProfile(
            id: id,
            displayName: name,
            avatarSource: .builtIn(avatar),
            bodyStyle: .plain,
            outfit: outfit,
            personalityPreset: personality,
            personality: personality.personality
        )
    }
}
