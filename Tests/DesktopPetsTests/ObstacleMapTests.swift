import XCTest
@testable import DesktopPets

final class ObstacleMapTests: XCTestCase {
    private let display = WorldRect(x: 0, y: 0, width: 1200, height: 800)!

    func testRejectsNonFiniteAndZeroSizedRectangles() {
        XCTAssertNil(WorldRect(x: 0, y: 0, width: 0, height: 10))
        XCTAssertNil(WorldRect(x: .nan, y: 0, width: 10, height: 10))
        XCTAssertNotNil(WorldRect(x: 0, y: 0, width: 10, height: 10))
    }

    func testSelectsHighestSupportingWindowBelowPoint() {
        let low = Obstacle(id: "low", kind: .window, rect: WorldRect(x: 100, y: 100, width: 300, height: 200)!)
        let high = Obstacle(id: "high", kind: .window, rect: WorldRect(x: 120, y: 350, width: 250, height: 200)!)
        let map = ObstacleMap(displays: [display], obstacles: [low, high])

        let surface = map.supportingSurface(below: WorldPoint(x: 200, y: 700), within: 500)

        XCTAssertEqual(surface?.obstacleID, "high")
        XCTAssertEqual(surface?.y, 550)
    }

    func testIgnoresSurfaceOutsideHorizontalReach() {
        let obstacle = Obstacle(id: "window", kind: .window, rect: WorldRect(x: 100, y: 100, width: 300, height: 200)!)
        let map = ObstacleMap(displays: [display], obstacles: [obstacle])

        let surface = map.supportingSurface(below: WorldPoint(x: 900, y: 500), within: 500)

        XCTAssertEqual(surface?.kind, .screenFloor)
        XCTAssertEqual(surface?.y, 0)
    }

    func testFindsNearestClimbableSide() {
        let obstacle = Obstacle(id: "window", kind: .window, rect: WorldRect(x: 200, y: 100, width: 300, height: 300)!)
        let map = ObstacleMap(displays: [display], obstacles: [obstacle])

        let edge = map.nearestClimbableEdge(to: WorldPoint(x: 185, y: 250), within: 30)

        XCTAssertEqual(edge?.obstacleID, "window")
        XCTAssertEqual(edge?.x, 200)
        XCTAssertEqual(edge?.side, .left)
    }

    func testDetectsWindowSideCrossedByHorizontalCrawl() {
        let obstacle = Obstacle(id: "window", kind: .window, rect: WorldRect(x: 200, y: 100, width: 300, height: 300)!)
        let map = ObstacleMap(displays: [display], obstacles: [obstacle])

        let enteringFromLeft = map.crossedClimbableEdge(fromX: 190, toX: 210, atY: 120)
        let enteringFromRight = map.crossedClimbableEdge(fromX: 510, toX: 490, atY: 120)

        XCTAssertEqual(enteringFromLeft?.x, 200)
        XCTAssertEqual(enteringFromLeft?.side, .left)
        XCTAssertEqual(enteringFromRight?.x, 500)
        XCTAssertEqual(enteringFromRight?.side, .right)
        XCTAssertNil(map.crossedClimbableEdge(fromX: 190, toX: 210, atY: 50))
    }

    func testClampsPointToNearestOfMultipleDisplays() {
        let second = WorldRect(x: 1200, y: 0, width: 800, height: 600)!
        let map = ObstacleMap(displays: [display, second], obstacles: [])

        XCTAssertEqual(
            map.clamped(WorldPoint(x: 2100, y: 700), margin: 20),
            WorldPoint(x: 1980, y: 580)
        )
    }

    func testClampsPetAnchorWithPanelSafeMargins() {
        let map = ObstacleMap(displays: [display], obstacles: [])
        XCTAssertEqual(
            map.clampedPetAnchor(WorldPoint(x: -50, y: 900), halfWidth: 90, topClearance: 140),
            WorldPoint(x: 90, y: 660)
        )
        XCTAssertEqual(
            map.clampedPetAnchor(WorldPoint(x: 1300, y: -20), halfWidth: 90, topClearance: 140),
            WorldPoint(x: 1110, y: 0)
        )
    }
}
