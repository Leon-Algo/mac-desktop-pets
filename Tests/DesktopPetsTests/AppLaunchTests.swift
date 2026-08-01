import XCTest
@testable import DesktopPets

final class AppLaunchTests: XCTestCase {
    func testParsesSelfTestMode() {
        XCTAssertEqual(CommandLineMode.parse(["DesktopPets", "--self-test"]), .selfTest)
    }

    func testDefaultsToNormalMode() {
        XCTAssertEqual(CommandLineMode.parse(["DesktopPets"]), .normal)
    }

    func testUnknownArgumentIsRejected() {
        XCTAssertEqual(
            CommandLineMode.parse(["DesktopPets", "--surprise"]),
            .invalid("Unknown argument: --surprise")
        )
    }

    func testParsesGeometryProbeMode() {
        XCTAssertEqual(CommandLineMode.parse(["DesktopPets", "--geometry-probe"]), .geometryProbe)
    }

    func testParsesRenderSnapshotModeWithPath() {
        XCTAssertEqual(
            CommandLineMode.parse(["DesktopPets", "--render-snapshot", "/tmp/pets.png"]),
            .renderSnapshot("/tmp/pets.png")
        )
    }

    func testParsesInspectRunningPID() {
        XCTAssertEqual(
            CommandLineMode.parse(["DesktopPets", "--inspect-running", "1234"]),
            .inspectRunning(1234)
        )
    }
}
