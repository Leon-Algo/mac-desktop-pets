import Foundation

enum CommandLineMode: Equatable {
    case normal
    case selfTest
    case invalid(String)

    static func parse(_ arguments: [String]) -> CommandLineMode {
        guard arguments.count > 1 else { return .normal }
        switch arguments[1] {
        case "--self-test":
            return .selfTest
        default:
            return .invalid("Unknown argument: \(arguments[1])")
        }
    }
}
