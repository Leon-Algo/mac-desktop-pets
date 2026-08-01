import XCTest
@testable import DesktopPets

@MainActor
final class FaceAssetTests: XCTestCase {
    func testAllFourIdentityFaceAssetsLoadFromBundle() throws {
        for identifier in ["person-left", "person-center-left", "person-center-right", "person-right"] {
            let image = try XCTUnwrap(FaceAssetLoader.image(for: identifier), "Missing face for \(identifier)")
            XCTAssertGreaterThan(image.size.width, 100)
            XCTAssertGreaterThan(image.size.height, 100)
        }
    }
}
