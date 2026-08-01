import Foundation

enum CommandLineMode: Equatable {
    case normal
    case selfTest
    case geometryProbe
    case renderSnapshot(String)
    case inspectRunning(Int32)
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
        case "--inspect-running":
            guard arguments.count > 2, let pid = Int32(arguments[2]), pid > 0 else {
                return .invalid("--inspect-running requires a positive PID")
            }
            return .inspectRunning(pid)
        default:
            return .invalid("Unknown argument: \(arguments[1])")
        }
    }
}
