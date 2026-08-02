import Foundation

enum BuiltInAvatarPreset: String, Codable, CaseIterable, Sendable {
    case sunny, ocean, mint, violet, coral, amber, sky, forest, rose, slate, indigo, cocoa

    var index: Int { Self.allCases.firstIndex(of: self) ?? 0 }
}

enum AvatarSource: Codable, Equatable, Sendable {
    case builtIn(BuiltInAvatarPreset)
    case imported(filename: String)
    case legacyBundled(identifier: String)

    var isValid: Bool {
        switch self {
        case .builtIn:
            return true
        case let .imported(filename):
            return !filename.isEmpty
                && filename == URL(fileURLWithPath: filename).lastPathComponent
                && filename.lowercased().hasSuffix(".png")
        case let .legacyBundled(identifier):
            return !identifier.isEmpty
                && identifier.range(of: #"^[A-Za-z0-9_-]+$"#, options: .regularExpression) != nil
        }
    }
}

enum BodyStyle: String, Codable, CaseIterable, Sendable {
    case plain, plaid, jacket

    var displayName: String {
        switch self {
        case .plain: "简约"
        case .plaid: "格纹"
        case .jacket: "外套"
        }
    }
}

enum OutfitPreset: String, Codable, CaseIterable, Sendable {
    case orange, blue, mint, violet, coral, slate

    var displayName: String {
        switch self {
        case .orange: "暖橙"
        case .blue: "海蓝"
        case .mint: "薄荷"
        case .violet: "柔紫"
        case .coral: "珊瑚"
        case .slate: "岩灰"
        }
    }

    var palette: CharacterPalette {
        switch self {
        case .orange: .init(skin: "#D79A79", hair: "#4A2B20", shirt: "#E28A3B", accent: "#FFF1D6")
        case .blue: .init(skin: "#C98D70", hair: "#202A39", shirt: "#4278B8", accent: "#DCEEFF")
        case .mint: .init(skin: "#D39A7D", hair: "#3A241B", shirt: "#70BFAE", accent: "#E3FFF8")
        case .violet: .init(skin: "#C88E75", hair: "#2B2035", shirt: "#8B69B8", accent: "#F0E5FF")
        case .coral: .init(skin: "#D9A082", hair: "#5A3028", shirt: "#D96868", accent: "#FFE4DD")
        case .slate: .init(skin: "#B98269", hair: "#202326", shirt: "#59646F", accent: "#EEF2F5")
        }
    }
}

enum PersonalityPreset: String, Codable, CaseIterable, Sendable {
    case lively, calm, curious, social, sleepy

    var displayName: String {
        switch self {
        case .lively: "活泼"
        case .calm: "沉稳"
        case .curious: "好奇"
        case .social: "社交"
        case .sleepy: "慵懒"
        }
    }

    var personality: Personality {
        switch self {
        case .lively: .init(speed: 0.82, curiosity: 0.72, sociability: 0.70, courage: 0.70, sleepiness: 0.18)
        case .calm: .init(speed: 0.42, curiosity: 0.50, sociability: 0.48, courage: 0.76, sleepiness: 0.36)
        case .curious: .init(speed: 0.60, curiosity: 0.92, sociability: 0.58, courage: 0.54, sleepiness: 0.28)
        case .social: .init(speed: 0.62, curiosity: 0.70, sociability: 0.94, courage: 0.64, sleepiness: 0.24)
        case .sleepy: .init(speed: 0.34, curiosity: 0.42, sociability: 0.55, courage: 0.46, sleepiness: 0.88)
        }
    }
}

struct CharacterProfile: Codable, Equatable, Sendable {
    var id: String
    var displayName: String
    var avatarSource: AvatarSource
    var bodyStyle: BodyStyle
    var outfit: OutfitPreset
    var personalityPreset: PersonalityPreset
    var personality: Personality
    var paletteOverride: CharacterPalette? = nil
}
