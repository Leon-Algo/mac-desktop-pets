import Foundation

public struct NormalizedPoint: Codable, Equatable, Sendable {
    public let x: Double
    public let y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    public var isValid: Bool { x.isFinite && y.isFinite && (0...1).contains(x) && (0...1).contains(y) }
}

public struct FrameRect: Codable, Equatable, Sendable {
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    public var isValid: Bool {
        x.isFinite && y.isFinite && width.isFinite && height.isFinite &&
        x >= 0 && y >= 0 && width > 0 && height > 0 && x + width <= 1 && y + height <= 1
    }
}

public struct AnimationClip: Codable, Equatable, Sendable {
    public let frames: [FrameRect]
    public let fps: Double

    public init(frames: [FrameRect], fps: Double) {
        self.frames = frames
        self.fps = fps
    }

    public var isValid: Bool { !frames.isEmpty && frames.allSatisfy(\.isValid) && fps.isFinite && fps > 0 && fps <= 60 }
}

public struct Personality: Codable, Equatable, Hashable, Sendable {
    public let speed: Double
    public let curiosity: Double
    public let sociability: Double
    public let courage: Double
    public let sleepiness: Double

    public init(speed: Double, curiosity: Double, sociability: Double, courage: Double, sleepiness: Double) {
        self.speed = speed
        self.curiosity = curiosity
        self.sociability = sociability
        self.courage = courage
        self.sleepiness = sleepiness
    }

    public var isValid: Bool {
        [speed, curiosity, sociability, courage, sleepiness].allSatisfy { $0.isFinite && (0...1).contains($0) }
    }
}

public struct CharacterPalette: Codable, Equatable, Sendable {
    public let skin: String
    public let hair: String
    public let shirt: String
    public let accent: String

    public init(skin: String, hair: String, shirt: String, accent: String) {
        self.skin = skin
        self.hair = hair
        self.shirt = shirt
        self.accent = accent
    }
}

public struct CharacterManifest: Codable, Equatable, Sendable {
    public let id: String
    public let displayName: String
    public let atlasName: String?
    public let palette: CharacterPalette
    public let personality: Personality
    public let anchor: NormalizedPoint
    public let collisionBody: FrameRect
    public let animations: [String: AnimationClip]
    public var avatarSource: AvatarSource?
    public var bodyStyle: BodyStyle?

    public init(
        id: String,
        displayName: String,
        atlasName: String?,
        palette: CharacterPalette,
        personality: Personality,
        anchor: NormalizedPoint,
        collisionBody: FrameRect,
        animations: [String: AnimationClip],
        avatarSource: AvatarSource? = nil,
        bodyStyle: BodyStyle? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.atlasName = atlasName
        self.palette = palette
        self.personality = personality
        self.anchor = anchor
        self.collisionBody = collisionBody
        self.animations = animations
        self.avatarSource = avatarSource
        self.bodyStyle = bodyStyle
    }

    public func animation(named name: String) -> AnimationClip? {
        animations[name] ?? animations["idle"]
    }

    public var isValid: Bool {
        !id.isEmpty && !displayName.isEmpty && personality.isValid && anchor.isValid &&
        collisionBody.isValid && animations["idle"]?.isValid == true &&
        animations.values.allSatisfy(\.isValid)
    }
}
