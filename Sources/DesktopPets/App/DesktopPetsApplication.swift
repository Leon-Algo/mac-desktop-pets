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

struct RunningAppReport: Codable, Equatable {
    let status: String
    let pid: Int32
    let windowCount: Int
    let petWindowCount: Int
    let fallbackControlPresent: Bool
}

struct RunningWindowDescriptor: Equatable, Sendable {
    let name: String
    let width: Double
    let height: Double
}

enum RunningAppInspection {
    static func evaluate(pid: Int32, windows: [RunningWindowDescriptor]) -> RunningAppReport {
        var fallbackControlPresent = windows.contains {
            $0.name == "桌面伙伴总台" && abs($0.width - 96) <= 1 && abs($0.height - 38) <= 1
        }
        let unnamed = windows.filter { $0.name.isEmpty }
        var uniformPetCount = 0
        for preset in PetScalePreset.allCases {
            let factors = unnamed.compactMap { descriptor -> Double? in
                let factor = descriptor.width / preset.panelSize.width
                guard (0.5...1.05).contains(factor),
                      abs(descriptor.height - preset.panelSize.height * factor) <= 2 else { return nil }
                return factor
            }
            guard (1...CharacterRoster.maximumCount).contains(unnamed.count),
                  factors.count == unnamed.count,
                  (factors.max() ?? 0) - (factors.min() ?? 0) <= 0.03 else { continue }
            uniformPetCount = factors.count
            let factor = factors.reduce(0, +) / Double(factors.count)
            if windows.contains(where: {
                $0.name == "桌面伙伴总台"
                    && abs($0.width - 96 * factor) <= 2
                    && abs($0.height - 38 * factor) <= 2
            }) {
                fallbackControlPresent = true
            }
            break
        }
        let petWindowCount = uniformPetCount > 0 ? uniformPetCount : PetScalePreset.allCases.reduce(0) { count, preset in
            count + unnamed.filter {
                abs($0.width - preset.panelSize.width) <= 1
                    && abs($0.height - preset.panelSize.height) <= 1
            }.count
        }
        return RunningAppReport(
            status: fallbackControlPresent && uniformPetCount > 0 ? "ok" : "degraded",
            pid: pid,
            windowCount: windows.count,
            petWindowCount: petWindowCount,
            fallbackControlPresent: fallbackControlPresent
        )
    }
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
            .performAction(PetActionRequest(actionID: .wave, targetID: "person-left")),
            .performAction(PetActionRequest(actionID: .hop, targetID: "person-center-left")),
            .performAction(PetActionRequest(actionID: .roll, targetID: "person-center-right")),
            .performAction(PetActionRequest(actionID: .callDad, targetID: "person-right")),
            .performAction(PetActionRequest(actionID: .groupCallDad, targetID: nil)),
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
            ProcessInfo.processInfo.disableAutomaticTermination(
                "Desktop pets are initializing their persistent controls"
            )
            ProcessInfo.processInfo.disableSuddenTermination()
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
            let windows = CGWindowGeometryProvider.runningWindowDescriptors(ownerPID: pid)
            return printJSON(RunningAppInspection.evaluate(pid: pid, windows: windows))
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
