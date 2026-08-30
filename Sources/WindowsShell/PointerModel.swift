import Foundation
import DesktopPetsCore

/// 指针命中与手势状态机（纯逻辑，跨平台可测）。
///
/// Windows 壳不使用 WS_EX_TRANSPARENT 整窗穿透（那会丢掉全部交互），
/// 而是 WM_NCHITTEST 逐像素判定：不透明像素 HTCLIENT（吃点击），
/// 透明像素 HTTRANSPARENT（点击穿透到下层窗口）。
/// 手势语义与 macOS PetSpriteView 一致：
/// 按下-移动超阈值 = 拖拽；按住不动松开 = 单击（挥手）；快速两击 = 集合玩耍。
struct PointerModel {
    /// 拖拽判定阈值（屏幕像素）。
    static let dragThreshold: Double = 5

    enum Phase: Equatable {
        case idle
        case pressing(startX: Double, startY: Double)
        case dragging
    }

    var phase: Phase = .idle

    /// 窗口内归一化点（0..1，y 向下，与位图行序一致）是否落在不透明像素上。
    /// WM_NCHITTEST 的窗口本地坐标直接就是 y 向下，无需翻转。
    static func isOpaque(normalizedX: Double, normalizedY: Double, alpha: [UInt8], width: Int, height: Int, threshold: UInt8 = 24) -> Bool {
        guard width > 0, height > 0 else { return false }
        guard normalizedX >= 0, normalizedX < 1, normalizedY >= 0, normalizedY < 1 else { return false }
        let px = min(width - 1, Int(normalizedX * Double(width)))
        let py = min(height - 1, Int(normalizedY * Double(height)))
        let index = py * width + px
        guard alpha.indices.contains(index) else { return false }
        return alpha[index] >= threshold
    }

    /// 画布 alpha 通道提取（行序自上而下，与窗口 y 向下坐标直接对应）。
    static func alphaBuffer(of canvas: PetCanvas) -> [UInt8] {
        var alpha = [UInt8]()
        alpha.reserveCapacity(canvas.width * canvas.height)
        var i = 3
        while i < canvas.pixels.count {
            alpha.append(canvas.pixels[i])
            i += 4
        }
        return alpha
    }

    public enum PressEvent: Equatable {
        case none
        /// 进入拖拽（第一次越过阈值时返回一次）。
        case beginDrag
        /// 拖拽中。
        case drag
        /// 未构成拖拽的普通点击；`isDoubleClick` 为 true 表示双击。
        case tap(isDoubleClick: Bool)
    }

    /// 指针按下。
    public mutating func press(atX x: Double, atY y: Double) {
        phase = .pressing(startX: x, startY: y)
    }

    /// 指针按下后移动。返回本次移动产生的事件（拖拽开始/持续）。
    public mutating func move(toX x: Double, toY y: Double) -> PressEvent {
        switch phase {
        case .idle:
            return .none
        case let .pressing(startX, startY):
            let dx = x - startX
            let dy = y - startY
            guard dx * dx + dy * dy >= Self.dragThreshold * Self.dragThreshold else { return .none }
            phase = .dragging
            return .beginDrag
        case .dragging:
            return .drag
        }
    }

    /// 指针释放。拖拽返回 .drag（调用方发 release）；否则视为 tap。
    public mutating func release(isDoubleClick: Bool) -> PressEvent {
        switch phase {
        case .idle:
            return .none
        case .pressing:
            phase = .idle
            return .tap(isDoubleClick: isDoubleClick)
        case .dragging:
            phase = .idle
            return .drag
        }
    }

    var isDragging: Bool {
        if case .dragging = phase { return true }
        return false
    }
}
