import AppKit
import Foundation

struct PetAlphaMask: Sendable {
    let width: Int
    let height: Int
    private let alpha: [UInt8]

    init(width: Int, height: Int, alpha: [UInt8]) {
        self.width = max(0, width)
        self.height = max(0, height)
        self.alpha = alpha
    }

    init(image: NSImage) {
        let maximumPointDimension: CGFloat = 48
        let scale = min(1, maximumPointDimension / max(image.size.width, image.size.height))
        let sampledSize = CGSize(
            width: max(1, (image.size.width * scale).rounded()),
            height: max(1, (image.size.height * scale).rounded())
        )
        let sampledImage = NSImage(size: sampledSize)
        sampledImage.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        image.draw(in: NSRect(origin: .zero, size: sampledSize))
        sampledImage.unlockFocus()
        guard let tiff = sampledImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              bitmap.pixelsWide > 0,
              bitmap.pixelsHigh > 0 else {
            self.init(width: 0, height: 0, alpha: [])
            return
        }
        var values = [UInt8]()
        values.reserveCapacity(bitmap.pixelsWide * bitmap.pixelsHigh)
        for y in 0..<bitmap.pixelsHigh {
            for x in 0..<bitmap.pixelsWide {
                let component = bitmap.colorAt(x: x, y: y)?.alphaComponent ?? 0
                values.append(UInt8(max(0, min(255, Int((component * 255).rounded())))))
            }
        }
        self.init(width: bitmap.pixelsWide, height: bitmap.pixelsHigh, alpha: values)
    }

    func containsOpaquePixel(normalizedPoint point: CGPoint, threshold: UInt8 = 24) -> Bool {
        guard width > 0, height > 0,
              point.x >= 0, point.x < 1,
              point.y >= 0, point.y < 1 else { return false }
        let x = min(width - 1, Int(point.x * CGFloat(width)))
        let y = min(height - 1, Int(point.y * CGFloat(height)))
        let index = y * width + x
        guard alpha.indices.contains(index) else { return false }
        return alpha[index] >= threshold
    }
}
