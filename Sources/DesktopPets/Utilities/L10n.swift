import Foundation

/// Lightweight localization helper for the SwiftPM-built DesktopPets executable.
///
/// Translation tables live in `Resources/Localization/<lang>.lproj/Localizable.strings`
/// and are embedded in `Bundle.module`. `Scripts/package-app.sh` already copies that
/// module bundle into the shipped `.app`, so the same lookup works in tests, via
/// `swift run`, and in the packaged application.
///
/// User-facing chrome should call `L10n.localized(_:)`. The default UI language is
/// Chinese (`zh-Hans`) to preserve the original behavior on every system; English
/// resources remain embedded for a future in-app language picker.
enum L10n {
    /// Resolves the current UI language. The UI stays Chinese by default to preserve the
    /// original behavior; English resources remain embedded for a future language switch.
    static var currentLanguage: String { "zh-Hans" }

    /// Localized string for the running UI language.
    /// - Parameter fallback: returned verbatim when the key is missing; defaults to the key itself.
    static func localized(_ key: String, _ comment: String = "", fallback: String? = nil) -> String {
        string(forKey: key, language: currentLanguage, fallback: fallback ?? key, comment: comment)
    }

    /// Testable variant that forces a specific language bundle (locale-independent).
    static func string(forKey key: String, language: String, fallback: String, comment: String) -> String {
        guard let bundle = bundle(for: language) else { return fallback }
        let resolved = bundle.localizedString(forKey: key, value: fallback, table: "Localizable")
        return resolved.isEmpty ? fallback : resolved
    }

    // MARK: - Bundle resolution

    private static func lprojName(for language: String) -> String {
        language.lowercased().hasPrefix("en") ? "en.lproj" : "zh-Hans.lproj"
    }

    private static func bundle(for language: String) -> Bundle? {
        guard let url = lprojURL(named: lprojName(for: language)) else { return nil }
        return Bundle(path: url.path)
    }

    /// Recursively locates `<name>` under the module resource bundle so it resolves
    /// regardless of how SwiftPM places the copied `.lproj` directories.
    private static func lprojURL(named name: String) -> URL? {
        let root = Bundle.module.bundleURL
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return nil }
        for case let url as URL in enumerator {
            if url.lastPathComponent == name,
               (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true {
                return url
            }
        }
        return nil
    }
}
