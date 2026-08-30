import Foundation
import DesktopPetsCore

/// 窗口世界坐标桥（纯逻辑，跨平台可测）。
///
/// Windows 虚拟屏幕坐标 y 向下；PetWorld 世界坐标 y 向上（0 = 屏幕底边）。
/// 与 macOS 语义对齐：拖拽时宠物锚点跟随指针（macOS AppKit 屏幕坐标
/// 本身 y 向上，等价于这里翻转后的结果）。
struct ScreenBridge {
    /// 世界坐标（宠物锚点，y 向上）→ 窗口左上角屏幕坐标（y 向下）。
    ///
    /// `displayBottomY` 是宠物所在显示器底边在虚拟屏幕坐标里的 y 值。
    /// 锚点行位于窗口底行再往上一个 groundOffset：
    /// 窗口顶 = bottom - petY - (windowHeight - 1) - groundOffset。
    static func windowOrigin(
        petX: Double, petY: Double, displayBottomY: Double
    ) -> (x: Int, y: Int) {
        let originX = petX - Double(ShellModel.windowWidth) / 2
        let originY = displayBottomY - petY - Double(ShellModel.windowHeight - 1) - ShellModel.groundOffset
        return (Int(originX.rounded()), Int(originY.rounded()))
    }

    /// 指针屏幕坐标 → 世界坐标宠物锚点（拖拽跟随语义）。
    static func petAnchor(
        screenX: Double, screenY: Double, displayBottomY: Double
    ) -> WorldPoint {
        WorldPoint(x: screenX.rounded(), y: (displayBottomY - screenY).rounded())
    }
}
