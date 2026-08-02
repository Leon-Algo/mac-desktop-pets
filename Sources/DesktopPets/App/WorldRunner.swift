import AppKit
import Foundation
import OSLog

@MainActor
final class WorldRunner: NSObject {
    static let simulationFramesPerSecond = 20
    static let geometryRefreshInterval = 1.0
    private var world: PetWorld
    private let geometryProvider: GeometryProvider
    private var windows: PetWindowCoordinator!
    private var obstacleMap: ObstacleMap
    private var timer: Timer?
    private var lastTick = ProcessInfo.processInfo.systemUptime
    private var lastGeometryRefresh = 0.0
    private var fullyClickThrough = false
    private var hiddenPetIDs: Set<String> = []
    private let characters: [CharacterManifest]
    private let logger = Logger(subsystem: "com.codex.DesktopPets", category: "world")
    var onControlStateChange: (([PetControlState]) -> Void)?
    var onUICommand: ((ControlCenterCommand) -> Void)?

    init(characters: [CharacterManifest], geometryProvider: GeometryProvider) {
        self.characters = characters
        self.geometryProvider = geometryProvider
        let snapshot = geometryProvider.snapshot()
        let fallback = WorldRect(x: 0, y: 0, width: 1440, height: 900)!
        let primary = snapshot.displays.first ?? fallback
        world = PetWorld(characters: characters, display: primary, seed: 0xD35C70)
        obstacleMap = snapshot.displays.isEmpty
            ? ObstacleMap(displays: [fallback], obstacles: [])
            : snapshot.obstacleMap
        super.init()
        windows = PetWindowCoordinator(characters: characters) { [weak self] interaction in
            self?.handle(interaction)
        }
        windows.apply(poses: world.poses)
    }

    func start(preferences: AppPreferences) {
        world.setPaused(preferences.paused)
        fullyClickThrough = preferences.clickThrough
        hiddenPetIDs = preferences.petsHidden ? Set(characters.map(\.id)) : []
        preferences.petsHidden ? windows.hide() : windows.show()
        lastTick = ProcessInfo.processInfo.systemUptime
        timer = Timer.scheduledTimer(
            timeInterval: 1.0 / Double(Self.simulationFramesPerSecond),
            target: self,
            selector: #selector(tick),
            userInfo: nil,
            repeats: true
        )
        RunLoop.main.add(timer!, forMode: .common)
        logger.info("Started four-pet world runner")
        notifyControlStateChanged()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        windows.hide()
    }

    func setPaused(_ paused: Bool) { world.setPaused(paused) }
    func setHidden(_ hidden: Bool) {
        if hidden {
            hiddenPetIDs = Set(characters.map(\.id))
            windows.hide()
        } else {
            hiddenPetIDs.removeAll()
            windows.show()
        }
        notifyControlStateChanged()
    }

    func setClickThrough(_ enabled: Bool) {
        fullyClickThrough = enabled
        windows.updateMouseAcceptance(at: NSEvent.mouseLocation, fullyClickThrough: enabled)
    }

    func recall() {
        let display = obstacleMap.displays.first ?? WorldRect(x: 0, y: 0, width: 1440, height: 900)!
        world.recall(to: display)
        hiddenPetIDs.removeAll()
        windows.apply(poses: world.poses)
        windows.show()
        notifyControlStateChanged()
    }

    var diagnostics: [String: Any] {
        [
            "petCount": world.poses.count,
            "visiblePanelCount": windows.allPanels.filter(\.isVisible).count,
            "displayCount": obstacleMap.displays.count,
            "obstacleCount": obstacleMap.obstacles.count,
            "states": world.poses.map { $0.state.rawValue },
            "interactionMode": fullyClickThrough ? "full-pass-through" : "shape-aware",
            "hiddenPetCount": hiddenPetIDs.count,
        ]
    }

    var controlSnapshot: [PetControlState] {
        characters.map {
            PetControlState(
                id: $0.id,
                displayName: $0.displayName,
                isHidden: hiddenPetIDs.contains($0.id),
                isPaused: world.isPaused(id: $0.id)
            )
        }
    }

    func handle(_ interaction: PetInteraction) {
        switch interaction {
        case .recallAll:
            recall()
            return
        case .openControlCenter:
            onUICommand?(.openControlCenter)
            return
        case .quitApplication:
            onUICommand?(.quitApplication)
            return
        default:
            break
        }
        if case .gatherAndPlay = interaction {
            hiddenPetIDs.removeAll()
            windows.show()
        }
        let result = world.handle(interaction, obstacles: obstacleMap)
        switch result {
        case let .hide(id):
            hiddenPetIDs.insert(id)
            windows.hide(identifier: id)
        case let .show(id):
            hiddenPetIDs.remove(id)
            windows.show(identifier: id)
        case .handled, .pauseChanged:
            break
        case .ignored:
            logger.warning("Ignored interaction for unknown pet")
        }
        windows.apply(poses: world.poses)
        notifyControlStateChanged()
    }

    private func notifyControlStateChanged() {
        onControlStateChange?(controlSnapshot)
    }

    @objc private func tick() {
        let now = ProcessInfo.processInfo.systemUptime
        let delta = min(max(now - lastTick, 0), 0.1)
        lastTick = now
        if now - lastGeometryRefresh >= Self.geometryRefreshInterval {
            let snapshot = geometryProvider.snapshot()
            if !snapshot.displays.isEmpty { obstacleMap = snapshot.obstacleMap }
            lastGeometryRefresh = now
        }
        world.step(deltaTime: delta, obstacles: obstacleMap)
        windows.apply(poses: world.poses)
        windows.updateMouseAcceptance(at: NSEvent.mouseLocation, fullyClickThrough: fullyClickThrough)
    }
}
