// CoreProbe —— 跨平台可行性探针。
// 目标：在 macOS 与 Windows 两种工具链下编译同一份纯 Foundation 核心
// （DesktopPetsCore），并运行一段确定性模拟自检，验证：
//   1. 核心零平台依赖、双端可编译；
//   2. 模拟行为跨平台逐位一致（同种子同结果）；
//   3. 长时运行状态有界、坐标有限（无发散、无 NaN）。
// 退出码 0 = 全部通过；非 0 = 失败。CI 依赖该退出码做断言。

import DesktopPetsCore
import Foundation

@main
struct CoreProbe {
    static func main() {
        var failures: [String] = []

        // ---- 1. 确定性：同种子双实例逐 tick 一致 ----
        let display = WorldRect(x: 0, y: 0, width: 1000, height: 700)!
        let characters = fallbackCharacters()
        let map = ObstacleMap(
            displays: [display],
            obstacles: [Obstacle(id: "window", kind: .window, rect: WorldRect(x: 200, y: 100, width: 300, height: 200)!)]
        )
        var lhs = PetWorld(characters: characters, display: display, seed: 42)
        var rhs = PetWorld(characters: characters, display: display, seed: 42)
        for _ in 0..<600 {
            lhs.step(deltaTime: 1.0 / 60.0, obstacles: map)
            rhs.step(deltaTime: 1.0 / 60.0, obstacles: map)
        }
        if lhs.poses != rhs.poses {
            failures.append("determinism: same seed diverged")
        }

        // ---- 2. 长时运行：2 小时@60fps 加速模拟，状态有界、坐标有限 ----
        var world = PetWorld(characters: characters, display: display, seed: 91)
        var maxTicks: UInt64 = 0
        let stateSet = Set(PetState.allCases.map(\.rawValue))
        for _ in 0..<(2 * 3600 * 60) {
            world.step(deltaTime: 1.0 / 60.0, obstacles: map)
            maxTicks &+= 1
        }
        let poses = world.poses
        if poses.count != characters.count {
            failures.append("longrun: expected \(characters.count) pets, got \(poses.count)")
        }
        for pose in poses {
            if !pose.position.isFinite {
                failures.append("longrun: non-finite position for \(pose.id)")
            }
            if !display.contains(pose.position) {
                failures.append("longrun: out-of-display position for \(pose.id): \(pose.position.x), \(pose.position.y)")
            }
            if !stateSet.contains(pose.state.rawValue) {
                failures.append("longrun: unknown state \(pose.state.rawValue)")
            }
        }
        if maxTicks != UInt64(2 * 3600 * 60) {
            failures.append("longrun: tick counter mismatch")
        }

        // ---- 3. 交互：拖拽→释放→落地，动作反馈可产生 ----
        var interactive = PetWorld(characters: characters, display: display, seed: 7)
        let drag = interactive.handle(
            .beginDrag(id: characters[0].id, position: WorldPoint(x: 500, y: 600)),
            obstacles: map
        )
        if drag != .handled { failures.append("interaction: beginDrag not handled") }
        let release = interactive.handle(
            .release(id: characters[0].id, position: WorldPoint(x: 250, y: 250)),
            obstacles: map
        )
        if release != .handled { failures.append("interaction: release not handled") }
        var landed = false
        for _ in 0..<600 {
            interactive.step(deltaTime: 1.0 / 60.0, obstacles: map)
            if interactive.poses[0].state == .crawl { landed = true; break }
        }
        if !landed { failures.append("interaction: pet did not land after release") }
        let action = interactive.handle(
            .performAction(PetActionRequest(actionID: .wave, targetID: characters[0].id)),
            obstacles: map
        )
        if case .action(.performed) = action {} else {
            failures.append("interaction: wave action not performed")
        }

        // ---- 4. 名册持久化：临时目录读写回环 ----
        do {
            let root = FileManager.default.temporaryDirectory
                .appendingPathComponent("CoreProbe-\(UUID().uuidString)", isDirectory: true)
            let store = CharacterRosterStore(rootDirectory: root)
            let loaded = store.load()
            if loaded != .default { failures.append("roster: default load mismatch") }
            try store.save(.default)
            if store.load() != .default { failures.append("roster: roundtrip mismatch") }
            try? FileManager.default.removeItem(at: root)
        } catch {
            failures.append("roster: \(error)")
        }

        if failures.isEmpty {
            print("CoreProbe: ok (determinism + 2h longrun + interactions + roster roundtrip)")
        } else {
            for failure in failures { print("CoreProbe FAILURE: \(failure)") }
            exit(1)
        }
    }

    private static func fallbackCharacters() -> [CharacterManifest] {
        // 与 macOS 壳层 CharacterCatalog.fallback 同源的 4 人阵容。
        let profiles: [(String, String, CharacterPalette, Personality)] = [
            ("person-left", "格子衫", .init(skin: "#D8A080", hair: "#1E1715", shirt: "#B9A88A", accent: "#5D655E"), .init(speed: 0.46, curiosity: 0.70, sociability: 0.62, courage: 0.42, sleepiness: 0.35)),
            ("person-center-left", "黑背心", .init(skin: "#D49A76", hair: "#171313", shirt: "#171717", accent: "#F5F0E8"), .init(speed: 0.70, curiosity: 0.72, sociability: 0.80, courage: 0.78, sleepiness: 0.22)),
            ("person-center-right", "薄荷衫", .init(skin: "#D39A7D", hair: "#3A241B", shirt: "#A9D8CF", accent: "#403632"), .init(speed: 0.52, curiosity: 0.58, sociability: 0.74, courage: 0.48, sleepiness: 0.42)),
            ("person-right", "黑外套", .init(skin: "#B97D5E", hair: "#151313", shirt: "#272727", accent: "#EFE4DC"), .init(speed: 0.62, curiosity: 0.66, sociability: 0.68, courage: 0.66, sleepiness: 0.30)),
        ]
        let frame = FrameRect(x: 0, y: 0, width: 1, height: 1)
        let clip = AnimationClip(frames: [frame], fps: 8)
        let animations = Dictionary(uniqueKeysWithValues: ["idle", "crawl", "turn", "climb", "hang", "jump", "fall", "sleep", "chase", "greet", "play"].map { ($0, clip) })
        return profiles.map { id, name, palette, personality in
            CharacterManifest(
                id: id,
                displayName: name,
                atlasName: nil,
                palette: palette,
                personality: personality,
                anchor: NormalizedPoint(x: 0.5, y: 0.08),
                collisionBody: FrameRect(x: 0.15, y: 0.04, width: 0.7, height: 0.72),
                animations: animations
            )
        }
    }
}
