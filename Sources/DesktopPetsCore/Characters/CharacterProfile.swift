import Foundation

public enum BuiltInAvatarPreset: String, Codable, CaseIterable, Sendable {
    case sunny, ocean, mint, violet, coral, amber, sky, forest, rose, slate, indigo, cocoa

    public var index: Int { Self.allCases.firstIndex(of: self) ?? 0 }
}

public enum AvatarSource: Codable, Equatable, Sendable {
    case builtIn(BuiltInAvatarPreset)
    case imported(filename: String)
    case legacyBundled(identifier: String)

    public var isValid: Bool {
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

public enum BodyStyle: String, Codable, CaseIterable, Sendable {
    case plain, plaid, jacket

    /// 中文显示名。跨平台核心不依赖资源包，直接提供与 macOS 端一致的默认文案。
    public var displayName: String {
        switch self {
        case .plain: "简约"
        case .plaid: "格纹"
        case .jacket: "外套"
        }
    }
}

public enum OutfitPreset: String, Codable, CaseIterable, Sendable {
    case orange, blue, mint, violet, coral, slate

    public var displayName: String {
        switch self {
        case .orange: "暖橙"
        case .blue: "海蓝"
        case .mint: "薄荷"
        case .violet: "柔紫"
        case .coral: "珊瑚"
        case .slate: "岩灰"
        }
    }

    public var palette: CharacterPalette {
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

public enum PersonalityPreset: String, Codable, CaseIterable, Sendable {
    case lively, calm, curious, social, sleepy

    public var displayName: String {
        switch self {
        case .lively: "活泼"
        case .calm: "沉稳"
        case .curious: "好奇"
        case .social: "社交"
        case .sleepy: "慵懒"
        }
    }

    public var personality: Personality {
        switch self {
        case .lively: .init(speed: 0.82, curiosity: 0.72, sociability: 0.70, courage: 0.70, sleepiness: 0.18)
        case .calm: .init(speed: 0.42, curiosity: 0.50, sociability: 0.48, courage: 0.76, sleepiness: 0.36)
        case .curious: .init(speed: 0.60, curiosity: 0.92, sociability: 0.58, courage: 0.54, sleepiness: 0.28)
        case .social: .init(speed: 0.62, curiosity: 0.70, sociability: 0.94, courage: 0.64, sleepiness: 0.24)
        case .sleepy: .init(speed: 0.34, curiosity: 0.42, sociability: 0.55, courage: 0.46, sleepiness: 0.88)
        }
    }
}

public struct CharacterProfile: Codable, Equatable, Sendable {
    public var id: String
    public var displayName: String
    public var avatarSource: AvatarSource
    public var bodyStyle: BodyStyle
    public var outfit: OutfitPreset
    public var personalityPreset: PersonalityPreset
    public var personality: Personality
    public var paletteOverride: CharacterPalette?

    public init(
        id: String,
        displayName: String,
        avatarSource: AvatarSource,
        bodyStyle: BodyStyle,
        outfit: OutfitPreset,
        personalityPreset: PersonalityPreset,
        personality: Personality,
        paletteOverride: CharacterPalette? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.avatarSource = avatarSource
        self.bodyStyle = bodyStyle
        self.outfit = outfit
        self.personalityPreset = personalityPreset
        self.personality = personality
        self.paletteOverride = paletteOverride
    }
}
