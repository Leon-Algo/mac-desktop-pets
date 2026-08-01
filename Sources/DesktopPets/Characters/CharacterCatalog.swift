import Foundation

enum CharacterCatalogError: Error, Equatable {
    case invalidManifest(String)
    case duplicateIdentifier(String)
    case missingBundledCatalog
}

struct CharacterCatalog: Sendable {
    let characters: [CharacterManifest]
    let usedFallback: Bool

    static func load(data: Data) throws -> CharacterCatalog {
        let decoded = try JSONDecoder().decode([CharacterManifest].self, from: data)
        var identifiers = Set<String>()
        for manifest in decoded {
            guard manifest.isValid else { throw CharacterCatalogError.invalidManifest(manifest.id) }
            guard identifiers.insert(manifest.id).inserted else {
                throw CharacterCatalogError.duplicateIdentifier(manifest.id)
            }
        }
        return CharacterCatalog(characters: decoded, usedFallback: false)
    }

    static func loadBundled() throws -> CharacterCatalog {
        guard let url = ResourceBundleLocator.current.url(forResource: "characters", withExtension: "json") else {
            throw CharacterCatalogError.missingBundledCatalog
        }
        return try load(data: Data(contentsOf: url))
    }

    static func loadOrFallback(data: Data) -> CharacterCatalog {
        (try? load(data: data)) ?? fallback
    }

    static var fallback: CharacterCatalog {
        let profiles: [(String, String, CharacterPalette, Personality)] = [
            ("person-left", "格子衫", .init(skin: "#D8A080", hair: "#1E1715", shirt: "#B9A88A", accent: "#5D655E"), .init(speed: 0.46, curiosity: 0.70, sociability: 0.62, courage: 0.42, sleepiness: 0.35)),
            ("person-center-left", "黑背心", .init(skin: "#D49A76", hair: "#171313", shirt: "#171717", accent: "#F5F0E8"), .init(speed: 0.70, curiosity: 0.72, sociability: 0.80, courage: 0.78, sleepiness: 0.22)),
            ("person-center-right", "薄荷衫", .init(skin: "#D39A7D", hair: "#3A241B", shirt: "#A9D8CF", accent: "#403632"), .init(speed: 0.52, curiosity: 0.58, sociability: 0.74, courage: 0.48, sleepiness: 0.42)),
            ("person-right", "黑外套", .init(skin: "#B97D5E", hair: "#151313", shirt: "#272727", accent: "#EFE4DC"), .init(speed: 0.62, curiosity: 0.66, sociability: 0.68, courage: 0.66, sleepiness: 0.30)),
        ]
        let frame = FrameRect(x: 0, y: 0, width: 1, height: 1)
        let clip = AnimationClip(frames: [frame], fps: 8)
        let animations = Dictionary(uniqueKeysWithValues: ["idle", "crawl", "turn", "climb", "hang", "jump", "fall", "sleep", "chase", "greet", "play"].map { ($0, clip) })
        return CharacterCatalog(
            characters: profiles.map { id, name, palette, personality in
                CharacterManifest(
                    id: id,
                    displayName: name,
                    atlasName: nil,
                    palette: palette,
                    personality: personality,
                    anchor: NormalizedPoint(x: 0.5, y: 0.08),
                    collisionBody: FrameRect(x: 0.15, y: 0.04, width: 0.7, height: 0.72),
                    animations: animations
                )
            },
            usedFallback: true
        )
    }
}
