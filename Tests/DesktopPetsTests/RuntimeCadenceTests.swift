import XCTest
@testable import DesktopPets

@MainActor
final class RuntimeCadenceTests: XCTestCase {
    func testRuntimeCadenceBalancesSmoothMotionAndWindowPollingCost() {
        XCTAssertEqual(WorldRunner.simulationFramesPerSecond, 20)
        XCTAssertGreaterThanOrEqual(WorldRunner.geometryRefreshInterval, 1.0)
    }
}
