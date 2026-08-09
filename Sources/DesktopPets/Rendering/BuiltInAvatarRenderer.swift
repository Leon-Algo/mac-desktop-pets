import AppKit

@MainActor
enum BuiltInAvatarRenderer {
    static func image(for preset: BuiltInAvatarPreset, size: NSSize) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        let bounds = NSRect(origin: .zero, size: size)
        NSColor.clear.setFill()
        bounds.fill()
        let colors = palette(for: preset)
        colors.background.setFill()
        NSBezierPath(ovalIn: bounds.insetBy(dx: size.width * 0.04, dy: size.height * 0.04)).fill()

        let face = bounds.insetBy(dx: size.width * 0.20, dy: size.height * 0.14)
        colors.skin.setFill()
        NSBezierPath(ovalIn: face).fill()

        colors.hair.setFill()
        let variant = preset.index % 4
        switch variant {
        case 0:
            NSBezierPath(roundedRect: NSRect(x: face.minX, y: face.midY, width: face.width, height: face.height * 0.48), xRadius: face.width * 0.25, yRadius: face.width * 0.25).fill()
        case 1:
            NSBezierPath(ovalIn: NSRect(x: face.minX - face.width * 0.05, y: face.midY, width: face.width * 1.1, height: face.height * 0.55)).fill()
        case 2:
            for x in stride(from: face.minX, through: face.maxX - face.width * 0.2, by: face.width * 0.18) {
                NSBezierPath(ovalIn: NSRect(x: x, y: face.maxY - face.height * 0.25, width: face.width * 0.28, height: face.height * 0.28)).fill()
            }
        default:
            NSBezierPath(roundedRect: NSRect(x: face.minX, y: face.maxY - face.height * 0.34, width: face.width, height: face.height * 0.34), xRadius: 5, yRadius: 5).fill()
        }

        NSColor(calibratedWhite: 0.12, alpha: 1).setFill()
        let eyeY = face.midY + face.height * 0.02
        let eyeSize = max(3, face.width * 0.075)
        for x in [face.midX - face.width * 0.18, face.midX + face.width * 0.18] {
            NSBezierPath(ovalIn: NSRect(x: x - eyeSize / 2, y: eyeY, width: eyeSize, height: eyeSize)).fill()
        }
        colors.accent.setStroke()
        let smile = NSBezierPath()
        smile.move(to: CGPoint(x: face.midX - face.width * 0.12, y: face.midY - face.height * 0.16))
        smile.curve(
            to: CGPoint(x: face.midX + face.width * 0.12, y: face.midY - face.height * 0.16),
            controlPoint1: CGPoint(x: face.midX - face.width * 0.06, y: face.midY - face.height * 0.25),
            controlPoint2: CGPoint(x: face.midX + face.width * 0.06, y: face.midY - face.height * 0.25)
        )
        smile.lineWidth = max(1.5, size.width * 0.018)
        smile.stroke()
        image.unlockFocus()
        return image
    }

    private static func palette(for preset: BuiltInAvatarPreset) -> (background: NSColor, skin: NSColor, hair: NSColor, accent: NSColor) {
        let backgrounds: [NSColor] = [.systemOrange, .systemBlue, .systemMint, .systemPurple, .systemPink, .systemYellow, .systemCyan, .systemGreen, .systemRed, .systemGray, .systemIndigo, .brown]
        let skins = ["#F2C5A8", "#D99A78", "#B9785D", "#E6B18F"]
        let hairs = ["#3C241D", "#17191C", "#6A3F2B", "#2F2340", "#8B5A36", "#24334A"]
        let index = preset.index
        return (
            backgrounds[index].withAlphaComponent(0.28),
            NSColor(hexString: skins[index % skins.count]),
            NSColor(hexString: hairs[index % hairs.count]),
            NSColor(calibratedWhite: 0.18, alpha: 1)
        )
    }
}

private extension NSColor {
    convenience init(hexString: String) {
        let value = UInt64(hexString.dropFirst(), radix: 16) ?? 0
        self.init(
            srgbRed: CGFloat((value >> 16) & 255) / 255,
            green: CGFloat((value >> 8) & 255) / 255,
            blue: CGFloat(value & 255) / 255,
            alpha: 1
        )
    }
}
