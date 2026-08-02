import AppKit

@MainActor
final class StatusMenuController {
    private(set) var statusItem: NSStatusItem
    let controlMenu = NSMenu(title: "桌宠总台")
    private weak var target: AppController?

    var statusButtonTitle: String { statusItem.button?.title ?? "" }

    init(target: AppController) {
        self.target = target
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        configureStatusItem()
    }

    func refresh(preferences: AppPreferences, characters: [PetControlState]) {
        controlMenu.removeAllItems()
        let state = MenuState(preferences: preferences)
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
