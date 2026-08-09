import Foundation

struct NormalizedPoint: Codable, Equatable, Sendable {
    let x: Double
    let y: Double

    var isValid: Bool { x.isFinite && y.isFinite && (0...1).contains(x) && (0...1).contains(y) }
}

struct FrameRect: Codable, Equatable, Sendable {
    let x: Double
    let y: Double
    let width: Double
    let height: Double

    var isValid: Bool {
        x.isFinite && y.isFinite && width.isFinite && height.isFinite &&
        x >= 0 && y >= 0 && width > 0 && height > 0 && x + width <= 1 && y + height <= 1
    }
}

struct AnimationClip: Codable, Equatable, Sendable {
    let frames: [FrameRect]
    let fps: Double

    var isValid: Bool { !frames.isEmpty && frames.allSatisfy(\.isValid) && fps.isFinite && fps > 0 && fps <= 60 }
}

struct Personality: Codable, Equatable, Hashable, Sendable {
    let speed: Double
    let curiosity: Double
    let sociability: Double
    let courage: Double
    let sleepiness: Double

    var isValid: Bool {
        [speed, curiosity, sociability, courage, sleepiness].allSatisfy { $0.isFinite && (0...1).contains($0) }
    }
}

struct CharacterPalette: Codable, Equatable, Sendable {
    let skin: String
    let hair: String
    let shirt: String
    let accent: String
}

struct CharacterManifest: Codable, Equatable, Sendable {
    let id: String
    let displayName: String
    let atlasName: String?
    let palette: CharacterPalette
    let personality: Personality
    let anchor: NormalizedPoint
    let collisionBody: FrameRect
    let animations: [String: AnimationClip]
    var avatarSource: AvatarSource? = nil
    var bodyStyle: BodyStyle? = nil

    func animation(named name: String) -> AnimationClip? {
        animations[name] ?? animations["idle"]
    }

    var isValid: Bool {
        !id.isEmpty && !displayName.isEmpty && personality.isValid && anchor.isValid &&
        collisionBody.isValid && animations["idle"]?.isValid == true &&
        animations.values.allSatisfy(\.isValid)
    }
}
