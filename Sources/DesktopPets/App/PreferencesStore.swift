import Foundation

struct AppPreferences: Codable, Equatable, Sendable {
    var paused: Bool
    var petsHidden: Bool
    var clickThrough: Bool
    var launchAtLogin: Bool

    static let defaults = AppPreferences(paused: false, petsHidden: false, clickThrough: true, launchAtLogin: false)
}

struct PreferencesStore {
    static let storageKey = "desktopPets.preferences.v1"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> AppPreferences {
        guard let data = defaults.data(forKey: Self.storageKey),
              let value = try? JSONDecoder().decode(AppPreferences.self, from: data) else { return .defaults }
        return value
    }

    func save(_ preferences: AppPreferences) {
        guard let data = try? JSONEncoder().encode(preferences) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }
}

struct MenuState: Equatable, Sendable {
    let preferences: AppPreferences

    var pauseTitle: String { preferences.paused ? "继续活动" : "暂停活动" }
    var visibilityTitle: String { preferences.petsHidden ? "显示宠物" : "隐藏宠物" }
    var clickThroughTitle: String { preferences.clickThrough ? "关闭点击穿透" : "开启点击穿透" }
}
