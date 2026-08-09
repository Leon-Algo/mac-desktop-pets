import AppKit
import Foundation

enum CharacterRosterStoreError: Error {
    case applicationSupportUnavailable
}

@MainActor
final class CharacterRosterStore {
    let rootDirectory: URL
    let rosterURL: URL
    let avatarsDirectory: URL
    private let fileManager: FileManager

    init(rootDirectory: URL? = nil, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        let resolvedRoot = rootDirectory ?? fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!.appendingPathComponent("DesktopPets", isDirectory: true)
        self.rootDirectory = resolvedRoot
        rosterURL = resolvedRoot.appendingPathComponent("characters-v1.json")
        avatarsDirectory = resolvedRoot.appendingPathComponent("Avatars", isDirectory: true)
    }

    func load(fallback: CharacterRoster = .default) -> CharacterRoster {
        guard let data = try? Data(contentsOf: rosterURL),
              let decoded = try? JSONDecoder().decode(CharacterRoster.self, from: data),
              let valid = try? decoded.validated() else {
            // 读取/解码/校验任一失败：不静默丢弃，先把损坏文件备份为 .corrupt，
            // 供排查与人工恢复，再回退到默认 roster。
            backupCorruptRosterIfNeeded()
            return fallback
        }
        return valid
    }

    /// 若已存在损坏的 roster 文件且尚未备份，则复制为 `<name>.corrupt`。
    private func backupCorruptRosterIfNeeded() {
        guard fileManager.fileExists(atPath: rosterURL.path) else { return }
        let backup = rosterURL.deletingPathExtension().appendingPathExtension("json.corrupt")
        guard !fileManager.fileExists(atPath: backup.path) else { return }
        try? fileManager.copyItem(at: rosterURL, to: backup)
    }

    var hasStoredRoster: Bool { fileManager.fileExists(atPath: rosterURL.path) }

    func save(_ roster: CharacterRoster) throws {
        let valid = try roster.validated()
        try ensureDirectories()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(valid).write(to: rosterURL, options: .atomic)
    }

    func importAvatar(data: Data) throws -> String {
        let normalized = try AvatarImageProcessor.normalizedPNG(from: data)
        try ensureDirectories()
        let filename = "\(UUID().uuidString.lowercased()).png"
        try normalized.write(to: avatarsDirectory.appendingPathComponent(filename), options: .atomic)
        return filename
    }

    func image(for source: AvatarSource) -> NSImage? {
        switch source {
        case .builtIn:
            return nil
        case let .imported(filename):
            guard AvatarSource.imported(filename: filename).isValid else { return nil }
            return NSImage(contentsOf: avatarsDirectory.appendingPathComponent(filename))
        case let .legacyBundled(identifier):
            return FaceAssetLoader.legacyBundledImage(identifier: identifier)
        }
    }

    func removeUnreferencedAvatars(roster: CharacterRoster) throws {
        let referenced = Set(roster.profiles.compactMap { profile -> String? in
            if case let .imported(filename) = profile.avatarSource { return filename }
            return nil
        })
        guard fileManager.fileExists(atPath: avatarsDirectory.path) else { return }
        for url in try fileManager.contentsOfDirectory(
            at: avatarsDirectory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) where url.pathExtension.lowercased() == "png" && !referenced.contains(url.lastPathComponent) {
            try fileManager.removeItem(at: url)
        }
    }

    private func ensureDirectories() throws {
        try fileManager.createDirectory(at: avatarsDirectory, withIntermediateDirectories: true)
    }
}
