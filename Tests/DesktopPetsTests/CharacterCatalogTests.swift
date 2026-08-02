import XCTest
@testable import DesktopPets

final class CharacterCatalogTests: XCTestCase {
    func testBundledCatalogContainsFourStablePeople() throws {
        let catalog = try CharacterCatalog.loadBundled()
        XCTAssertEqual(catalog.characters.map(\.id), [
            "person-left", "person-center-left", "person-center-right", "person-right",
        ])
        XCTAssertTrue(catalog.characters.allSatisfy { $0.animation(named: "crawl") != nil })
    }

    func testMissingAnimationFallsBackToIdle() throws {
        let manifest = try CharacterCatalog.load(data: validJSON(animations: "\"idle\": {\"frames\": [{\"x\":0,\"y\":0,\"width\":0.25,\"height\":1}], \"fps\": 4}"))
            .characters[0]
        XCTAssertEqual(manifest.animation(named: "crawl"), manifest.animation(named: "idle"))
    }

    func testRejectsOutOfRangeNormalizedFrame() {
        let json = validJSON(animations: "\"idle\": {\"frames\": [{\"x\":0.9,\"y\":0,\"width\":0.5,\"height\":1}], \"fps\": 4}")
        XCTAssertThrowsError(try CharacterCatalog.load(data: json))
    }

    func testRejectsDuplicateIdentifiers() {
        let one = String(decoding: validJSON(), as: UTF8.self)
        let object = String(one.dropFirst().dropLast())
        let duplicate = Data("[\(object),\(object)]".utf8)
        XCTAssertThrowsError(try CharacterCatalog.load(data: duplicate))
    }

    func testCorruptJSONUsesProceduralFallback() {
        let catalog = CharacterCatalog.loadOrFallback(data: Data("not-json".utf8))
        XCTAssertEqual(catalog.characters.count, 4)
        XCTAssertTrue(catalog.usedFallback)
    }

    private func validJSON(animations: String = "\"idle\": {\"frames\": [{\"x\":0,\"y\":0,\"width\":0.25,\"height\":1}], \"fps\": 4}, \"crawl\": {\"frames\": [{\"x\":0,\"y\":0,\"width\":0.25,\"height\":1}], \"fps\": 8}") -> Data {
        Data("""
        [{
          "id":"test-person",
          "displayName":"Test",
          "atlasName":null,
          "palette":{"skin":"#D49A78","hair":"#201A18","shirt":"#222222","accent":"#FFFFFF"},
          "personality":{"speed":0.5,"curiosity":0.5,"sociability":0.5,"courage":0.5,"sleepiness":0.5},
          "anchor":{"x":0.5,"y":0.1},
          "collisionBody":{"x":0.2,"y":0.05,"width":0.6,"height":0.7},
          "animations":{\(animations)}
        }]
        """.utf8)
    }
}
