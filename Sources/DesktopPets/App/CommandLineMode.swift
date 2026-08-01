import Foundation

enum CommandLineMode: Equatable {
    case normal
    case selfTest
    case geometryProbe
    case renderSnapshot(String)
    case invalid(String)

    static func parse(_ arguments: [String]) -> CommandLineMode {
        guard arguments.count > 1 else { return .normal }
        switch arguments[1] {
        case "--self-test":
            return .selfTest
        case "--geometry-probe":
            return .geometryProbe
        case "--render-snapshot":
            guard arguments.count > 2 else { return .invalid("--render-snapshot requires an output path") }
            return .renderSnapshot(arguments[2])
        default:
            return .invalid("Unknown argument: \(arguments[1])")
        }
    }
}
