import Foundation
import DesktopPetsCore

/// 多显示器布局纯逻辑（虚拟屏幕坐标，y 向下）。
/// Windows 侧由 EnumDisplayMonitors 喂入原始矩形；macOS/CI 侧用同一份函数做无头自检。
enum MonitorLayout {
    /// 空列表/全无效时的回退主屏。
    static let fallbackMonitor = WorldRect(x: 0, y: 0, width: 1920, height: 1080)!

    /// 过滤无效显示器（尺寸异常）并去重；全部无效时回退到 1920×1080。
    static func resolve(_ raw: [WorldRect]) -> [WorldRect] {
        var seen: [WorldRect] = []
        for monitor in raw where monitor.width >= 100 && monitor.height >= 100 {
            if !seen.contains(monitor) { seen.append(monitor) }
        }
        return seen.isEmpty ? [fallbackMonitor] : seen
    }

    /// 主显示器：包含虚拟屏幕原点者优先（Windows 约定主屏含原点）；
    /// 否则取面积最大者，同面积取 x 最小（靠左）者，保证确定性。
    static func homeDisplay(in monitors: [WorldRect]) -> WorldRect {
        guard !monitors.isEmpty else { return fallbackMonitor }
        let origin = WorldPoint(x: 0, y: 0)
        if let primary = monitors.first(where: { $0.contains(origin) }) { return primary }
        var best = monitors[0]
        for candidate in monitors.dropFirst() {
            let bestArea = best.width * best.height
            let area = candidate.width * candidate.height
            if area > bestArea || (area == bestArea && candidate.minX < best.minX) {
                best = candidate
            }
        }
        return best
    }

    enum HomeChangeAction: Equatable {
        case keep
        case recall
    }

    /// 主屏变化时的处置：变了就召回全部宠物到新主屏。
    static func action(oldHome: WorldRect, newHome: WorldRect) -> HomeChangeAction {
        oldHome == newHome ? .keep : .recall
    }

    /// 把窗口左上角坐标夹回指定显示器可见范围（防止显示器拔掉后窗口丢失）。
    static func clampedWindowOrigin(
        x: Int, y: Int, width: Int, height: Int, in monitor: WorldRect
    ) -> (x: Int, y: Int) {
        let maxOriginX = max(Int(monitor.minX), Int(monitor.maxX) - width)
        let maxOriginY = max(Int(monitor.minY), Int(monitor.maxY) - height)
        return (
            min(max(x, Int(monitor.minX)), maxOriginX),
            min(max(y, Int(monitor.minY)), maxOriginY)
        )
    }
}
