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
}
