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

    init(characters: [CharacterManifest], displays: [WorldRect], seed: UInt64 = 0xD35C70) {
        self.characters = characters
        let resolved = MonitorLayout.resolve(displays)
        self.world = PetWorld(characters: characters, display: MonitorLayout.homeDisplay(in: resolved), seed: seed)
        self.obstacleMap = ObstacleMap(displays: resolved, obstacles: [])
    }

    /// 便捷构造：单显示器（自检/兼容旧调用）。
    init(characters: [CharacterManifest], display: WorldRect, seed: UInt64 = 0xD35C70) {
        self.init(characters: characters, displays: [display], seed: seed)
    }

    /// 推进一帧并产出每个宠物的窗口位置（窗口左上角，虚拟屏幕坐标，y 向下）。
    /// 语义与 macOS PetWindowCoordinator.apply(poses:) 一致：
    /// 宠物锚点贴所在显示器底边 groundOffset 像素处。
    /// 多显示器：按宠物锚点距哪个显示器更近归位到该显示器。
    mutating func tick(deltaTime: Double) -> [(id: String, x: Int, y: Int, pose: PetPose, canvas: PetCanvas)] {
        world.step(deltaTime: deltaTime, obstacles: obstacleMap)
        return world.poses.map { pose in
            let display = obstacleMap.displays.min {
                $0.squaredDistance(to: pose.position) < $1.squaredDistance(to: pose.position)
            } ?? MonitorLayout.fallbackMonitor
            let origin = ScreenBridge.windowOrigin(petX: pose.position.x, petY: pose.position.y, displayBottomY: display.maxY)
            let canvas = PetCanvas.render(character: manifest(for: pose.id), pose: pose)
            return (pose.id, origin.x, origin.y, pose, canvas)
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

    // MARK: - 交互入口（Win32 壳把指针事件转成 PetInteraction）

    /// 单击 → react（打招呼）；双击 → gatherAndPlay；拖拽 → beginDrag/drag。
    mutating func handle(beginDrag id: String, screenX: Double, screenY: Double) {
        let anchor = anchorPoint(fromScreenX: screenX, screenY: screenY)
        _ = world.handle(.beginDrag(id: id, position: anchor), obstacles: obstacleMap)
    }

    mutating func handle(drag id: String, screenX: Double, screenY: Double) {
        let anchor = anchorPoint(fromScreenX: screenX, screenY: screenY)
        _ = world.handle(.drag(id: id, position: anchor), obstacles: obstacleMap)
    }

    mutating func handle(release id: String, screenX: Double, screenY: Double) {
        let anchor = anchorPoint(fromScreenX: screenX, screenY: screenY)
        _ = world.handle(.release(id: id, position: anchor), obstacles: obstacleMap)
    }

    mutating func handle(react id: String) -> PetInteractionResult {
        world.handle(.react(id: id), obstacles: obstacleMap)
    }

    mutating func handle(gather leaderID: String) -> PetInteractionResult {
        world.handle(.gatherAndPlay(leaderID: leaderID), obstacles: obstacleMap)
    }

    /// 屏幕坐标（y 向下）→ 世界坐标锚点（y 向上）。取指针所在显示器。
    private func anchorPoint(fromScreenX screenX: Double, screenY: Double) -> WorldPoint {
        let displays = obstacleMap.displays
        let pointer = WorldPoint(x: screenX, y: screenY)
        let display = displays.min {
            $0.squaredDistance(to: pointer) < $1.squaredDistance(to: pointer)
        } ?? MonitorLayout.fallbackMonitor
        return ScreenBridge.petAnchor(screenX: screenX, screenY: screenY, displayBottomY: display.maxY)
    }

    // MARK: - 无头自检（Windows 与 macOS 跑同一份断言）

    /// 返回空数组表示全部通过；否则返回失败原因列表。
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

        // 1.5) 坐标桥正确性：锚点在屏底 groundOffset 处、往返一致、修复旧版埋底 bug。
        do {
            let bottom = display.maxY
            let origin = ScreenBridge.windowOrigin(petX: 960, petY: 0, displayBottomY: bottom)
            // 窗口底行（y 向下）应位于 bottom - groundOffset：origin.y + 159 = 1060 → origin.y = 901。
            if origin.y != 901 { failures.append("windowOrigin bottom row mismatch: \(origin.y), expected 901") }
            let anchor = ScreenBridge.petAnchor(screenX: 960, screenY: bottom, displayBottomY: bottom)
            if abs(anchor.x - 960) > 1 || abs(anchor.y) > 1 {
                failures.append("petAnchor bottom-of-screen mismatch: \(anchor)")
            }
            let topAnchor = ScreenBridge.petAnchor(screenX: 500, screenY: 0, displayBottomY: bottom)
            if abs(topAnchor.y - bottom) > 1 {
                failures.append("petAnchor top-of-screen mismatch: \(topAnchor)")
            }
            // 屏顶锚点（y = display.height）映射后窗口底行应接近 groundOffset。
            let topOrigin = ScreenBridge.windowOrigin(petX: 960, petY: display.height, displayBottomY: bottom)
            if abs(Double(topOrigin.y) - (bottom - display.height - Double(Self.windowHeight - 1) - Self.groundOffset)) > 1 {
                failures.append("windowOrigin top mapping mismatch: \(topOrigin.y)")
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

        // 5) 命中模型：不透明像素吃点击、透明穿透、拖拽阈值、单击/双击。
        do {
            let canvas = PetCanvas.render(character: model.characters[0], pose: pose)
            let alpha = PointerModel.alphaBuffer(of: canvas)
            if alpha.count != canvas.width * canvas.height { failures.append("alpha buffer size mismatch") }
            // 画布内必有至少一个不透明与一个透明采样点（扫描网格找代表点）。
            var foundOpaque = false
            var foundTransparent = false
            for step in 1...9 {
                let nx = Double(step) / 10
                let ny = Double(step) / 10
                if PointerModel.isOpaque(normalizedX: nx, normalizedY: ny, alpha: alpha, width: canvas.width, height: canvas.height) {
                    foundOpaque = true
                } else {
                    foundTransparent = true
                }
            }
            if !foundOpaque { failures.append("hit-test found no opaque sample") }
            if !foundTransparent { failures.append("hit-test found no transparent sample") }
            // 越界归一化点必须穿透。
            if PointerModel.isOpaque(normalizedX: -0.1, normalizedY: 0.5, alpha: alpha, width: canvas.width, height: canvas.height) {
                failures.append("hit-test accepted out-of-range point")
            }

            // 手势：小位移不是拖拽，松开算单击。
            var pointer = PointerModel()
            pointer.press(atX: 100, atY: 100)
            if pointer.move(toX: 102, toY: 101) != .none { failures.append("sub-threshold move misclassified as drag") }
            if pointer.release(isDoubleClick: false) != .tap(isDoubleClick: false) { failures.append("plain press/release should be single tap") }
            // 大位移成拖拽。
            pointer.press(atX: 100, atY: 100)
            if pointer.move(toX: 110, toY: 100) != .beginDrag { failures.append("over-threshold move should begin drag") }
            if pointer.move(toX: 120, toY: 100) != .drag { failures.append("continued move should be drag") }
            if pointer.release(isDoubleClick: false) != .drag { failures.append("drag release should report drag") }
            if pointer.isDragging { failures.append("phase should be idle after release") }
            // 双击。
            pointer.press(atX: 0, atY: 0)
            if pointer.release(isDoubleClick: true) != .tap(isDoubleClick: true) { failures.append("double click misclassified") }
        }

        // 6) 交互语义：单击 → greet；双击 → 集合 play；拖拽 → hang；释放 → fall。
        do {
            var interactive = ShellModel(characters: fallbackCharacters(), display: display)
            if interactive.handle(react: "person-left") != .handled { failures.append("react interaction not handled") }
            if interactive.world.poses[0].state != .greet { failures.append("react should transition to greet") }

            if interactive.handle(gather: "person-right") != .handled { failures.append("gather interaction not handled") }
            if interactive.world.poses[3].state != .greet { failures.append("gather leader should greet") }
            if interactive.world.poses[0].state != .play { failures.append("gather companion should play") }

            interactive.handle(beginDrag: "person-center-left", screenX: 500, screenY: 500)
            if interactive.world.poses[1].state != .hang { failures.append("beginDrag should hang") }
            let before = interactive.world.poses[1].position
            interactive.handle(drag: "person-center-left", screenX: 640, screenY: 420)
            if interactive.world.poses[1].position == before { failures.append("drag should move pet") }
            interactive.handle(release: "person-center-left", screenX: 640, screenY: 420)
            if interactive.world.poses[1].state != .fall { failures.append("release should fall") }
        }

        // 7) 多显示器布局：去重、主屏选择、变化召回、夹紧。
        do {
            let primary = WorldRect(x: 0, y: 0, width: 1920, height: 1080)!
            let right = WorldRect(x: 1920, y: 0, width: 1080, height: 1920)!  // 竖屏副屏
            let resolved = MonitorLayout.resolve([primary, right, primary])
            if resolved.count != 2 { failures.append("monitor dedupe failed: \(resolved.count)") }
            if MonitorLayout.homeDisplay(in: [right, primary]) != primary {
                failures.append("home display should prefer origin-containing monitor")
            }
            if MonitorLayout.homeDisplay(in: [right]) != right {
                failures.append("single-monitor home should be itself")
            }
            if MonitorLayout.action(oldHome: primary, newHome: primary) != .keep {
                failures.append("same home should keep")
            }
            if MonitorLayout.action(oldHome: primary, newHome: right) != .recall {
                failures.append("changed home should recall")
            }
            let clamped = MonitorLayout.clampedWindowOrigin(x: -500, y: 5000, width: 180, height: 160, in: primary)
            if clamped != (x: 0, y: 920) { failures.append("window clamp mismatch: \(clamped)") }
            // 多显示器下的 ShellModel：宠物都落在主屏、600 帧不越出任一显示器并集。
            var multi = ShellModel(characters: fallbackCharacters(), displays: [primary, right])
            for _ in 0..<600 {
                for frame in multi.tick(deltaTime: 1.0 / Self.simulationFPS) {
                    let insideAny = [primary, right].contains { $0.contains(frame.pose.position) }
                    if !insideAny { failures.append("multi-monitor pet escaped all displays"); break }
                }
            }
        }

        return failures
    }
}
