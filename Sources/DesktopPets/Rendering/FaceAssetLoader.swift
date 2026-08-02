import AppKit

@MainActor
enum FaceAssetLoader {
    static func image(for identifier: String) -> NSImage? {
        guard let url = ResourceBundleLocator.current.url(forResource: identifier, withExtension: "jpg") else { return nil }
        return NSImage(contentsOf: url)
    }
}
