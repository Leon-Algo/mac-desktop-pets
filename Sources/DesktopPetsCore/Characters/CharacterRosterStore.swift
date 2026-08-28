import Foundation

public enum CharacterRosterStoreError: Error {
    case applicationSupportUnavailable
}

/// 角色名册持久化。核心无 AppKit 依赖：头像导入的图像归一化由
/// 平台外壳通过 `normalizePNG` 闭包注入（macOS 用 NSImage 实现，
/// Windows 用 WIC 实现），其余全部为纯 Foundation 文件操作。
@MainActor
public final class CharacterRosterStore {
    public let rootDirectory: URL
    public let rosterURL: URL
    public let avatarsDirectory: URL
    private let fileManager: FileManager
    private let normalizePNG: (Data) throws -> Data

    public init(
        rootDirectory: URL? = nil,
        fileManager: FileManager = .default,
        normalizePNG: ((Data) throws -> Data)? = nil
    ) {
        self.fileManager = fileManager
        self.normalizePNG = normalizePNG ?? { $0 }
        let resolvedRoot = rootDirectory ?? fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!.appendingPathComponent("DesktopPets", isDirectory: true)
        self.rootDirectory = resolvedRoot
        self.rosterURL = resolvedRoot.appendingPathComponent("characters-v1.json")
        self.avatarsDirectory = resolvedRoot.appendingPathComponent("Avatars", isDirectory: true)
    }

    public func load(fallback: CharacterRoster = .default) -> CharacterRoster {
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

    public var hasStoredRoster: Bool { fileManager.fileExists(atPath: rosterURL.path) }

    public func save(_ roster: CharacterRoster) throws {
        let valid = try roster.validated()
        try ensureDirectories()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(valid).write(to: rosterURL, options: .atomic)
    }

    public func importAvatar(data: Data) throws -> String {
        let normalized = try normalizePNG(data)
        try ensureDirectories()
        let filename = "\(UUID().uuidString.lowercased()).png"
        try normalized.write(to: avatarsDirectory.appendingPathComponent(filename), options: .atomic)
        return filename
    }

    /// 返回已导入头像的文件 URL（仅 `.imported` 有实体文件；`.builtIn`/`.legacyBundled` 返回 nil）。
    /// 图像解码交给平台外壳完成，保持核心无平台 UI 依赖，便于 Windows 复用。
    public func importedAvatarURL(for source: AvatarSource) -> URL? {
        guard case let .imported(filename) = source,
              AvatarSource.imported(filename: filename).isValid else { return nil }
        return avatarsDirectory.appendingPathComponent(filename)
    }

    public func removeUnreferencedAvatars(roster: CharacterRoster) throws {
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
