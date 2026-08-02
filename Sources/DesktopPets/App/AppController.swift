import AppKit
import Foundation
import ServiceManagement

@MainActor
final class AppController: NSObject, NSApplicationDelegate {
    private let preferenceStore = PreferencesStore()
    private var preferences = AppPreferences.defaults
    private var runner: WorldRunner?
    private var statusMenu: StatusMenuController?
    private var controlCenterPanel: ControlCenterPanelController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        preferences = VerificationLaunchPolicy.preferences(
            from: preferenceStore.load(),
            forceVisibleValue: ProcessInfo.processInfo.environment["DESKTOP_PETS_FORCE_VISIBLE"]
        )
        let catalog = (try? CharacterCatalog.loadBundled()) ?? .fallback
        runner = WorldRunner(characters: catalog.characters, geometryProvider: CGWindowGeometryProvider())
        statusMenu = StatusMenuController(target: self)
        if let menu = statusMenu?.controlMenu {
            controlCenterPanel = ControlCenterPanelController(menu: menu)
        }
        statusMenu?.onFallbackRequired = { [weak self] in self?.showControlCenter() }
        statusMenu?.onStatusContextChanged = { [weak self] in
            self?.controlCenterPanel?.repositionOnCurrentScreen()
            self?.refreshMenuOnly()
        }
        runner?.onControlStateChange = { [weak self] _ in self?.refreshControls() }
        runner?.onUICommand = { [weak self] command in self?.handle(command) }
        refreshControls()
        runner?.start(preferences: preferences)
        controlCenterPanel?.show()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) { [weak self] in
            self?.statusMenu?.checkHealth()
        }
        showControlHintIfNeeded()
    }

    func applicationWillTerminate(_ notification: Notification) {
        runner?.stop()
        controlCenterPanel?.hide()
        ProcessInfo.processInfo.enableSuddenTermination()
        ProcessInfo.processInfo.enableAutomaticTermination("Desktop pets are quitting")
    }

    @objc func togglePause(_ sender: Any?) {
        preferences.paused.toggle()
        runner?.setPaused(preferences.paused)
        persistAndRefresh()
    }

    @objc func toggleVisibility(_ sender: Any?) {
        preferences.petsHidden = ControlCenterVisibilityPolicy.nextGlobalHidden(
            globalHidden: preferences.petsHidden,
            characters: runner?.controlSnapshot ?? []
        )
        runner?.setHidden(preferences.petsHidden)
        if preferences.petsHidden { showControlCenter() }
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

    @objc func setPetScale(_ sender: Any?) {
        guard let rawValue = (sender as? NSMenuItem)?.representedObject as? String,
              let preset = PetScalePreset(rawValue: rawValue) else { return }
        preferences.petScale = preset
        runner?.setScale(preset)
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
        var data = runner?.diagnostics ?? [:]
        statusMenu?.diagnostics.forEach { data[$0.key] = $0.value }
        data["fallbackControlVisible"] = controlCenterPanel?.isVisible ?? false
        let text = data.keys.sorted().map { "\($0): \(data[$0] ?? "-")" }.joined(separator: "\n")
        showAlert(title: "桌面伙伴诊断", message: text)
    }

    @objc func quit(_ sender: Any?) {
        NSApplication.shared.terminate(nil)
    }

    @objc func toggleControlCenter(_ sender: Any?) {
        let states = runner?.controlSnapshot ?? []
        if !ControlCenterVisibilityPolicy.canHideFallback(
            clickThrough: preferences.clickThrough,
            globalHidden: preferences.petsHidden,
            characters: states
        ) {
            showControlCenter()
        } else {
            controlCenterPanel?.toggle()
            refreshControls()
        }
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
        let states = runner?.controlSnapshot ?? []
        if ControlCenterVisibilityPolicy.mustShowFallback(
            globalHidden: preferences.petsHidden,
            characters: states
        ) {
            showControlCenter()
        }
        statusMenu?.refresh(
            preferences: preferences,
            characters: states,
            isFallbackVisible: controlCenterPanel?.isVisible ?? false,
            canHideFallback: ControlCenterVisibilityPolicy.canHideFallback(
                clickThrough: preferences.clickThrough,
                globalHidden: preferences.petsHidden,
                characters: states
            )
        )
    }

    private func representedPetID(_ sender: Any?) -> String? {
        (sender as? NSMenuItem)?.representedObject as? String
    }

    private func handle(_ command: ControlCenterCommand) {
        switch command {
        case .openControlCenter:
            showControlCenter(openingMenu: true)
        case .quitApplication:
            quit(nil)
        }
    }

    private func showControlCenter(openingMenu: Bool = false) {
        controlCenterPanel?.show(openingMenu: openingMenu)
        refreshMenuOnly()
    }

    private func refreshMenuOnly() {
        let states = runner?.controlSnapshot ?? []
        statusMenu?.refresh(
            preferences: preferences,
            characters: states,
            isFallbackVisible: controlCenterPanel?.isVisible ?? false,
            canHideFallback: ControlCenterVisibilityPolicy.canHideFallback(
                clickThrough: preferences.clickThrough,
                globalHidden: preferences.petsHidden,
                characters: states
            )
        )
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
        controlCenterPanel?.button.toolTip = ControlHintPolicy.guidance
        showControlCenter()
    }
}
