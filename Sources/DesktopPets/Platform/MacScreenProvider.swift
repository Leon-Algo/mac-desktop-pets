import AppKit
import Foundation

@MainActor
enum MacScreenProvider {
    static func displays() -> [WorldRect] {
        NSScreen.screens.compactMap { screen in
            WorldRect(
                x: screen.visibleFrame.origin.x,
                y: screen.visibleFrame.origin.y,
                width: screen.visibleFrame.width,
                height: screen.visibleFrame.height
            )
        }
    }

    static func mainScreenMaxY() -> Double {
        guard let main = NSScreen.screens.first else { return 0 }
        return main.frame.maxY
    }
}
