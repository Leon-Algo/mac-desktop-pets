import AppKit

@MainActor
final class StatusMenuController {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let menu = NSMenu()
    private weak var target: AppController?

    private let pauseItem = NSMenuItem()
    private let visibilityItem = NSMenuItem()
    private let clickThroughItem = NSMenuItem()
    private let launchItem = NSMenuItem()

    init(target: AppController) {
        self.target = target
        statusItem.button?.image = NSImage(systemSymbolName: "pawprint.fill", accessibilityDescription: "桌面伙伴")
        statusItem.button?.toolTip = "桌面伙伴"

        configure(pauseItem, action: #selector(AppController.togglePause(_:)))
        configure(visibilityItem, action: #selector(AppController.toggleVisibility(_:)))
        menu.addItem(NSMenuItem(title: "召回四人", action: #selector(AppController.recallPets(_:)), keyEquivalent: "r"))
        menu.items.last?.target = target
        menu.addItem(.separator())
        configure(clickThroughItem, action: #selector(AppController.toggleClickThrough(_:)))
        configure(launchItem, action: #selector(AppController.toggleLaunchAtLogin(_:)))
        menu.addItem(.separator())
        let diagnostics = NSMenuItem(title: "诊断信息…", action: #selector(AppController.showDiagnostics(_:)), keyEquivalent: "d")
        diagnostics.target = target
        menu.addItem(diagnostics)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "退出桌面伙伴", action: #selector(AppController.quit(_:)), keyEquivalent: "q")
        quit.target = target
        menu.addItem(quit)
        statusItem.menu = menu
    }

    func refresh(preferences: AppPreferences) {
        let state = MenuState(preferences: preferences)
        pauseItem.title = state.pauseTitle
        visibilityItem.title = state.visibilityTitle
        clickThroughItem.title = state.clickThroughTitle
        launchItem.title = "登录时启动"
        launchItem.state = preferences.launchAtLogin ? .on : .off
    }

    private func configure(_ item: NSMenuItem, action: Selector) {
        item.action = action
        item.target = target
        menu.addItem(item)
    }
}
