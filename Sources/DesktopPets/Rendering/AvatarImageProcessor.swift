import AppKit
import Foundation

enum AvatarImageProcessorError: Error, Equatable {
    case undecodableImage
    case bitmapCreationFailed
    case pngEncodingFailed
}

@MainActor
enum AvatarImageProcessor {
    static let pixelSize = 512

    static func normalizedPNG(
        from data: Data,
        zoom: Double = 1,
        offsetX: Double = 0,
        offsetY: Double = 0
    ) throws -> Data {
        guard let image = NSImage(data: data), image.size.width > 0, image.size.height > 0 else {
            throw AvatarImageProcessorError.undecodableImage
        }
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixelSize,
            pixelsHigh: pixelSize,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else { throw AvatarImageProcessorError.bitmapCreationFailed }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        NSColor.clear.setFill()
        NSRect(x: 0, y: 0, width: pixelSize, height: pixelSize).fill()
        let sourceSize = image.size
        let safeZoom = min(max(zoom, 1), 3)
        let cropSide = min(sourceSize.width, sourceSize.height) / safeZoom
        let centeredX = (sourceSize.width - cropSide) / 2
        let centeredY = (sourceSize.height - cropSide) / 2
        let maxShiftX = max(0, (sourceSize.width - cropSide) / 2)
        let maxShiftY = max(0, (sourceSize.height - cropSide) / 2)
        let source = NSRect(
            x: centeredX + min(max(offsetX, -1), 1) * maxShiftX,
            y: centeredY + min(max(offsetY, -1), 1) * maxShiftY,
            width: cropSide,
            height: cropSide
        )
        image.draw(
            in: NSRect(x: 0, y: 0, width: pixelSize, height: pixelSize),
            from: source,
            operation: .copy,
            fraction: 1
        )
        NSGraphicsContext.restoreGraphicsState()

        guard let png = rep.representation(using: .png, properties: [:]) else {
            throw AvatarImageProcessorError.pngEncodingFailed
        }
        return png
    }
}
