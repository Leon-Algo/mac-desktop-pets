import AppKit
import OSLog

@MainActor
final class StatusMenuController: NSObject {
    private(set) var statusItem: NSStatusItem
    let controlMenu = NSMenu(title: "桌宠总台")
    private weak var target: AppController?
    private var healthPolicy = StatusItemHealthPolicy()
    private let logger = Logger(subsystem: "com.codex.DesktopPets", category: "ControlCenter")
    var onFallbackRequired: (() -> Void)?

    var statusButtonTitle: String { statusItem.button?.title ?? "" }

    init(target: AppController) {
        self.target = target
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        configureStatusItem()
        observeStatusContext()
    }

    func refresh(preferences: AppPreferences, characters: [PetControlState], isFallbackVisible: Bool = false) {
        controlMenu.removeAllItems()
        var effectivePreferences = preferences
        effectivePreferences.petsHidden = ControlCenterVisibilityPolicy.isGloballyHidden(
            globalHidden: preferences.petsHidden,
            characters: characters
        )
        let state = MenuState(preferences: effectivePreferences)
        addItem(state.pauseTitle, action: #selector(AppController.togglePause(_:)), key: "p")
        addItem(state.visibilityTitle, action: #selector(AppController.toggleVisibility(_:)), key: "h")
        addItem("召回四人", action: #selector(AppController.recallPets(_:)), key: "r")
        controlMenu.addItem(.separator())

        let peopleItem = NSMenuItem(title: "四人管理", action: nil, keyEquivalent: "")
        let peopleMenu = NSMenu(title: "四人管理")
        for character in characters {
            let item = NSMenuItem(title: character.displayName, action: nil, keyEquivalent: "")
            item.submenu = characterMenu(for: character)
            peopleMenu.addItem(item)
        }
        peopleItem.submenu = peopleMenu
        controlMenu.addItem(peopleItem)
        controlMenu.addItem(.separator())

        addItem(state.clickThroughTitle, action: #selector(AppController.toggleClickThrough(_:)))
        addItem(
            isFallbackVisible ? "隐藏备用总台" : "显示备用总台",
            action: #selector(AppController.toggleControlCenter(_:))
        )
        let launch = addItem("登录时启动", action: #selector(AppController.toggleLaunchAtLogin(_:)))
        launch.state = preferences.launchAtLogin ? .on : .off
        controlMenu.addItem(.separator())
        addItem("诊断信息…", action: #selector(AppController.showDiagnostics(_:)), key: "d")
        controlMenu.addItem(.separator())
        addItem("退出桌面伙伴", action: #selector(AppController.quit(_:)), key: "q")
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }
        button.title = "🐾 桌宠"
        button.toolTip = "桌面伙伴总台：暂停、召回、设置或退出"
        button.setAccessibilityLabel("桌面伙伴总台")
        statusItem.isVisible = true
        statusItem.menu = controlMenu
        logger.info("Status item configured with labeled control")
    }

    @discardableResult
    func checkHealth() -> StatusItemHealthAction {
        let snapshot = healthSnapshot
        let action = healthPolicy.observe(snapshot)
        logger.info(
            "Status item health markedVisible=\(snapshot.isMarkedVisible) button=\(snapshot.hasButton) window=\(snapshot.hasWindow) action=\(String(describing: action), privacy: .public)"
        )
        switch action {
        case .none:
            break
        case .recreate:
            recreateStatusItem()
        case .showFallback:
            onFallbackRequired?()
        }
        return action
    }

    var healthSnapshot: StatusItemHealthSnapshot {
        StatusItemHealthSnapshot(
            isMarkedVisible: statusItem.isVisible,
            hasButton: statusItem.button != nil,
            hasWindow: statusItem.button?.window != nil
        )
    }

    var diagnostics: [String: Any] {
        let snapshot = healthSnapshot
        return [
            "statusItemMarkedVisible": snapshot.isMarkedVisible,
            "statusItemHasButton": snapshot.hasButton,
            "statusItemHasWindow": snapshot.hasWindow,
            "statusItemAppKitHealthy": snapshot.isHealthy,
            "statusItemPixelVisibilityKnown": false,
        ]
    }

    private func recreateStatusItem() {
        NSStatusBar.system.removeStatusItem(statusItem)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        configureStatusItem()
        logger.warning("Recreated unhealthy status item once")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.checkHealth()
        }
    }

    private func observeStatusContext() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(statusContextChanged(_:)),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(statusContextChanged(_:)),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(statusContextChanged(_:)),
            name: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil
        )
    }

    @objc private func statusContextChanged(_ notification: Notification) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            self?.checkHealth()
        }
    }

    private func characterMenu(for character: PetControlState) -> NSMenu {
        let menu = NSMenu(title: character.displayName)
        addCharacterItem(character.visibilityTitle, action: #selector(AppController.togglePetVisibility(_:)), id: character.id, to: menu)
        addCharacterItem("召回", action: #selector(AppController.recallPet(_:)), id: character.id, to: menu)
        addCharacterItem(character.pauseTitle, action: #selector(AppController.togglePetPause(_:)), id: character.id, to: menu)
        addCharacterItem("做个动作", action: #selector(AppController.reactPet(_:)), id: character.id, to: menu)
        return menu
    }

    @discardableResult
    private func addItem(_ title: String, action: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = target
        controlMenu.addItem(item)
        return item
    }

    private func addCharacterItem(_ title: String, action: Selector, id: String, to menu: NSMenu) {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = target
        item.representedObject = id
        menu.addItem(item)
    }
}
