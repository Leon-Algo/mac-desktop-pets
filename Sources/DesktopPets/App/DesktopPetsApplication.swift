import AppKit
import CoreGraphics
import Foundation

struct SelfTestReport: Codable {
    let status: String
    let version: String
    let architecture: String
    let windowEnumerationAvailable: Bool
}

@MainActor
final class DesktopPetsApplication {
    private let mode: CommandLineMode

    init(mode: CommandLineMode) {
        self.mode = mode
    }

    func run() -> Int32 {
        switch mode {
        case .normal:
            let app = NSApplication.shared
            app.setActivationPolicy(.accessory)
            app.run()
            return EXIT_SUCCESS
        case .selfTest:
            let report = SelfTestReport(
                status: "ok",
                version: "0.1.0",
                architecture: Self.architecture,
                windowEnumerationAvailable: CGWindowListCopyWindowInfo(
                    [.optionOnScreenOnly, .excludeDesktopElements],
                    kCGNullWindowID
                ) != nil
            )
            return printJSON(report)
        case let .invalid(message):
            FileHandle.standardError.write(Data("\(message)\n".utf8))
            return EXIT_FAILURE
        }
    }

    private func printJSON<T: Encodable>(_ value: T) -> Int32 {
        do {
            let data = try JSONEncoder().encode(value)
            FileHandle.standardOutput.write(data)
            FileHandle.standardOutput.write(Data("\n".utf8))
            return EXIT_SUCCESS
        } catch {
            FileHandle.standardError.write(Data("Self-test encoding failed: \(error)\n".utf8))
            return EXIT_FAILURE
        }
    }

    private static var architecture: String {
#if arch(arm64)
        "arm64"
#elseif arch(x86_64)
        "x86_64"
#else
        "unknown"
#endif
    }
}
