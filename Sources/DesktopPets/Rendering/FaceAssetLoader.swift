import AppKit

@MainActor
enum FaceAssetLoader {
    static func image(for identifier: String) -> NSImage? {
        legacyBundledImage(identifier: identifier)
    }

    static func legacyBundledImage(identifier: String) -> NSImage? {
        guard let url = ResourceBundleLocator.current.url(forResource: identifier, withExtension: "jpg") else { return nil }
        return NSImage(contentsOf: url)
    }

    static func image(for character: CharacterManifest) -> NSImage? {
        switch character.avatarSource {
        case let .builtIn(preset):
            return BuiltInAvatarRenderer.image(for: preset, size: NSSize(width: 256, height: 256))
        case let .imported(filename):
            return CharacterRosterStore().image(for: .imported(filename: filename))
        case let .legacyBundled(identifier):
            return legacyBundledImage(identifier: identifier)
        case nil:
            return image(for: character.id)
        }
    }
}
