import AppKit
import Foundation
import OSLog

@MainActor
final class WorldRunner: NSObject {
    private var world: PetWorld
    private let geometryProvider: GeometryProvider
    private let windows: PetWindowCoordinator
    private var obstacleMap: ObstacleMap
    private var timer: Timer?
    private var lastTick = ProcessInfo.processInfo.systemUptime
    private var lastGeometryRefresh = 0.0
    private let logger = Logger(subsystem: "com.codex.DesktopPets", category: "world")

    init(characters: [CharacterManifest], geometryProvider: GeometryProvider) {
        self.geometryProvider = geometryProvider
        let snapshot = geometryProvider.snapshot()
        let fallback = WorldRect(x: 0, y: 0, width: 1440, height: 900)!
        let primary = snapshot.displays.first ?? fallback
        world = PetWorld(characters: characters, display: primary, seed: 0xD35C70)
        obstacleMap = snapshot.displays.isEmpty
            ? ObstacleMap(displays: [fallback], obstacles: [])
            : snapshot.obstacleMap
        windows = PetWindowCoordinator(characters: characters)
        super.init()
        windows.apply(poses: world.poses)
    }

    func start(preferences: AppPreferences) {
        world.setPaused(preferences.paused)
        windows.setClickThrough(preferences.clickThrough)
        preferences.petsHidden ? windows.hide() : windows.show()
        lastTick = ProcessInfo.processInfo.systemUptime
        timer = Timer.scheduledTimer(timeInterval: 1.0 / 30.0, target: self, selector: #selector(tick), userInfo: nil, repeats: true)
        RunLoop.main.add(timer!, forMode: .common)
        logger.info("Started four-pet world runner")
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        windows.hide()
    }

    func setPaused(_ paused: Bool) { world.setPaused(paused) }
    func setHidden(_ hidden: Bool) { hidden ? windows.hide() : windows.show() }
    func setClickThrough(_ enabled: Bool) { windows.setClickThrough(enabled) }

    func recall() {
        let display = obstacleMap.displays.first ?? WorldRect(x: 0, y: 0, width: 1440, height: 900)!
        world.recall(to: display)
        windows.apply(poses: world.poses)
        windows.show()
    }

    var diagnostics: [String: Any] {
        [
            "petCount": world.poses.count,
            "visiblePanelCount": windows.allPanels.filter(\.isVisible).count,
            "displayCount": obstacleMap.displays.count,
            "obstacleCount": obstacleMap.obstacles.count,
            "states": world.poses.map { $0.state.rawValue },
        ]
    }

    @objc private func tick() {
        let now = ProcessInfo.processInfo.systemUptime
        let delta = min(max(now - lastTick, 0), 0.1)
        lastTick = now
        if now - lastGeometryRefresh >= 0.25 {
            let snapshot = geometryProvider.snapshot()
            if !snapshot.displays.isEmpty { obstacleMap = snapshot.obstacleMap }
            lastGeometryRefresh = now
        }
        world.step(deltaTime: delta, obstacles: obstacleMap)
        windows.apply(poses: world.poses)
    }
}
