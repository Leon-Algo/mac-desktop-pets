import XCTest
import AppKit
@testable import DesktopPets

/// 发布前内存与生命周期验收：
/// 1. 长时间运行下，模拟状态有界、坐标有限、单步耗时稳定（无卡顿/无状态累积）。
/// 2. WorldRunner 被丢弃引用（未调用 stop）后必须能被释放，证明 Timer 不再强持有 self。
@MainActor
final class MemoryAndLifecycleTests: XCTestCase {

    /// 模拟长时间运行：以真实节奏（20fps）推进 1 小时，断言不退化、不累积、性能在预算内。
    func testSustainedLongRunStaysBoundedAndFast() {
        let display = WorldRect(x: 0, y: 0, width: 1440, height: 900)!
        var world = PetWorld(characters: CharacterCatalog.fallback.characters, display: display, seed: 0xC0FFEE)
        let window = Obstacle(id: "w", kind: .window, rect: WorldRect(x: 200, y: 200, width: 600, height: 400)!)
        let map = ObstacleMap(displays: [display], obstacles: [window])

        let fps = WorldRunner.simulationFramesPerSecond
        let steps = 60 * 60 * fps // 1 小时
        let step = 1.0 / Double(fps)

        let start = Date()
        for _ in 0..<steps {
            world.step(deltaTime: step, obstacles: map)
        }
        let elapsed = Date().timeIntervalSince(start)

        // 状态有界：角色数量恒定，坐标始终有限且落在显示器内（无 NaN / 飞出）。
        XCTAssertEqual(world.poses.count, CharacterCatalog.fallback.characters.count)
        XCTAssertTrue(world.poses.allSatisfy { $0.position.isFinite && display.contains($0.position) })

        // 性能预算：平均单步远低于 1ms（实际应 < 0.05ms），证明长期运行不会因状态累积而卡顿。
        let perStep = elapsed / Double(steps)
        XCTAssertLessThan(perStep, 0.001, "平均单步耗时 \(perStep * 1_000_000)µs 超出预算，长时间运行可能卡顿")
    }

    /// WorldRunner 被丢弃引用（未显式 stop）后必须释放自身。
    /// 旧实现中 Timer.scheduledTimer(target:self) 强持有 self，会形成
    /// WorldRunner → Timer → WorldRunner 循环，导致即使引用归零也不释放（泄漏）。
    /// 修复后定时器以 [weak self] 捕获，引用归零即可 deallocate。
    func testWorldRunnerDeallocatesWhenReferenceDroppedWithoutStop() {
        let provider = StaticGeometryProvider(snapshot: GeometrySnapshot(
            displays: [WorldRect(x: 0, y: 0, width: 1440, height: 900)!],
            obstacles: [],
            ownerPIDs: [],
            capturedAt: Date()
        ))

        weak var weakRunner: WorldRunner?
        autoreleasepool {
            let runner = WorldRunner(characters: CharacterCatalog.fallback.characters, geometryProvider: provider)
            runner.start(preferences: .defaults)
            weakRunner = runner
            // 故意不调用 stop()/dispose()，模拟“引用被丢弃但忘记清理”的最坏情况。
        }

        // 局部强引用离开作用域即释放；若无额外强引用（定时器不再强持有），应立即 deallocate。
        XCTAssertNil(
            weakRunner,
            "WorldRunner 在引用归零后仍存活：Timer 强持有 self 造成泄漏。修复后应可正常释放。"
        )
    }

    /// 正常路径（start → stop → 丢弃引用）也必须释放，作为对照。
    func testWorldRunnerDeallocatesAfterStop() {
        let provider = StaticGeometryProvider(snapshot: GeometrySnapshot(
            displays: [WorldRect(x: 0, y: 0, width: 1440, height: 900)!],
            obstacles: [],
            ownerPIDs: [],
            capturedAt: Date()
        ))

        weak var weakRunner: WorldRunner?
        autoreleasepool {
            let runner = WorldRunner(characters: CharacterCatalog.fallback.characters, geometryProvider: provider)
            runner.start(preferences: .defaults)
            runner.stop()
            weakRunner = runner
        }

        XCTAssertNil(weakRunner, "正常 stop() 后 WorldRunner 应可被释放。")
    }
}

@MainActor
final class StaticGeometryProvider: GeometryProvider {
    let fixedSnapshot: GeometrySnapshot
    init(snapshot: GeometrySnapshot) { self.fixedSnapshot = snapshot }
    func snapshot() -> GeometrySnapshot { fixedSnapshot }
}
