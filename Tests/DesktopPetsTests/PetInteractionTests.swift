import XCTest
@testable import DesktopPets

final class PetInteractionTests: XCTestCase {
    private let display = WorldRect(x: 0, y: 0, width: 1000, height: 700)!

    func testSingleReactionMakesOnlyTargetGreet() {
        var world = makeWorld()

        let result = world.handle(.react(id: "person-left"), obstacles: map)

        XCTAssertEqual(result, .handled)
        XCTAssertEqual(world.poses.first { $0.id == "person-left" }?.state, .greet)
        XCTAssertFalse(world.poses.filter { $0.id != "person-left" }.contains { $0.state == .greet })
    }

    func testGroupPlayGathersAllPetsAroundLeader() throws {
        var world = makeWorld()

        XCTAssertEqual(world.handle(.gatherAndPlay(leaderID: "person-center-left"), obstacles: map), .handled)

        let leader = try XCTUnwrap(world.poses.first { $0.id == "person-center-left" })
        XCTAssertEqual(leader.state, .greet)
        XCTAssertTrue(world.poses.filter { $0.id != leader.id }.allSatisfy { pose in
            pose.state == .play && abs(pose.position.x - leader.position.x) <= 180
        })
    }

    func testDraggedPetTracksPointerThenFallsOnRelease() throws {
        var world = makeWorld()
        let id = "person-center-right"
        let destination = WorldPoint(x: 700, y: 420)

        XCTAssertEqual(world.handle(.beginDrag(id: id, position: destination), obstacles: map), .handled)
        XCTAssertEqual(world.poses.first { $0.id == id }?.state, .hang)
        XCTAssertEqual(world.poses.first { $0.id == id }?.position, destination)

        XCTAssertEqual(world.handle(.release(id: id, position: destination), obstacles: map), .handled)
        XCTAssertEqual(world.poses.first { $0.id == id }?.state, .fall)
    }

    func testPausedPetFreezesWhileOthersContinue() throws {
        var world = makeWorld()
        let id = "person-right"
        XCTAssertEqual(world.handle(.togglePause(id: id), obstacles: map), .pauseChanged(id: id, paused: true))
        let pausedBefore = try XCTUnwrap(world.poses.first { $0.id == id })
        let movingBefore = try XCTUnwrap(world.poses.first { $0.id == "person-left" })

        world.step(deltaTime: 0.5, obstacles: map)

        XCTAssertEqual(world.poses.first { $0.id == id }, pausedBefore)
        XCTAssertNotEqual(world.poses.first { $0.id == "person-left" }, movingBefore)
        XCTAssertEqual(world.handle(.togglePause(id: id), obstacles: map), .pauseChanged(id: id, paused: false))
    }

    func testDirectReactionResumesIndividuallyPausedPet() throws {
        var world = makeWorld()
        let id = "person-right"
        _ = world.handle(.togglePause(id: id), obstacles: map)

        XCTAssertEqual(world.handle(.react(id: id), obstacles: map), .handled)
        let before = try XCTUnwrap(world.poses.first { $0.id == id })
        world.step(deltaTime: 0.2, obstacles: map)

        XCTAssertNotEqual(world.poses.first { $0.id == id }, before)
    }

    func testRecallRestoresOnePetToSafeVisibleFloor() throws {
        let character = CharacterCatalog.fallback.characters[0]
        let agent = PetAgent(id: character.id, personality: character.personality, position: WorldPoint(x: 950, y: 650), state: .sleep)
        var world = PetWorld(agents: [agent], seed: 3)

        XCTAssertEqual(world.handle(.recall(id: character.id), obstacles: map), .show(id: character.id))

        let pose = try XCTUnwrap(world.poses.first)
        XCTAssertEqual(pose.position, WorldPoint(x: 500, y: 0))
        XCTAssertEqual(pose.state, .crawl)
    }

    func testHideReturnsPanelInstructionAndUnknownIdentifierIsIgnored() {
        var world = makeWorld()

        XCTAssertEqual(world.handle(.hide(id: "person-left"), obstacles: map), .hide(id: "person-left"))
        XCTAssertEqual(world.handle(.react(id: "missing"), obstacles: map), .ignored)
    }

    private var map: ObstacleMap { ObstacleMap(displays: [display], obstacles: []) }

    private func makeWorld() -> PetWorld {
        PetWorld(characters: CharacterCatalog.fallback.characters, display: display, seed: 11)
    }
}

@MainActor
final class WorldRunnerInteractionTests: XCTestCase {
    func testGroupPlayRestoresIndividuallyHiddenPets() {
        let display = WorldRect(x: 0, y: 0, width: 1000, height: 700)!
        let runner = WorldRunner(
            characters: CharacterCatalog.fallback.characters,
            geometryProvider: FixedGeometryProvider(display: display)
        )
        runner.start(preferences: .defaults)
        runner.handle(.hide(id: "person-left"))
        XCTAssertEqual(runner.diagnostics["hiddenPetCount"] as? Int, 1)

        runner.handle(.gatherAndPlay(leaderID: "person-center-left"))

        XCTAssertEqual(runner.diagnostics["hiddenPetCount"] as? Int, 0)
        XCTAssertEqual(runner.diagnostics["visiblePanelCount"] as? Int, 4)
        runner.stop()
    }
}

@MainActor
private final class FixedGeometryProvider: GeometryProvider {
    private let display: WorldRect

    init(display: WorldRect) {
        self.display = display
    }

    func snapshot() -> GeometrySnapshot {
        GeometrySnapshot(displays: [display], obstacles: [], ownerPIDs: [], capturedAt: Date())
    }
}
