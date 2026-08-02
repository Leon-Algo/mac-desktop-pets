import Foundation

enum ResourceBundleLocator {
    static var current: Bundle {
        if let resources = Bundle.main.resourceURL {
            let nestedURL = resources.appendingPathComponent("DesktopPets_DesktopPets.bundle", isDirectory: true)
            if let nested = Bundle(url: nestedURL) { return nested }
        }
        return Bundle.module
    }
}
