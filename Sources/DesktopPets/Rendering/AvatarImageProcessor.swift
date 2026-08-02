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

    static func normalizedPNG(from data: Data) throws -> Data {
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
        let sourceAspect = sourceSize.width / sourceSize.height
        var source = NSRect(origin: .zero, size: sourceSize)
        if sourceAspect > 1 {
            source.size.width = sourceSize.height
            source.origin.x = (sourceSize.width - source.size.width) / 2
        } else {
            source.size.height = sourceSize.width
            source.origin.y = (sourceSize.height - source.size.height) / 2
        }
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
