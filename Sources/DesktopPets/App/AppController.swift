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
    private let rosterStore = CharacterRosterStore()
    private var roster = CharacterRoster.default
    private var characterSettings: CharacterSettingsWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        preferences = VerificationLaunchPolicy.preferences(
            from: preferenceStore.load(),
            forceVisibleValue: ProcessInfo.processInfo.environment["DESKTOP_PETS_FORCE_VISIBLE"]
        )
        let catalog = (try? CharacterCatalog.loadBundled()) ?? .fallback
        let fallbackRoster = preferenceStore.hasStoredPreferences
            ? CharacterRoster.legacy(from: catalog.characters)
            : .default
        roster = rosterStore.load(fallback: fallbackRoster)
        if !rosterStore.hasStoredRoster { try? rosterStore.save(roster) }
        runner = makeRunner(characters: roster.manifests)
        statusMenu = StatusMenuController(target: self)
        if let menu = statusMenu?.controlMenu {
            controlCenterPanel = ControlCenterPanelController(menu: menu)
        }
        statusMenu?.onFallbackRequired = { [weak self] in self?.showControlCenter() }
        statusMenu?.onStatusContextChanged = { [weak self] in
            self?.controlCenterPanel?.repositionOnCurrentScreen()
            self?.refreshMenuOnly()
        }
        wireRunnerCallbacks()
        refreshControls()
        runner?.start(preferences: preferences)
        controlCenterPanel?.show()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) { [weak self] in
            self?.statusMenu?.checkHealth()
        }
        showControlHintIfNeeded()
        if VerificationLaunchPolicy.shouldOpenCharacterSettings(
            value: ProcessInfo.processInfo.environment["DESKTOP_PETS_OPEN_CHARACTER_SETTINGS"]
        ) {
            DispatchQueue.main.async { [weak self] in self?.showCharacterSettings(nil) }
        }
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

    @objc func performPetAction(_ sender: Any?) {
        guard let request = (sender as? NSMenuItem)?.representedObject as? PetActionRequest else { return }
        runner?.handle(.performAction(request))
    }

    @objc func showCharacterSettings(_ sender: Any?) {
        if characterSettings == nil {
            let controller = CharacterSettingsWindowController(roster: roster)
            controller.onImportAvatar = { [weak self] data in
                guard let self else { throw CharacterRosterStoreError.applicationSupportUnavailable }
                return try self.rosterStore.importAvatar(data: data)
            }
            controller.onSave = { [weak self] saved in
                guard let self else { return }
                try self.applyRoster(saved)
            }
            characterSettings = controller
        }
        characterSettings?.present(roster: roster)
    }

    func applyRoster(_ candidate: CharacterRoster) throws {
        let valid = try candidate.validated()
        try rosterStore.save(valid)
        let previousState = runner?.controlSnapshot ?? []
        runner?.stop()
        roster = valid
        runner = makeRunner(characters: valid.manifests)
        wireRunnerCallbacks()
        runner?.start(preferences: preferences)
        runner?.restoreControlState(previousState, restorePause: !preferences.paused)
        // 先刷新 UI，让用户立即看到已生效的新 roster。
        refreshControls()
        // 孤儿头像清理属非关键维护：失败仅遗留无用文件、无数据丢失风险，
        // 不应让已成功的保存流程误报"保存失败"，故在此非致命化处理。
        try? rosterStore.removeUnreferencedAvatars(roster: valid)
    }

    private func makeRunner(characters: [CharacterManifest]) -> WorldRunner {
        WorldRunner(characters: characters, geometryProvider: CGWindowGeometryProvider())
    }

    private func wireRunnerCallbacks() {
        runner?.onControlStateChange = { [weak self] _ in self?.refreshControls() }
        runner?.onUICommand = { [weak self] command in self?.handle(command) }
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
