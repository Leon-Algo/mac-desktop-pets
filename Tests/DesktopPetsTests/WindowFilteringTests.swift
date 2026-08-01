import XCTest
@testable import DesktopPets

final class WindowFilteringTests: XCTestCase {
    private let display = WorldRect(x: 0, y: 0, width: 1440, height: 900)!

    func testAcceptsNormalExternalWindowAndConvertsTopLeftCoordinates() {
        let record = RawWindowRecord(id: 7, ownerPID: 101, layer: 0, alpha: 1, bounds: WorldRect(x: 100, y: 100, width: 500, height: 400)!, ownerName: "TextEdit", isOnScreen: true)

        let obstacles = WindowFilter.normalize(records: [record], ownPID: 999, mainScreenMaxY: 900, displayBounds: [display])

        XCTAssertEqual(obstacles, [Obstacle(id: "window-7", kind: .window, rect: WorldRect(x: 100, y: 400, width: 500, height: 400)!)])
    }

    func testRejectsOwnProcessSystemLayersInvisibleAndTinyWindows() {
        let records = [
            RawWindowRecord(id: 1, ownerPID: 999, layer: 0, alpha: 1, bounds: rect(100, 100), ownerName: "DesktopPets", isOnScreen: true),
            RawWindowRecord(id: 2, ownerPID: 100, layer: 25, alpha: 1, bounds: rect(300, 300), ownerName: "SystemUIServer", isOnScreen: true),
            RawWindowRecord(id: 3, ownerPID: 101, layer: 0, alpha: 0, bounds: rect(300, 300), ownerName: "Hidden", isOnScreen: true),
            RawWindowRecord(id: 4, ownerPID: 102, layer: 0, alpha: 1, bounds: rect(300, 300), ownerName: "Offscreen", isOnScreen: false),
            RawWindowRecord(id: 5, ownerPID: 103, layer: 0, alpha: 1, bounds: rect(40, 40), ownerName: "Tiny", isOnScreen: true),
        ]

        XCTAssertTrue(WindowFilter.normalize(records: records, ownPID: 999, mainScreenMaxY: 900, displayBounds: [display]).isEmpty)
    }

    func testRejectsWindowThatDoesNotIntersectAnyDisplay() {
        let record = RawWindowRecord(id: 8, ownerPID: 101, layer: 0, alpha: 1, bounds: WorldRect(x: 4000, y: 100, width: 500, height: 400)!, ownerName: "Elsewhere", isOnScreen: true)
        XCTAssertTrue(WindowFilter.normalize(records: [record], ownPID: 999, mainScreenMaxY: 900, displayBounds: [display]).isEmpty)
    }

    private func rect(_ width: Double, _ height: Double) -> WorldRect {
        WorldRect(x: 10, y: 10, width: width, height: height)!
    }
}
