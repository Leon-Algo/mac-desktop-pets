import Foundation
import DesktopPetsCore

/// WindowsShell 共享业务逻辑（纯 Foundation，双端可编译可测试）。
/// Win32 专属的窗口/消息循环代码都在 `#if os(Windows)` 内，
/// macOS/CI 上编译为桩，但下面的模拟推进、姿态→屏幕坐标映射、
/// 自检断言与 Windows 上运行的完全一致。
struct ShellModel {
    static let windowWidth = 180
    static let windowHeight = 160
    static let groundOffset = 20.0
    static let simulationFPS = 20.0

    let characters: [CharacterManifest]
    var world: PetWorld
    var obstacleMap: ObstacleMap
    var lastError: String?

    init(characters: [CharacterManifest], display: WorldRect, seed: UInt64 = 0xD35C70) {
        self.characters = characters
        self.world = PetWorld(characters: characters, display: display, seed: seed)
        self.obstacleMap = ObstacleMap(displays: [display], obstacles: [])
    }

    /// 推进一帧并产出每个宠物的窗口位置（窗口左上角，屏幕坐标，y 向下）。
    /// 语义与 macOS PetWindowCoordinator.apply(poses:) 一致。
    mutating func tick(deltaTime: Double) -> [(id: String, x: Int, y: Int, pose: PetPose, canvas: PetCanvas)] {
        world.step(deltaTime: deltaTime, obstacles: obstacleMap)
        let display = obstacleMap.displays[0]
        return world.poses.map { pose in
            let originX = pose.position.x - Double(Self.windowWidth) / 2
            let originY = display.maxY - pose.position.y - Self.groundOffset
            let canvas = PetCanvas.render(character: manifest(for: pose.id), pose: pose)
            return (pose.id, Int(originX.rounded()), Int(originY.rounded()), pose, canvas)
        }
    }

    func manifest(for id: String) -> CharacterManifest {
        characters.first { $0.id == id }
            ?? CharacterManifest(
                id: id,
                displayName: id,
                atlasName: nil,
                palette: CharacterPalette(skin: "#D8A080", hair: "#1E1715", shirt: "#B9A88A", accent: "#5D655E"),
                personality: Personality(speed: 0.5, curiosity: 0.5, sociability: 0.5, courage: 0.5, sleepiness: 0.5),
                anchor: NormalizedPoint(x: 0.5, y: 0.08),
                collisionBody: FrameRect(x: 0.15, y: 0.04, width: 0.7, height: 0.72),
                animations: Self.defaultAnimations()
            )
    }

    static func defaultAnimations() -> [String: AnimationClip] {
        let frame = FrameRect(x: 0, y: 0, width: 1, height: 1)
        let clip = AnimationClip(frames: [frame], fps: 8)
        return Dictionary(uniqueKeysWithValues: ["idle", "crawl", "turn", "climb", "hang", "jump", "fall", "sleep", "chase", "greet", "play"].map { ($0, clip) })
    }

    static func fallbackCharacters() -> [CharacterManifest] {
        let profiles: [(String, String, CharacterPalette, Personality)] = [
            ("person-left", "格子衫", .init(skin: "#D8A080", hair: "#1E1715", shirt: "#B9A88A", accent: "#5D655E"), .init(speed: 0.46, curiosity: 0.70, sociability: 0.62, courage: 0.42, sleepiness: 0.35)),
            ("person-center-left", "黑背心", .init(skin: "#D49A76", hair: "#171313", shirt: "#171717", accent: "#F5F0E8"), .init(speed: 0.70, curiosity: 0.72, sociability: 0.80, courage: 0.78, sleepiness: 0.22)),
            ("person-center-right", "薄荷衫", .init(skin: "#D39A7D", hair: "#3A241B", shirt: "#A9D8CF", accent: "#403632"), .init(speed: 0.52, curiosity: 0.58, sociability: 0.74, courage: 0.48, sleepiness: 0.42)),
            ("person-right", "黑外套", .init(skin: "#B97D5E", hair: "#151313", shirt: "#272727", accent: "#EFE4DC"), .init(speed: 0.62, curiosity: 0.66, sociability: 0.68, courage: 0.66, sleepiness: 0.30)),
        ]
        return profiles.map { id, name, palette, personality in
            CharacterManifest(
                id: id,
                displayName: name,
                atlasName: nil,
                palette: palette,
                personality: personality,
                anchor: NormalizedPoint(x: 0.5, y: 0.08),
                collisionBody: FrameRect(x: 0.15, y: 0.04, width: 0.7, height: 0.72),
                animations: defaultAnimations()
            )
        }
    }

    // MARK: - 无头自检（Windows 与 macOS 跑同一份断言）

    /// 返回 nil 表示全部通过；否则返回失败原因列表。
    static func runSelfCheck() -> [String] {
        var failures: [String] = []
        let display = WorldRect(x: 0, y: 0, width: 1920, height: 1080)!
        var model = ShellModel(characters: fallbackCharacters(), display: display)

        // 1) 渲染：画布非空、有可见像素、尺寸正确。
        let frames = model.tick(deltaTime: 1.0 / Self.simulationFPS)
        if frames.count != 4 { failures.append("expected 4 pet frames, got \(frames.count)") }
        for frame in frames {
            if frame.canvas.width != Self.windowWidth || frame.canvas.height != Self.windowHeight {
                failures.append("canvas size mismatch for \(frame.id)")
            }
            if frame.canvas.opaquePixelCount < 100 {
                failures.append("canvas nearly empty for \(frame.id): \(frame.canvas.opaquePixelCount) opaque pixels")
            }
            if frame.canvas.pixels.count != Self.windowWidth * Self.windowHeight * 4 {
                failures.append("pixel buffer size mismatch for \(frame.id)")
            }
        }

        // 2) 600 帧长时：位置有限、在屏内、画布持续非空。
        var sawNonCrawl = false
        for _ in 0..<600 {
            for frame in model.tick(deltaTime: 1.0 / Self.simulationFPS) {
                if !frame.pose.position.isFinite { failures.append("non-finite position for \(frame.id)") }
                if !display.contains(frame.pose.position) { failures.append("out-of-display for \(frame.id)") }
                if frame.pose.state != .crawl { sawNonCrawl = true }
            }
        }
        if !sawNonCrawl { failures.append("600 frames without any state transition is suspicious") }

        // 3) 渲染确定性：同姿态两次渲染逐位一致。
        let pose = model.world.poses[0]
        let lhs = PetCanvas.render(character: model.characters[0], pose: pose)
        let rhs = PetCanvas.render(character: model.characters[0], pose: pose)
        if lhs.pixels != rhs.pixels { failures.append("renderer not deterministic") }

        // 4) 十六进制配色解析。
        if PetCanvas.parseHex("#FF8000") != (255, 128, 0) { failures.append("hex parse mismatch") }

        return failures
    }
}
