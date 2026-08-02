import AppKit
import Foundation
import ServiceManagement

@MainActor
final class AppController: NSObject, NSApplicationDelegate {
    private let preferenceStore = PreferencesStore()
    private var preferences = AppPreferences.defaults
    private var runner: WorldRunner?
    private var statusMenu: StatusMenuController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        preferences = preferenceStore.load()
        let catalog = (try? CharacterCatalog.loadBundled()) ?? .fallback
        runner = WorldRunner(characters: catalog.characters, geometryProvider: CGWindowGeometryProvider())
        statusMenu = StatusMenuController(target: self)
        runner?.onControlStateChange = { [weak self] _ in self?.refreshControls() }
        runner?.onUICommand = { [weak self] command in self?.handle(command) }
        refreshControls()
        runner?.start(preferences: preferences)
        ProcessInfo.processInfo.disableAutomaticTermination("Desktop pets remain active while the menu-bar app is running")
        ProcessInfo.processInfo.disableSuddenTermination()
        showControlHintIfNeeded()
    }

    func applicationWillTerminate(_ notification: Notification) {
        runner?.stop()
        ProcessInfo.processInfo.enableSuddenTermination()
        ProcessInfo.processInfo.enableAutomaticTermination("Desktop pets are quitting")
    }

    @objc func togglePause(_ sender: Any?) {
        preferences.paused.toggle()
        runner?.setPaused(preferences.paused)
        persistAndRefresh()
    }

    @objc func toggleVisibility(_ sender: Any?) {
        preferences.petsHidden.toggle()
        runner?.setHidden(preferences.petsHidden)
        persistAndRefresh()
    }

    @objc func recallPets(_ sender: Any?) {
        preferences.petsHidden = false
        runner?.recall()
        persistAndRefresh()
    }

    @objc func toggleClickThrough(_ sender: Any?) {
        preferences.clickThrough.toggle()
        runner?.setClickThrough(preferences.clickThrough)
        persistAndRefresh()
    }

    @objc func toggleLaunchAtLogin(_ sender: Any?) {
        do {
            if preferences.launchAtLogin {
                try SMAppService.mainApp.unregister()
                preferences.launchAtLogin = false
            } else {
                try SMAppService.mainApp.register()
                preferences.launchAtLogin = true
            }
            persistAndRefresh()
        } catch {
            showAlert(title: "无法更改登录启动", message: error.localizedDescription)
        }
    }

    @objc func showDiagnostics(_ sender: Any?) {
        let data = runner?.diagnostics ?? [:]
        let text = data.keys.sorted().map { "\($0): \(data[$0] ?? "-")" }.joined(separator: "\n")
        showAlert(title: "桌面伙伴诊断", message: text)
    }

    @objc func quit(_ sender: Any?) {
        NSApplication.shared.terminate(nil)
    }

    @objc func togglePetVisibility(_ sender: Any?) {
        guard let id = representedPetID(sender),
              let state = runner?.controlSnapshot.first(where: { $0.id == id }) else { return }
        runner?.handle(state.isHidden ? .recall(id: id) : .hide(id: id))
    }

    @objc func recallPet(_ sender: Any?) {
        guard let id = representedPetID(sender) else { return }
        runner?.handle(.recall(id: id))
    }

    @objc func togglePetPause(_ sender: Any?) {
        guard let id = representedPetID(sender) else { return }
        runner?.handle(.togglePause(id: id))
    }

    @objc func reactPet(_ sender: Any?) {
        guard let id = representedPetID(sender) else { return }
        runner?.handle(.react(id: id))
    }

    private func persistAndRefresh() {
        preferenceStore.save(preferences)
        refreshControls()
    }

    private func refreshControls() {
        statusMenu?.refresh(preferences: preferences, characters: runner?.controlSnapshot ?? [])
    }

    private func representedPetID(_ sender: Any?) -> String? {
        (sender as? NSMenuItem)?.representedObject as? String
    }

    private func handle(_ command: ControlCenterCommand) {
        switch command {
        case .openControlCenter:
            break
        case .quitApplication:
            quit(nil)
        }
    }

    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "好")
        let previousPolicy = NSApplication.shared.activationPolicy()
        if previousPolicy != .regular {
            NSApplication.shared.setActivationPolicy(.regular)
        }
        NSApplication.shared.activate(ignoringOtherApps: true)
        alert.runModal()
        if previousPolicy != .regular {
            NSApplication.shared.setActivationPolicy(previousPolicy)
        }
    }

    private func showControlHintIfNeeded() {
        guard ControlHintPolicy.shouldShow(
            storedHintNeeded: preferenceStore.shouldShowControlHint,
            suppressionValue: ProcessInfo.processInfo.environment["DESKTOP_PETS_SUPPRESS_CONTROL_HINT"]
        ) else { return }
        preferenceStore.markControlHintShown()
        DispatchQueue.main.async { [weak self] in
            self?.showAlert(
                title: "桌面伙伴已经启动",
                message: "点击人物可以互动，双击会召集大家，拖动可以把人物放到别处，右键可打开单人操作。\n\n暂停、隐藏和完全退出位于屏幕顶部菜单栏的爪印图标中。"
            )
        }
    }
}
