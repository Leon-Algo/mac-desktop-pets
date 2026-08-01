import Foundation

let mode = CommandLineMode.parse(CommandLine.arguments)
let application = DesktopPetsApplication(mode: mode)
exit(application.run())
