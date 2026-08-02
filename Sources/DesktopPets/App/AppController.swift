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
        statusMenu?.refresh(preferences: preferences)
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

    private func persistAndRefresh() {
        preferenceStore.save(preferences)
        statusMenu?.refresh(preferences: preferences)
    }

    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "好")
        alert.runModal()
    }

    private func showControlHintIfNeeded() {
        guard preferenceStore.shouldShowControlHint else { return }
        preferenceStore.markControlHintShown()
        DispatchQueue.main.async { [weak self] in
            self?.showAlert(
                title: "桌面伙伴已经启动",
                message: "点击人物可以互动，双击会召集大家，拖动可以把人物放到别处，右键可打开单人操作。\n\n暂停、隐藏和完全退出位于屏幕顶部菜单栏的爪印图标中。"
            )
        }
    }
}
