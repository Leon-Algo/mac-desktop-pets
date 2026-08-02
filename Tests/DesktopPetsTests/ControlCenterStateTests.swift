import XCTest
@testable import DesktopPets

final class ControlCenterStateTests: XCTestCase {
    @MainActor
    func testControlSnapshotReportsPerPetHiddenAndPausedState() throws {
        let runner = WorldRunner(
            characters: CharacterCatalog.fallback.characters,
            geometryProvider: ControlCenterFixedGeometryProvider()
        )
        runner.handle(.togglePause(id: "person-left"))
        runner.handle(.hide(id: "person-right"))

        let states = Dictionary(uniqueKeysWithValues: runner.controlSnapshot.map { ($0.id, $0) })
        XCTAssertEqual(states.count, 4)
        XCTAssertTrue(try XCTUnwrap(states["person-left"]).isPaused)
        XCTAssertFalse(try XCTUnwrap(states["person-left"]).isHidden)
        XCTAssertTrue(try XCTUnwrap(states["person-right"]).isHidden)
        XCTAssertFalse(try XCTUnwrap(states["person-right"]).isPaused)
        runner.stop()
    }

    func testStatusHealthPolicyRepairsOnceThenFallsBackUntilRecovery() {
        var policy = StatusItemHealthPolicy()
        let unhealthy = StatusItemHealthSnapshot(
            isMarkedVisible: true,
            hasButton: true,
            hasWindow: false
        )

        XCTAssertEqual(policy.observe(unhealthy), .recreate)
        XCTAssertEqual(policy.observe(unhealthy), .showFallback)
        XCTAssertEqual(policy.observe(unhealthy), .showFallback)
        XCTAssertEqual(policy.observe(.healthy), .none)
        XCTAssertEqual(policy.observe(unhealthy), .recreate)
    }

    func testMarkedInvisibleStatusItemIsUnhealthy() {
        let snapshot = StatusItemHealthSnapshot(
            isMarkedVisible: false,
            hasButton: true,
            hasWindow: true
        )

        XCTAssertFalse(snapshot.isHealthy)
    }

    func testHidingAllCharactersRequiresFallbackControl() {
        let hidden = CharacterCatalog.fallback.characters.map {
            PetControlState(id: $0.id, displayName: $0.displayName, isHidden: true, isPaused: false)
        }
        let oneVisible = hidden.enumerated().map { index, state in
            PetControlState(
                id: state.id,
                displayName: state.displayName,
                isHidden: index != 0,
                isPaused: state.isPaused
            )
        }

        XCTAssertTrue(ControlCenterVisibilityPolicy.mustShowFallback(globalHidden: false, characters: hidden))
        XCTAssertTrue(ControlCenterVisibilityPolicy.mustShowFallback(globalHidden: true, characters: oneVisible))
        XCTAssertFalse(ControlCenterVisibilityPolicy.mustShowFallback(globalHidden: false, characters: oneVisible))
    }
}

@MainActor
private final class ControlCenterFixedGeometryProvider: GeometryProvider {
    func snapshot() -> GeometrySnapshot {
        GeometrySnapshot(
            displays: [WorldRect(x: 0, y: 0, width: 1200, height: 800)!],
            obstacles: [],
            ownerPIDs: [],
            capturedAt: Date()
        )
    }
}
