import XCTest
@testable import DesktopPets

@MainActor
final class CharacterRosterStoreTests: XCTestCase {
    func testMissingStoreUsesDefaultsAndValidRosterRoundTrips() throws {
        let root = temporaryRoot()
        let store = CharacterRosterStore(rootDirectory: root)
        XCTAssertEqual(store.load(), .default)

        var edited = CharacterRoster.default
        edited.profiles[0].displayName = "新名字"
        try store.save(edited)

        XCTAssertEqual(store.load().profiles[0].displayName, "新名字")
    }

    func testInvalidSaveDoesNotOverwriteLastGoodRosterAndCorruptJSONRecovers() throws {
        let root = temporaryRoot()
        let store = CharacterRosterStore(rootDirectory: root)
        try store.save(.default)

        XCTAssertThrowsError(try store.save(CharacterRoster(version: 1, profiles: [])))
        XCTAssertEqual(store.load(), .default)

        try Data("broken".utf8).write(to: store.rosterURL)
        XCTAssertEqual(store.load(), .default)
    }

    func testCorruptRosterIsBackedUpBeforeFallback() throws {
        let root = temporaryRoot()
        let store = CharacterRosterStore(rootDirectory: root)
        try store.save(.default)

        let corrupt = Data("not-json".utf8)
        try corrupt.write(to: store.rosterURL)

        _ = store.load()
        let backup = root.appendingPathComponent("characters-v1.json.corrupt")
        XCTAssertTrue(FileManager.default.fileExists(atPath: backup.path), "损坏文件应备份为 .corrupt")
        XCTAssertEqual(try Data(contentsOf: backup), corrupt, "备份内容应与损坏原文件一致")
    }

    func testImportedAvatarUsesSafePNGNameAndOrphansAreRemoved() throws {
        let root = temporaryRoot()
        let store = CharacterRosterStore(rootDirectory: root)
        let filename = try store.importAvatar(data: sampleImageData(width: 120, height: 60))

        XCTAssertTrue(filename.hasSuffix(".png"))
        XCTAssertEqual(filename, URL(fileURLWithPath: filename).lastPathComponent)
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.avatarsDirectory.appendingPathComponent(filename).path))

        var roster = CharacterRoster.default
        roster.profiles[0].avatarSource = .imported(filename: filename)
        try store.save(roster)
        try store.removeUnreferencedAvatars(roster: roster)
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.avatarsDirectory.appendingPathComponent(filename).path))

        try store.removeUnreferencedAvatars(roster: .default)
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.avatarsDirectory.appendingPathComponent(filename).path))
    }

    private func temporaryRoot() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("DesktopPetsTests-\(UUID().uuidString)", isDirectory: true)
    }

    private func sampleImageData(width: Int, height: Int) throws -> Data {
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: width,
            pixelsHigh: height,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        NSColor.systemOrange.setFill()
        NSRect(x: 0, y: 0, width: width, height: height).fill()
        NSGraphicsContext.restoreGraphicsState()
        return try XCTUnwrap(rep.representation(using: .jpeg, properties: [.compressionFactor: 0.9]))
    }
}
