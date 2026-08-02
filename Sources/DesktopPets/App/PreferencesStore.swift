import Foundation

enum PetScalePreset: String, Codable, CaseIterable, Sendable {
    case quarter
    case half
    case original

    var factor: Double {
        switch self {
        case .quarter: 0.25
        case .half: 0.5
        case .original: 1.0
        }
    }

    var menuTitle: String {
        switch self {
        case .quarter: "25%（最小）"
        case .half: "50%（推荐）"
        case .original: "100%（原样）"
        }
    }

    var panelSize: CGSize {
        CGSize(width: 180 * factor, height: 160 * factor)
    }
}

struct AppPreferences: Codable, Equatable, Sendable {
    var paused: Bool
    var petsHidden: Bool
    var clickThrough: Bool
    var launchAtLogin: Bool
    var petScale: PetScalePreset

    init(
        paused: Bool,
        petsHidden: Bool,
        clickThrough: Bool,
        launchAtLogin: Bool,
        petScale: PetScalePreset = .half
    ) {
        self.paused = paused
        self.petsHidden = petsHidden
        self.clickThrough = clickThrough
        self.launchAtLogin = launchAtLogin
        self.petScale = petScale
    }

    private enum CodingKeys: String, CodingKey {
        case paused
        case petsHidden
        case clickThrough
        case launchAtLogin
        case petScale
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        paused = try container.decode(Bool.self, forKey: .paused)
        petsHidden = try container.decode(Bool.self, forKey: .petsHidden)
        clickThrough = try container.decode(Bool.self, forKey: .clickThrough)
        launchAtLogin = try container.decode(Bool.self, forKey: .launchAtLogin)
        petScale = try container.decodeIfPresent(PetScalePreset.self, forKey: .petScale) ?? .half
    }

    static let defaults = AppPreferences(
        paused: false,
        petsHidden: false,
        clickThrough: false,
        launchAtLogin: false,
        petScale: .half
    )
}

struct PreferencesStore {
    static let storageKey = "desktopPets.preferences.v1"
    static let controlHintKey = "desktopPets.didShowControlHint.v1"
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

    var hasStoredPreferences: Bool { defaults.data(forKey: Self.storageKey) != nil }

    var shouldShowControlHint: Bool {
        !defaults.bool(forKey: Self.controlHintKey)
    }

    func markControlHintShown() {
        defaults.set(true, forKey: Self.controlHintKey)
    }
}

struct MenuState: Equatable, Sendable {
    let preferences: AppPreferences

    var pauseTitle: String { preferences.paused ? "继续活动" : "暂停活动" }
    var visibilityTitle: String { preferences.petsHidden ? "显示宠物" : "隐藏宠物" }
    var clickThroughTitle: String { preferences.clickThrough ? "启用人物交互" : "完全点击穿透" }
}

enum ControlHintPolicy {
    static let guidance = "使用顶部菜单栏的 🐾 图标，或桌面上的 🐾 总台，可以暂停、召回、设置或退出桌面伙伴。"

    static func shouldShow(storedHintNeeded: Bool, suppressionValue: String?) -> Bool {
        storedHintNeeded && suppressionValue != "1"
    }
}

enum VerificationLaunchPolicy {
    static func preferences(from stored: AppPreferences, forceVisibleValue: String?) -> AppPreferences {
        guard forceVisibleValue == "1" else { return stored }
        var visible = stored
        visible.petsHidden = false
        return visible
    }
}
