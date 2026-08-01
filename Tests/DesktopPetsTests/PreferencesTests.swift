import XCTest
@testable import DesktopPets

final class PreferencesTests: XCTestCase {
    func testDefaultsAreNonBlockingAndVisible() {
        let defaults = makeDefaults()
        let store = PreferencesStore(defaults: defaults)
        XCTAssertEqual(store.load(), AppPreferences(paused: false, petsHidden: false, clickThrough: true, launchAtLogin: false))
    }

    func testRoundTripsPreferences() {
        let defaults = makeDefaults()
        let store = PreferencesStore(defaults: defaults)
        let expected = AppPreferences(paused: true, petsHidden: true, clickThrough: false, launchAtLogin: false)
        store.save(expected)
        XCTAssertEqual(store.load(), expected)
    }

    func testCorruptPreferencesRecoverToDefaults() {
        let defaults = makeDefaults()
        defaults.set(Data("broken".utf8), forKey: PreferencesStore.storageKey)
        XCTAssertEqual(PreferencesStore(defaults: defaults).load(), .defaults)
    }

    private func makeDefaults() -> UserDefaults {
        let suite = "DesktopPetsTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }
}
