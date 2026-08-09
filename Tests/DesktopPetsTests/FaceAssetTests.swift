import XCTest
@testable import DesktopPets

@MainActor
final class FaceAssetTests: XCTestCase {
    func testAllTwelveBuiltInAvatarsRenderAsDistinctSquareImages() throws {
        let payloads = BuiltInAvatarPreset.allCases.map {
            BuiltInAvatarRenderer.image(for: $0, size: NSSize(width: 128, height: 128)).tiffRepresentation
        }
        XCTAssertTrue(payloads.allSatisfy { $0 != nil })
        XCTAssertEqual(Set(payloads.compactMap { $0?.base64EncodedString() }).count, 12)
    }

    func testAllFourIdentityFaceAssetsLoadFromBundle() throws {
        for identifier in ["person-left", "person-center-left", "person-center-right", "person-right"] {
            let image = try XCTUnwrap(FaceAssetLoader.image(for: identifier), "Missing face for \(identifier)")
            XCTAssertGreaterThan(image.size.width, 100)
            XCTAssertGreaterThan(image.size.height, 100)
        }
    }

    func testResourceLocatorFindsCatalogInSwiftPMBundle() {
        let bundle = ResourceBundleLocator.current
        XCTAssertNotNil(bundle.url(forResource: "characters", withExtension: "json"))
    }
}
