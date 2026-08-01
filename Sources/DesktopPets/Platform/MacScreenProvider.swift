import AppKit
import Foundation

@MainActor
enum MacScreenProvider {
    static func displays() -> [WorldRect] {
        NSScreen.screens.compactMap { screen in
            WorldRect(
                x: screen.frame.origin.x,
                y: screen.frame.origin.y,
                width: screen.frame.width,
                height: screen.frame.height
            )
        }
    }

    static func mainScreenMaxY() -> Double {
        guard let main = NSScreen.screens.first else { return 0 }
        return main.frame.maxY
    }
}
