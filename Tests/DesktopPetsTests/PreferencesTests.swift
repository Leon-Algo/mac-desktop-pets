import XCTest
@testable import DesktopPets

final class PreferencesTests: XCTestCase {
    func testDefaultsEnableShapeAwareInteractionAndRemainVisible() {
        let defaults = makeDefaults()
        let store = PreferencesStore(defaults: defaults)
        XCTAssertEqual(store.load(), AppPreferences(paused: false, petsHidden: false, clickThrough: false, launchAtLogin: false))
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

    func testControlHintIsShownOnlyOnce() {
        let store = PreferencesStore(defaults: makeDefaults())
        XCTAssertTrue(store.shouldShowControlHint)

        store.markControlHintShown()

        XCTAssertFalse(store.shouldShowControlHint)
    }

    func testAutomatedLaunchCanSuppressHintWithoutMarkingItShown() {
        XCTAssertFalse(ControlHintPolicy.shouldShow(storedHintNeeded: true, suppressionValue: "1"))
        XCTAssertTrue(ControlHintPolicy.shouldShow(storedHintNeeded: true, suppressionValue: nil))
        XCTAssertFalse(ControlHintPolicy.shouldShow(storedHintNeeded: false, suppressionValue: nil))
    }

    private func makeDefaults() -> UserDefaults {
        let suite = "DesktopPetsTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }
}
