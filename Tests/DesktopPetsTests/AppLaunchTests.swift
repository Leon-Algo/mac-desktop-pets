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
}
