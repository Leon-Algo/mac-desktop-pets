import XCTest
@testable import DesktopPets

final class PetWorldTests: XCTestCase {
    private let display = WorldRect(x: 0, y: 0, width: 1000, height: 700)!

    func testCrawlingMovesHorizontally() {
        var world = makeWorld()
        let before = world.poses[0].position

        world.step(deltaTime: 1.0 / 30.0, obstacles: ObstacleMap(displays: [display], obstacles: []))

        XCTAssertGreaterThan(world.poses[0].position.x, before.x)
        XCTAssertEqual(world.poses[0].state, .crawl)
    }

    func testPauseFreezesAndResumeContinues() {
        var world = makeWorld()
        let map = ObstacleMap(displays: [display], obstacles: [])
        world.setPaused(true)
        let before = world.poses
        world.step(deltaTime: 1, obstacles: map)
        XCTAssertEqual(world.poses, before)

        world.setPaused(false)
        world.step(deltaTime: 1.0 / 30.0, obstacles: map)
        XCTAssertNotEqual(world.poses, before)
    }

    func testRecallPlacesFourPetsSafelyAcrossDisplay() {
        var world = makeWorld()
        world.recall(to: display)

        XCTAssertEqual(world.poses.count, 4)
        XCTAssertTrue(world.poses.allSatisfy { display.contains($0.position) })
        XCTAssertEqual(Set(world.poses.map(\.position.x)).count, 4)
    }

    func testFallingPetLandsOnWindowTop() {
        let character = CharacterCatalog.fallback.characters[0]
        let agent = PetAgent(id: character.id, personality: character.personality, position: WorldPoint(x: 300, y: 500), state: .fall, velocity: WorldVector(dx: 0, dy: -100))
        var world = PetWorld(agents: [agent], seed: 7)
        let window = Obstacle(id: "window", kind: .window, rect: WorldRect(x: 200, y: 100, width: 300, height: 200)!)
        let map = ObstacleMap(displays: [display], obstacles: [window])

        for _ in 0..<120 { world.step(deltaTime: 1.0 / 60.0, obstacles: map) }

        XCTAssertEqual(world.poses[0].position.y, 300, accuracy: 0.001)
        XCTAssertEqual(world.poses[0].state, .crawl)
        XCTAssertEqual(world.poses[0].supportID, "window")
    }

    func testSameSeedProducesSameMotion() {
        var lhs = makeWorld(seed: 42)
        var rhs = makeWorld(seed: 42)
        let map = ObstacleMap(displays: [display], obstacles: [])
        for _ in 0..<1200 {
            lhs.step(deltaTime: 1.0 / 60.0, obstacles: map)
            rhs.step(deltaTime: 1.0 / 60.0, obstacles: map)
        }
        XCTAssertEqual(lhs.poses, rhs.poses)
    }

    func testAcceleratedThirtyMinutesMaintainsFiniteValidState() {
        var world = makeWorld(seed: 91)
        let window = Obstacle(id: "window", kind: .window, rect: WorldRect(x: 180, y: 150, width: 500, height: 280)!)
        let map = ObstacleMap(displays: [display], obstacles: [window])

        for _ in 0..<(30 * 60 * 10) {
            world.step(deltaTime: 0.1, obstacles: map)
        }

        XCTAssertEqual(world.poses.count, 4)
        XCTAssertTrue(world.poses.allSatisfy { $0.position.isFinite && display.contains($0.position) })
    }

    private func makeWorld(seed: UInt64 = 1) -> PetWorld {
        PetWorld(characters: CharacterCatalog.fallback.characters, display: display, seed: seed)
    }
}
