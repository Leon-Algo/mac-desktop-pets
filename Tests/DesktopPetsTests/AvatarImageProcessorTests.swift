import XCTest
@testable import DesktopPets

@MainActor
final class AvatarImageProcessorTests: XCTestCase {
    func testNormalizesDecodableImageToSquare512PNG() throws {
        let source = NSImage(size: NSSize(width: 80, height: 40))
        source.lockFocus()
        NSColor.systemBlue.setFill()
        NSRect(x: 0, y: 0, width: 80, height: 40).fill()
        source.unlockFocus()
        let input = try XCTUnwrap(source.tiffRepresentation)

        let output = try AvatarImageProcessor.normalizedPNG(from: input)
        let rep = try XCTUnwrap(NSBitmapImageRep(data: output))

        XCTAssertEqual(rep.pixelsWide, 512)
        XCTAssertEqual(rep.pixelsHigh, 512)
        XCTAssertEqual(Array(output.prefix(8)), [137, 80, 78, 71, 13, 10, 26, 10])
    }

    func testRejectsUndecodableData() {
        XCTAssertThrowsError(try AvatarImageProcessor.normalizedPNG(from: Data("not-image".utf8)))
    }

    func testZoomAndPositionProduceAValidDifferentCrop() throws {
        let source = NSImage(size: NSSize(width: 160, height: 80))
        source.lockFocus()
        NSColor.systemRed.setFill(); NSRect(x: 0, y: 0, width: 80, height: 80).fill()
        NSColor.systemBlue.setFill(); NSRect(x: 80, y: 0, width: 80, height: 80).fill()
        source.unlockFocus()
        let input = try XCTUnwrap(source.tiffRepresentation)

        let left = try AvatarImageProcessor.normalizedPNG(from: input, zoom: 2, offsetX: -1, offsetY: 0)
        let right = try AvatarImageProcessor.normalizedPNG(from: input, zoom: 2, offsetX: 1, offsetY: 0)

        XCTAssertNotEqual(left, right)
        XCTAssertEqual(NSBitmapImageRep(data: left)?.pixelsWide, 512)
        XCTAssertEqual(NSBitmapImageRep(data: right)?.pixelsHigh, 512)
    }
}
