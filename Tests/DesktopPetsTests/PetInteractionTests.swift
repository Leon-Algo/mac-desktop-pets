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

    func testManualActionsEnterDistinctStates() {
        let cases: [(PetActionID, PetState)] = [
            (.wave, .greet),
            (.hop, .jump),
            (.roll, .roll),
            (.sleep, .sleep),
        ]

        for (actionID, expectedState) in cases {
            var world = makeWorld()
            let result = world.handle(
                .performAction(PetActionRequest(actionID: actionID, targetID: "person-left")),
                obstacles: map
            )
            guard case let .action(.performed(ids, _, _)) = result else {
                return XCTFail("Expected performed outcome for \(actionID)")
            }
            XCTAssertEqual(ids, ["person-left"])
            XCTAssertEqual(world.poses.first { $0.id == "person-left" }?.state, expectedState)
        }
    }

    func testManualActionResumesOnlyIndividualPauseButRespectsGlobalPause() throws {
        var world = makeWorld()
        _ = world.handle(.togglePause(id: "person-left"), obstacles: map)

        let resumed = world.handle(
            .performAction(PetActionRequest(actionID: .wave, targetID: "person-left")),
            obstacles: map
        )
        guard case .action(.performed) = resumed else { return XCTFail("Expected performed action") }
        XCTAssertEqual(world.poses.first { $0.id == "person-left" }?.state, .greet)

        world.setPaused(true)
        let before = world.poses
        let blocked = world.handle(
            .performAction(PetActionRequest(actionID: .roll, targetID: "person-left")),
            obstacles: map
        )
        XCTAssertEqual(
            blocked,
            .action(.unavailable(
                targetID: "person-left",
                feedback: "当前已暂停，请先继续活动",
                duration: 2
            ))
        )
        XCTAssertEqual(world.poses, before)
    }

    func testManualActionsExpireAndRollPhaseDoesNotWrap() throws {
        var rollWorld = makeWorld()
        _ = rollWorld.handle(
            .performAction(PetActionRequest(actionID: .roll, targetID: "person-left")),
            obstacles: map
        )
        rollWorld.step(deltaTime: 0.7, obstacles: map)
        XCTAssertEqual(
            try XCTUnwrap(rollWorld.poses.first { $0.id == "person-left" }).phase,
            0.5,
            accuracy: 0.02
        )
        rollWorld.step(deltaTime: 0.75, obstacles: map)
        XCTAssertEqual(rollWorld.poses.first { $0.id == "person-left" }?.state, .crawl)

        var sleepWorld = makeWorld()
        _ = sleepWorld.handle(
            .performAction(PetActionRequest(actionID: .sleep, targetID: "person-left")),
            obstacles: map
        )
        for _ in 0..<5 {
            sleepWorld.step(deltaTime: 0.9, obstacles: map)
        }
        XCTAssertEqual(sleepWorld.poses.first { $0.id == "person-left" }?.state, .crawl)
    }

    func testGroupActionUsesAllCharactersAndInvalidTargetDoesNotMutate() {
        var world = makeWorld()
        let result = world.handle(
            .performAction(PetActionRequest(actionID: .gatherPlay, targetID: nil)),
            obstacles: map
        )
        guard case let .action(.performed(ids, _, _)) = result else {
            return XCTFail("Expected group action")
        }
        XCTAssertEqual(Set(ids), Set(CharacterCatalog.fallback.characters.map(\.id)))

        var invalidWorld = makeWorld()
        let before = invalidWorld.poses
        let invalid = invalidWorld.handle(
            .performAction(PetActionRequest(actionID: .wave, targetID: "missing")),
            obstacles: map
        )
        guard case .action(.unavailable) = invalid else { return XCTFail("Expected unavailable action") }
        XCTAssertEqual(invalidWorld.poses, before)
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
