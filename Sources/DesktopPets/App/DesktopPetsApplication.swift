import AppKit
import CoreGraphics
import Foundation

struct SelfTestReport: Codable {
    let status: String
    let version: String
    let architecture: String
    let windowEnumerationAvailable: Bool
}

struct GeometryProbeReport: Codable {
    let status: String
    let displayCount: Int
    let acceptedExternalRectangleCount: Int
    let ownerPIDs: [Int32]
}

struct RunningAppReport: Codable {
    let status: String
    let pid: Int32
    let windowCount: Int
}

struct InteractionSelfTestReport: Codable, Equatable {
    let status: String
    let commandCount: Int
    let petCount: Int
    let allFinite: Bool
}

enum InteractionSelfTest {
    static func run() -> InteractionSelfTestReport {
        let display = WorldRect(x: 0, y: 0, width: 1200, height: 800)!
        let map = ObstacleMap(displays: [display], obstacles: [])
        var world = PetWorld(characters: CharacterCatalog.fallback.characters, display: display, seed: 0x1A2B3C)
        let commands: [PetInteraction] = [
            .react(id: "person-left"),
            .gatherAndPlay(leaderID: "person-center-left"),
            .beginDrag(id: "person-center-right", position: WorldPoint(x: 700, y: 500)),
            .drag(id: "person-center-right", position: WorldPoint(x: 720, y: 520)),
            .release(id: "person-center-right", position: WorldPoint(x: 720, y: 520)),
            .togglePause(id: "person-right"),
            .togglePause(id: "person-right"),
            .recall(id: "person-left"),
            .hide(id: "person-right"),
        ]
        let results = commands.map { world.handle($0, obstacles: map) }
        world.step(deltaTime: 1.0 / 60.0, obstacles: map)
        let allFinite = world.poses.allSatisfy { $0.position.isFinite }
        let allHandled = !results.contains(.ignored)
        return InteractionSelfTestReport(
            status: allHandled && allFinite && world.poses.count == 4 ? "ok" : "degraded",
            commandCount: commands.count,
            petCount: world.poses.count,
            allFinite: allFinite
        )
    }
}

@MainActor
final class DesktopPetsApplication {
    private let mode: CommandLineMode
    private var appController: AppController?

    init(mode: CommandLineMode) {
        self.mode = mode
    }

    func run() -> Int32 {
        switch mode {
        case .normal:
            let app = NSApplication.shared
            app.setActivationPolicy(.accessory)
            let controller = AppController()
            appController = controller
            app.delegate = controller
            app.run()
            return EXIT_SUCCESS
        case .selfTest:
            let report = SelfTestReport(
                status: "ok",
                version: "0.1.0",
                architecture: Self.architecture,
                windowEnumerationAvailable: CGWindowListCopyWindowInfo(
                    [.optionOnScreenOnly, .excludeDesktopElements],
                    kCGNullWindowID
                ) != nil
            )
            return printJSON(report)
        case .geometryProbe:
            let snapshot = CGWindowGeometryProvider().snapshot()
            let report = GeometryProbeReport(
                status: snapshot.displays.isEmpty ? "degraded" : "ok",
                displayCount: snapshot.displays.count,
                acceptedExternalRectangleCount: snapshot.obstacles.count,
                ownerPIDs: snapshot.ownerPIDs.sorted()
            )
            return printJSON(report)
        case .interactionSelfTest:
            return printJSON(InteractionSelfTest.run())
        case let .renderSnapshot(path):
            do {
                try ProceduralPetRenderer.renderVerificationSnapshot(
                    characters: CharacterCatalog.fallback.characters,
                    url: URL(fileURLWithPath: path)
                )
                return printJSON(["status": "ok", "path": path])
            } catch {
                FileHandle.standardError.write(Data("Snapshot render failed: \(error)\n".utf8))
                return EXIT_FAILURE
            }
        case let .inspectRunning(pid):
            let count = CGWindowGeometryProvider.rawWindowCount(ownerPID: pid)
            return printJSON(RunningAppReport(status: count >= 4 ? "ok" : "degraded", pid: pid, windowCount: count))
        case let .invalid(message):
            FileHandle.standardError.write(Data("\(message)\n".utf8))
            return EXIT_FAILURE
        }
    }

    private func printJSON<T: Encodable>(_ value: T) -> Int32 {
        do {
            let data = try JSONEncoder().encode(value)
            FileHandle.standardOutput.write(data)
            FileHandle.standardOutput.write(Data("\n".utf8))
            return EXIT_SUCCESS
        } catch {
            FileHandle.standardError.write(Data("Self-test encoding failed: \(error)\n".utf8))
            return EXIT_FAILURE
        }
    }

    private static var architecture: String {
#if arch(arm64)
        "arm64"
#elseif arch(x86_64)
        "x86_64"
#else
        "unknown"
#endif
    }
}
