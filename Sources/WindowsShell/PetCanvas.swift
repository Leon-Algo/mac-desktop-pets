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
    /// `avatarBGRA` 非空时（512×512 BGRA），脸部区域改画头像（椭圆裁剪 aspect-fill），
    /// 布局与 macOS ProceduralPetRenderer 的 faceRect (103,81,58,62) 对齐。
    static func render(
        character: CharacterManifest, pose: PetPose, width: Int = 180, height: Int = 160,
        avatar: AvatarBitmap? = nil
    ) -> PetCanvas {
        var canvas = PetCanvas(width: width, height: height)
        canvas.draw(character: character, pose: pose, avatar: avatar)
        return canvas
    }

    /// 512×512 归一化头像位图（BGRA，行序自上而下）。
    struct AvatarBitmap {
        let pixels: [UInt8]
        static let size = 512
    }

    // MARK: - 绘制

    private mutating func draw(character: CharacterManifest, pose: PetPose, avatar: AvatarBitmap?) {
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

        // 脸：有头像 → 椭圆裁剪 aspect-fill 合成；无 → 程序化（肤色 + 发际 + 双眼）。
        let faceCenterX = 132.0
        let faceCenterY = 112.0 + bob
        let faceRX = 29.0
        let faceRY = 31.0
        if let avatar, drawAvatar(
            avatar, cx: faceCenterX, cy: faceCenterY, rx: faceRX, ry: faceRY
        ) {
            // 白描边（近似 macOS 72% 白，无 AA 下用单像素环）。
            strokeEllipseOutline(cx: faceCenterX, cy: faceCenterY, rx: faceRX, ry: faceRY, color: (240, 240, 240))
        } else {
            fillEllipse(cx: faceCenterX, cy: faceCenterY, rx: faceRX, ry: faceRY, color: skin)
            fillEllipse(cx: 132, cy: 129.5 + bob, rx: 27, ry: 13.5, color: hair)
            let eye = Self.parseHex("#2A2220")
            fillEllipse(cx: 122.5, cy: 111.5 + bob, rx: 2.5, ry: 2.5, color: eye)
            fillEllipse(cx: 143.5, cy: 111.5 + bob, rx: 2.5, ry: 2.5, color: eye)
        }

        // 手脚。
        fillEllipse(cx: 29, cy: 22, rx: 9, ry: 5, color: skin)
        fillEllipse(cx: 155, cy: 22, rx: 10, ry: 5, color: skin)
    }

    /// 椭圆区域内 aspect-fill 合成头像（最近邻采样，确定性）。
    /// 返回是否实际绘制（位图非法返回 false，调用方回退程序化脸）。
    private mutating func drawAvatar(_ avatar: AvatarBitmap, cx: Double, cy: Double, rx: Double, ry: Double) -> Bool {
        let size = AvatarBitmap.size
        let count = size * size * 4
        guard avatar.pixels.count == count else { return false }
        let minX = max(0, Int((cx - rx).rounded(.down)))
        let maxX = min(width - 1, Int((cx + rx).rounded(.up)))
        let minY = max(0, Int((cy - ry).rounded(.down)))
        let maxY = min(height - 1, Int((cy + ry).rounded(.up)))
        guard minX <= maxX, minY <= maxY else { return false }

        // aspect-fill：椭圆比 (rx/ry) 决定源裁剪带，短轴铺满、长轴居中裁。
        let destAspect = rx / ry
        let sourceAspect = 1.0
        var cropW = Double(size)
        var cropH = Double(size)
        if sourceAspect > destAspect {
            cropW = Double(size) * destAspect
        } else {
            cropH = Double(size) / destAspect
        }
        let cropX = (Double(size) - cropW) / 2
        let cropY = (Double(size) - cropH) / 2

        for py in minY...maxY {
            for px in minX...maxX {
                // 像素中心相对椭圆归一化半径，椭圆内才绘制。
                let dx = (Double(px) + 0.5 - cx) / rx
                let dy = (Double(py) + 0.5 - cy) / ry
                guard dx * dx + dy * dy <= 1 else { continue }
                // 目标位置 → 源裁剪带内最近邻采样。
                let u = (Double(px) + 0.5 - (cx - rx)) / (2 * rx)
                let v = (Double(py) + 0.5 - (cy - ry)) / (2 * ry)
                let sx = min(size - 1, max(0, Int((cropX + u * cropW).rounded(.down))))
                let sy = min(size - 1, max(0, Int((cropY + v * cropH).rounded(.down))))
                let src = (sy * size + sx) * 4
                let alpha = avatar.pixels[src + 3]
                guard alpha >= 24 else { continue }
                let row = height - 1 - py  // y 向上 → 自上而下位图
                let base = (row * width + px) * 4
                // 透明像素按 alpha 混合到现有内容（半透明边缘更柔和）。
                if alpha == 255 || pixels[base + 3] == 0 {
                    pixels[base] = avatar.pixels[src + 2]     // B
                    pixels[base + 1] = avatar.pixels[src + 1] // G
                    pixels[base + 2] = avatar.pixels[src]     // R
                    pixels[base + 3] = 255
                } else {
                    let a = Double(alpha) / 255
                    pixels[base] = UInt8(Double(pixels[base]) * (1 - a) + Double(avatar.pixels[src + 2]) * a)
                    pixels[base + 1] = UInt8(Double(pixels[base + 1]) * (1 - a) + Double(avatar.pixels[src + 1]) * a)
                    pixels[base + 2] = UInt8(Double(pixels[base + 2]) * (1 - a) + Double(avatar.pixels[src]) * a)
                    pixels[base + 3] = 255
                }
            }
        }
        return true
    }

    /// 椭圆单像素描边环（|归一化半径 - 1| 在一个像素带内即描边）。
    private mutating func strokeEllipseOutline(cx: Double, cy: Double, rx: Double, ry: Double, color: (UInt8, UInt8, UInt8)) {
        let (r, g, b) = color
        let minX = max(0, Int((cx - rx - 1).rounded(.down)))
        let maxX = min(width - 1, Int((cx + rx + 1).rounded(.up)))
        let minY = max(0, Int((cy - ry - 1).rounded(.down)))
        let maxY = min(height - 1, Int((cy + ry + 1).rounded(.up)))
        guard minX <= maxX, minY <= maxY else { return }
        for py in minY...maxY {
            for px in minX...maxX {
                let dx = (Double(px) + 0.5 - cx) / rx
                let dy = (Double(py) + 0.5 - cy) / ry
                let radiusSquared = dx * dx + dy * dy
                guard radiusSquared <= 1.15, radiusSquared >= 0.82 else { continue }
                let row = height - 1 - py
                let base = (row * width + px) * 4
                guard pixels[base + 3] == 255 else { continue }  // 只描已有内容，不外溢
                pixels[base] = b
                pixels[base + 1] = g
                pixels[base + 2] = r
            }
        }
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
