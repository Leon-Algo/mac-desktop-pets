import AppKit
import Foundation

enum SnapshotRenderError: Error {
    case bitmapCreationFailed
    case pngEncodingFailed
}

@MainActor
enum ProceduralPetRenderer {
    static func image(for character: CharacterManifest, size: CGSize) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        draw(character: character, in: NSRect(origin: .zero, size: size))
        image.unlockFocus()
        return image
    }

    static func renderVerificationSnapshot(characters: [CharacterManifest], url: URL) throws {
        let cell = CGSize(width: 180, height: 160)
        let canvas = NSImage(size: CGSize(width: cell.width * CGFloat(characters.count), height: cell.height))
        canvas.lockFocus()
        NSColor.clear.setFill()
        NSRect(origin: .zero, size: canvas.size).fill()
        for (index, character) in characters.enumerated() {
            image(for: character, size: cell).draw(
                in: NSRect(x: CGFloat(index) * cell.width, y: 0, width: cell.width, height: cell.height),
                from: .zero,
                operation: .sourceOver,
                fraction: 1
            )
        }
        canvas.unlockFocus()
        guard let tiff = canvas.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff) else { throw SnapshotRenderError.bitmapCreationFailed }
        guard let png = bitmap.representation(using: .png, properties: [:]) else { throw SnapshotRenderError.pngEncodingFailed }
        try png.write(to: url, options: .atomic)
    }

    private static func draw(character: CharacterManifest, in rect: NSRect) {
        let skin = NSColor(hex: character.palette.skin)
        let hair = NSColor(hex: character.palette.hair)
        let shirt = NSColor(hex: character.palette.shirt)
        let accent = NSColor(hex: character.palette.accent)

        strokeLimb(points: [CGPoint(x: 72, y: 72), CGPoint(x: 48, y: 48), CGPoint(x: 28, y: 24)], color: shirt, width: 16)
        strokeLimb(points: [CGPoint(x: 95, y: 68), CGPoint(x: 122, y: 48), CGPoint(x: 150, y: 26)], color: shirt, width: 17)
        strokeLimb(points: [CGPoint(x: 88, y: 86), CGPoint(x: 58, y: 54), CGPoint(x: 44, y: 22)], color: skin, width: 12)
        strokeLimb(points: [CGPoint(x: 112, y: 88), CGPoint(x: 140, y: 54), CGPoint(x: 154, y: 23)], color: skin, width: 12)

        shirt.setFill()
        NSBezierPath(roundedRect: NSRect(x: 55, y: 60, width: 72, height: 52), xRadius: 22, yRadius: 22).fill()

        if character.id == "person-left" {
            accent.withAlphaComponent(0.65).setStroke()
            for x in stride(from: 62.0, through: 118.0, by: 14) {
                let line = NSBezierPath(); line.move(to: CGPoint(x: x, y: 64)); line.line(to: CGPoint(x: x, y: 106)); line.lineWidth = 2; line.stroke()
            }
            for y in stride(from: 70.0, through: 100.0, by: 12) {
                let line = NSBezierPath(); line.move(to: CGPoint(x: 58, y: y)); line.line(to: CGPoint(x: 124, y: y)); line.lineWidth = 2; line.stroke()
            }
        } else if character.id == "person-right" {
            accent.setFill()
            NSBezierPath(roundedRect: NSRect(x: 84, y: 64, width: 18, height: 44), xRadius: 7, yRadius: 7).fill()
        }

        skin.setFill()
        NSBezierPath(ovalIn: NSRect(x: 105, y: 83, width: 54, height: 58)).fill()
        hair.setFill()
        let hairPath = NSBezierPath()
        hairPath.move(to: CGPoint(x: 106, y: 117))
        hairPath.curve(to: CGPoint(x: 157, y: 118), controlPoint1: CGPoint(x: 112, y: 145), controlPoint2: CGPoint(x: 150, y: 145))
        hairPath.line(to: CGPoint(x: 153, y: 132))
        hairPath.curve(to: CGPoint(x: 110, y: 128), controlPoint1: CGPoint(x: 142, y: 143), controlPoint2: CGPoint(x: 118, y: 141))
        hairPath.close()
        hairPath.fill()

        NSColor(hex: "#2A2220").setFill()
        NSBezierPath(ovalIn: NSRect(x: 120, y: 109, width: 5, height: 5)).fill()
        NSBezierPath(ovalIn: NSRect(x: 141, y: 109, width: 5, height: 5)).fill()
        let smile = NSBezierPath()
        smile.move(to: CGPoint(x: 127, y: 99))
        smile.curve(to: CGPoint(x: 143, y: 100), controlPoint1: CGPoint(x: 132, y: 95), controlPoint2: CGPoint(x: 139, y: 95))
        smile.lineWidth = 2
        smile.stroke()

        if character.id == "person-left" || character.id == "person-center-right" {
            hair.setStroke()
            for x in [117.0, 138.0] {
                let glasses = NSBezierPath(ovalIn: NSRect(x: x, y: 105, width: 14, height: 12))
                glasses.lineWidth = 1.8
                glasses.stroke()
            }
            let bridge = NSBezierPath(); bridge.move(to: CGPoint(x: 131, y: 111)); bridge.line(to: CGPoint(x: 138, y: 111)); bridge.lineWidth = 1.5; bridge.stroke()
        }

        skin.setFill()
        NSBezierPath(ovalIn: NSRect(x: 20, y: 17, width: 18, height: 10)).fill()
        NSBezierPath(ovalIn: NSRect(x: 145, y: 17, width: 20, height: 10)).fill()
    }

    private static func strokeLimb(points: [CGPoint], color: NSColor, width: CGFloat) {
        guard let first = points.first else { return }
        let path = NSBezierPath()
        path.move(to: first)
        for point in points.dropFirst() { path.line(to: point) }
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        path.lineWidth = width
        color.setStroke()
        path.stroke()
    }
}

private extension NSColor {
    convenience init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        let value = UInt64(cleaned, radix: 16) ?? 0
        let red = CGFloat((value >> 16) & 0xFF) / 255
        let green = CGFloat((value >> 8) & 0xFF) / 255
        let blue = CGFloat(value & 0xFF) / 255
        self.init(srgbRed: red, green: green, blue: blue, alpha: 1)
    }
}
