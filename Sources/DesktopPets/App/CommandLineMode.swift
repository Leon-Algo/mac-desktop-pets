import Foundation

enum CommandLineMode: Equatable {
    case normal
    case selfTest
    case geometryProbe
    case invalid(String)

    static func parse(_ arguments: [String]) -> CommandLineMode {
        guard arguments.count > 1 else { return .normal }
        switch arguments[1] {
        case "--self-test":
            return .selfTest
        case "--geometry-probe":
            return .geometryProbe
        default:
            return .invalid("Unknown argument: \(arguments[1])")
        }
    }
}
