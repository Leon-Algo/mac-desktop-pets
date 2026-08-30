import Foundation
import DesktopPetsCore

/// 纯 Foundation 软件光栅器：把宠物角色渲染成 BGRA 像素缓冲。
/// 与 macOS 端 ProceduralPetRenderer 同比例（180×160、同肢体布局、同配色），
/// 双端可编译可测试——Windows 壳用它喂 UpdateLayeredWindow，
/// macOS/CI 端用它在无 GUI 情况下验证渲染管线。
///
/// 坐标约定：绘图 API 采用与 macOS 相同的 y 向上坐标；写像素时翻转到
/// 自上而下位图行序。无抗锯齿（alpha 仅 0/255），保证双端逐位确定。
struct PetCanvas {
    let width: Int
    let height: Int
    private(set) var pixels: [UInt8]  // BGRA，每像素 4 字节

    init(width: Int, height: Int) {
        self.width = width
        self.height = height
        self.pixels = [UInt8](repeating: 0, count: width * height * 4)
    }

    var opaquePixelCount: Int {
        var count = 0
        var i = 3
        while i < pixels.count {
            if pixels[i] == 255 { count += 1 }
            i += 4
        }
        return count
    }

    /// 主入口：按角色与当前姿态渲染整帧。
    static func render(character: CharacterManifest, pose: PetPose, width: Int = 180, height: Int = 160) -> PetCanvas {
        var canvas = PetCanvas(width: width, height: height)
        canvas.draw(character: character, pose: pose)
        return canvas
    }

    // MARK: - 绘制

    private mutating func draw(character: CharacterManifest, pose: PetPose) {
        let skin = Self.parseHex(character.palette.skin)
        let hair = Self.parseHex(character.palette.hair)
        let shirt = Self.parseHex(character.palette.shirt)
        let accent = Self.parseHex(character.palette.accent)

        // 爬行时轻微起伏，与 Mac 端 phase 语义一致。
        var bob = 0.0
        if pose.state == .crawl { bob = sin(pose.phase * 2 * Double.pi) * 2 }

        // 肢体（与 macOS ProceduralPetRenderer 同布局，y 向上坐标）。
        strokePolyline([(72, 72), (48, 48), (28, 24)], width: 16, color: shirt, offsetY: bob)
        strokePolyline([(95, 68), (122, 48), (150, 26)], width: 17, color: shirt, offsetY: bob)
        strokePolyline([(88, 86), (58, 54), (44, 22)], width: 12, color: skin, offsetY: bob)
        strokePolyline([(112, 88), (140, 54), (154, 23)], width: 12, color: skin, offsetY: bob)

        fillRoundRect(x: 55, y: 60 + bob, w: 72, h: 52, radius: 22, color: shirt)

        let bodyStyle = character.bodyStyle
            ?? (character.id == "person-left" ? BodyStyle.plaid : (character.id == "person-right" ? BodyStyle.jacket : BodyStyle.plain))
        if bodyStyle == .plaid {
            var x = 62.0
            while x <= 118 {
                strokeLine(x1: x, y1: 64 + bob, x2: x, y2: 106 + bob, width: 2, color: accent)
                x += 14
            }
            var y = 70.0
            while y <= 100 {
                strokeLine(x1: 58, y1: y + bob, x2: 124, y2: y + bob, width: 2, color: accent)
                y += 12
            }
        } else if bodyStyle == .jacket {
            fillRoundRect(x: 84, y: 64 + bob, w: 18, h: 44, radius: 7, color: accent)
        }

        // 脸（无头像资源，程序化：肤色椭圆 + 发际 + 双眼）。
        fillEllipse(cx: 132, cy: 112 + bob, rx: 29, ry: 31, color: skin)
        fillEllipse(cx: 132, cy: 129.5 + bob, rx: 27, ry: 13.5, color: hair)
        let eye = Self.parseHex("#2A2220")
        fillEllipse(cx: 122.5, cy: 111.5 + bob, rx: 2.5, ry: 2.5, color: eye)
        fillEllipse(cx: 143.5, cy: 111.5 + bob, rx: 2.5, ry: 2.5, color: eye)

        // 手脚。
        fillEllipse(cx: 29, cy: 22, rx: 9, ry: 5, color: skin)
        fillEllipse(cx: 155, cy: 22, rx: 10, ry: 5, color: skin)
    }

    /// y 向上坐标 → 自上而下位图。越界与 alpha 已写则跳过。
    private mutating func setPixel(x: Int, y: Int, r: UInt8, g: UInt8, b: UInt8) {
        guard x >= 0, x < width, y >= 0, y < height else { return }
        let row = height - 1 - y
        let base = (row * width + x) * 4
        if pixels[base + 3] == 255 { return }
        pixels[base] = b
        pixels[base + 1] = g
        pixels[base + 2] = r
        pixels[base + 3] = 255
    }

    mutating func fillEllipse(cx: Double, cy: Double, rx: Double, ry: Double, color: (UInt8, UInt8, UInt8)) {
        guard rx > 0, ry > 0 else { return }
        let minX = max(0, Int((cx - rx).rounded(.down)))
        let maxX = min(width - 1, Int((cx + rx).rounded(.up)))
        let minY = max(0, Int((cy - ry).rounded(.down)))
        let maxY = min(height - 1, Int((cy + ry).rounded(.up)))
        guard minX <= maxX, minY <= maxY else { return }
        let (r, g, b) = color
        for py in minY...maxY {
            for px in minX...maxX {
                let dx = (Double(px) + 0.5 - cx) / rx
                let dy = (Double(py) + 0.5 - cy) / ry
                if dx * dx + dy * dy <= 1 {
                    setPixel(x: px, y: Int(py), r: r, g: g, b: b)
                }
            }
        }
    }

    mutating func fillRoundRect(x: Double, y: Double, w: Double, h: Double, radius: Double, color: (UInt8, UInt8, UInt8)) {
        let (r, g, b) = color
        let minX = max(0, Int(x.rounded(.down)))
        let maxX = min(width - 1, Int((x + w).rounded(.up)))
        let minY = max(0, Int(y.rounded(.down)))
        let maxY = min(height - 1, Int((y + h).rounded(.up)))
        guard minX <= maxX, minY <= maxY else { return }
        let rad = min(radius, min(w, h) / 2)
        let innerL = x + rad
        let innerR = x + w - rad
        let innerB = y + rad
        let innerT = y + h - rad
        for py in minY...maxY {
            for px in minX...maxX {
                let pointX = Double(px) + 0.5
                let pointY = Double(py) + 0.5
                let inXBand = pointX >= innerL && pointX <= innerR
                let inYBand = pointY >= innerB && pointY <= innerT
                if inXBand || inYBand {
                    setPixel(x: px, y: py, r: r, g: g, b: b)
                    continue
                }
                // 四个圆角区域。
                let cornerCX = pointX < innerL ? innerL : innerR
                let cornerCY = pointY < innerB ? innerB : innerT
                let dx = pointX - cornerCX
                let dy = pointY - cornerCY
                if dx * dx + dy * dy <= rad * rad {
                    setPixel(x: px, y: py, r: r, g: g, b: b)
                }
            }
        }
    }

    mutating func strokeLine(x1: Double, y1: Double, x2: Double, y2: Double, width: Double, color: (UInt8, UInt8, UInt8)) {
        strokePolyline([(x1, y1), (x2, y2)], width: width, color: color, offsetY: 0)
    }

    /// 圆头折线：对包围盒内像素做点到线段距离判定（无 AA，确定性）。
    mutating func strokePolyline(_ points: [(Double, Double)], width: Double, color: (UInt8, UInt8, UInt8), offsetY: Double) {
        guard let first = points.first else { return }
        let half = width / 2 + 1
        var minX = first.0, maxX = first.0, minY = first.1, maxY = first.1
        for (px, py) in points {
            minX = min(minX, px); maxX = max(maxX, px)
            minY = min(minY, py); maxY = max(maxY, py)
        }
        let (r, g, b) = color
        let pixelMinX = max(0, Int((minX - half).rounded(.down)))
        let pixelMaxX = min(self.width - 1, Int((maxX + half).rounded(.up)))
        let pixelMinY = max(0, Int((minY - half).rounded(.down)))
        let pixelMaxY = min(self.height - 1, Int((maxY + half).rounded(.up)))
        guard pixelMinX <= pixelMaxX, pixelMinY <= pixelMaxY else { return }
        for py in pixelMinY...pixelMaxY {
            for px in pixelMinX...pixelMaxX {
                let pointX = Double(px) + 0.5
                let pointY = Double(py) + 0.5 - offsetY
                if distanceToPath(x: pointX, y: pointY, points: points) <= half {
                    setPixel(x: px, y: py, r: r, g: g, b: b)
                }
            }
        }
    }
    private func distanceToPath(x: Double, y: Double, points: [(Double, Double)]) -> Double {
        var best = Double.greatestFiniteMagnitude
        var previous = points[0]
        for current in points.dropFirst() {
            best = min(best, Self.distanceToSegment(x: x, y: y, ax: previous.0, ay: previous.1, bx: current.0, by: current.1))
            previous = current
        }
        return best
    }

    private static func distanceToSegment(x: Double, y: Double, ax: Double, ay: Double, bx: Double, by: Double) -> Double {
        let abx = bx - ax
        let aby = by - ay
        let apx = x - ax
        let apy = y - ay
        let lengthSquared = abx * abx + aby * aby
        let t = lengthSquared == 0 ? 0.0 : min(1, max(0, (apx * abx + apy * aby) / lengthSquared))
        let dx = x - (ax + abx * t)
        let dy = y - (ay + aby * t)
        return (dx * dx + dy * dy).squareRoot()
    }

    static func parseHex(_ hex: String) -> (UInt8, UInt8, UInt8) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        let value = UInt64(cleaned, radix: 16) ?? 0
        return (
            UInt8((value >> 16) & 0xFF),
            UInt8((value >> 8) & 0xFF),
            UInt8(value & 0xFF)
        )
    }
}
