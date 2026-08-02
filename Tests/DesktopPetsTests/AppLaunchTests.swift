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

    func testParsesInteractionSelfTestMode() {
        XCTAssertEqual(CommandLineMode.parse(["DesktopPets", "--interaction-self-test"]), .interactionSelfTest)
    }

    @MainActor
    func testInteractionSelfTestExercisesCommandsAndPreservesFourFinitePets() {
        let report = InteractionSelfTest.run()

        XCTAssertEqual(report.status, "ok")
        XCTAssertEqual(report.commandCount, 9)
        XCTAssertEqual(report.petCount, 4)
        XCTAssertTrue(report.allFinite)
    }
}
