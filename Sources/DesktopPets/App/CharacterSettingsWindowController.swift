import AppKit
import UniformTypeIdentifiers

@MainActor
final class CharacterSettingsWindowController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate, NSTextFieldDelegate {
    let tableView = NSTableView()
    let previewImageView = NSImageView()
    let nameField = NSTextField()
    let avatarPopUp = NSPopUpButton()
    let bodyStylePopUp = NSPopUpButton()
    let outfitPopUp = NSPopUpButton()
    let personalityPopUp = NSPopUpButton()
    let addButton = NSButton(title: "+", target: nil, action: nil)
    let deleteButton = NSButton(title: "−", target: nil, action: nil)
    let moveUpButton = NSButton(title: "上移", target: nil, action: nil)
    let moveDownButton = NSButton(title: "下移", target: nil, action: nil)
    let importButton = NSButton(title: "导入本地头像…", target: nil, action: nil)
    let saveButton = NSButton(title: "保存并应用", target: nil, action: nil)
    let cancelButton = NSButton(title: "取消", target: nil, action: nil)
    private let countLabel = NSTextField(labelWithString: "")
    private let errorLabel = NSTextField(labelWithString: "")
    private var sliders: [NSSlider] = []
    private var isRefreshingSelection = false
    private(set) var model: CharacterEditorModel
    var onSave: ((CharacterRoster) throws -> Void)?
    var onImportAvatar: ((Data) throws -> String)?

    init(roster: CharacterRoster) {
        model = CharacterEditorModel(roster: roster)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 820, height: 560),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "人物设置"
        window.minSize = NSSize(width: 820, height: 560)
        window.maxSize = NSSize(width: 820, height: 560)
        window.isReleasedWhenClosed = false
        super.init(window: window)
        buildInterface()
        refreshAll()
    }

    required init?(coder: NSCoder) { nil }

    func present(roster: CharacterRoster? = nil) {
        if let roster {
            model = CharacterEditorModel(roster: roster)
            refreshAll()
        }
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func numberOfRows(in tableView: NSTableView) -> Int { model.draft.profiles.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let identifier = NSUserInterfaceItemIdentifier("CharacterNameCell")
        let field = (tableView.makeView(withIdentifier: identifier, owner: self) as? NSTextField)
            ?? NSTextField(labelWithString: "")
        field.identifier = identifier
        field.lineBreakMode = .byTruncatingTail
        field.stringValue = model.draft.profiles[row].displayName
        return field
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        guard !isRefreshingSelection else { return }
        guard tableView.selectedRow >= 0 else { return }
        model.selectedIndex = tableView.selectedRow
        refreshEditor()
    }

    func controlTextDidChange(_ obj: Notification) {
        guard obj.object as? NSTextField === nameField else { return }
        model.updateSelectedName(nameField.stringValue)
        tableView.reloadData()
        tableView.selectRowIndexes(IndexSet(integer: model.selectedIndex), byExtendingSelection: false)
        refreshPreview()
    }

    private func buildInterface() {
        guard let root = window?.contentView else { return }
        root.wantsLayer = true

        let left = NSView(frame: NSRect(x: 0, y: 0, width: 230, height: 560))
        left.wantsLayer = true
        left.layer?.backgroundColor = NSColor.windowBackgroundColor.blended(withFraction: 0.08, of: .black)?.cgColor
        root.addSubview(left)

        let heading = NSTextField(labelWithString: "我的人物")
        heading.font = .systemFont(ofSize: 16, weight: .semibold)
        heading.frame = NSRect(x: 18, y: 518, width: 120, height: 24)
        left.addSubview(heading)
        countLabel.frame = NSRect(x: 145, y: 520, width: 66, height: 20)
        countLabel.alignment = .right
        countLabel.textColor = .secondaryLabelColor
        left.addSubview(countLabel)

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
        column.title = "人物"
        column.width = 190
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.rowHeight = 34
        tableView.delegate = self
        tableView.dataSource = self
        tableView.allowsEmptySelection = false
        let scroll = NSScrollView(frame: NSRect(x: 14, y: 112, width: 202, height: 394))
        scroll.documentView = tableView
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder
        left.addSubview(scroll)

        configureButton(addButton, action: #selector(addCharacter(_:)), frame: NSRect(x: 14, y: 70, width: 42, height: 30), parent: left)
        configureButton(deleteButton, action: #selector(deleteCharacter(_:)), frame: NSRect(x: 60, y: 70, width: 42, height: 30), parent: left)
        configureButton(moveUpButton, action: #selector(moveCharacterUp(_:)), frame: NSRect(x: 108, y: 70, width: 50, height: 30), parent: left)
        configureButton(moveDownButton, action: #selector(moveCharacterDown(_:)), frame: NSRect(x: 162, y: 70, width: 54, height: 30), parent: left)

        let detailTitle = NSTextField(labelWithString: "人物外观与性格")
        detailTitle.font = .systemFont(ofSize: 18, weight: .semibold)
        detailTitle.frame = NSRect(x: 258, y: 518, width: 240, height: 26)
        root.addSubview(detailTitle)

        previewImageView.frame = NSRect(x: 260, y: 320, width: 180, height: 170)
        previewImageView.imageScaling = .scaleProportionallyUpOrDown
        previewImageView.wantsLayer = true
        previewImageView.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        previewImageView.layer?.cornerRadius = 12
        root.addSubview(previewImageView)

        avatarPopUp.addItem(withTitle: "当前头像")
        avatarPopUp.addItems(withTitles: BuiltInAvatarPreset.allCases.enumerated().map { "内置头像 \($0.offset + 1)" })
        bodyStylePopUp.addItems(withTitles: BodyStyle.allCases.map(\.displayName))
        outfitPopUp.addItems(withTitles: OutfitPreset.allCases.map(\.displayName))
        personalityPopUp.addItems(withTitles: PersonalityPreset.allCases.map(\.displayName))
        nameField.delegate = self
        let rows: [(String, NSView)] = [
            ("名称", nameField),
            ("头像", avatarPopUp),
            ("服装样式", bodyStylePopUp),
            ("服装配色", outfitPopUp),
            ("性格模板", personalityPopUp),
        ]
        for (index, row) in rows.enumerated() {
            let y = 450 - CGFloat(index) * 48
            let label = NSTextField(labelWithString: row.0)
            label.frame = NSRect(x: 466, y: y + 4, width: 80, height: 22)
            row.1.frame = NSRect(x: 550, y: y, width: 230, height: 28)
            root.addSubview(label)
            root.addSubview(row.1)
        }
        avatarPopUp.target = self; avatarPopUp.action = #selector(avatarChanged(_:))
        bodyStylePopUp.target = self; bodyStylePopUp.action = #selector(bodyStyleChanged(_:))
        outfitPopUp.target = self; outfitPopUp.action = #selector(outfitChanged(_:))
        personalityPopUp.target = self; personalityPopUp.action = #selector(personalityChanged(_:))
        configureButton(importButton, action: #selector(importAvatar(_:)), frame: NSRect(x: 260, y: 282, width: 180, height: 30), parent: root)

        let advanced = NSTextField(labelWithString: "高级性格参数")
        advanced.font = .systemFont(ofSize: 14, weight: .semibold)
        advanced.frame = NSRect(x: 260, y: 244, width: 140, height: 22)
        root.addSubview(advanced)
        let sliderNames = ["速度", "好奇", "社交", "勇气", "困倦"]
        for (index, name) in sliderNames.enumerated() {
            let y = 207 - CGFloat(index) * 34
            let label = NSTextField(labelWithString: name)
            label.frame = NSRect(x: 260, y: y + 2, width: 50, height: 20)
            let slider = NSSlider(value: 0.5, minValue: 0, maxValue: 1, target: self, action: #selector(sliderChanged(_:)))
            slider.tag = index
            slider.frame = NSRect(x: 315, y: y, width: 300, height: 24)
            sliders.append(slider)
            root.addSubview(label)
            root.addSubview(slider)
        }

        errorLabel.frame = NSRect(x: 630, y: 62, width: 150, height: 40)
        errorLabel.textColor = .systemRed
        errorLabel.maximumNumberOfLines = 2
        root.addSubview(errorLabel)
        configureButton(cancelButton, action: #selector(cancel(_:)), frame: NSRect(x: 610, y: 18, width: 80, height: 32), parent: root)
        configureButton(saveButton, action: #selector(save(_:)), frame: NSRect(x: 698, y: 18, width: 102, height: 32), parent: root)
        saveButton.keyEquivalent = "\r"
    }

    private func configureButton(_ button: NSButton, action: Selector, frame: NSRect, parent: NSView) {
        button.target = self
        button.action = action
        button.frame = frame
        parent.addSubview(button)
    }

    private func refreshAll() {
        let intendedIndex = model.selectedIndex
        isRefreshingSelection = true
        tableView.reloadData()
        tableView.selectRowIndexes(IndexSet(integer: intendedIndex), byExtendingSelection: false)
        isRefreshingSelection = false
        model.selectedIndex = intendedIndex
        refreshEditor()
    }

    private func refreshEditor() {
        let profile = model.selectedProfile
        nameField.stringValue = profile.displayName
        switch profile.avatarSource {
        case let .builtIn(preset):
            avatarPopUp.item(at: 0)?.title = "当前头像"
            avatarPopUp.selectItem(at: preset.index + 1)
        case .imported:
            avatarPopUp.item(at: 0)?.title = "当前：本地导入头像"
            avatarPopUp.selectItem(at: 0)
        case .legacyBundled:
            avatarPopUp.item(at: 0)?.title = "当前：原头像"
            avatarPopUp.selectItem(at: 0)
        }
        bodyStylePopUp.selectItem(withTitle: profile.bodyStyle.displayName)
        outfitPopUp.selectItem(withTitle: profile.outfit.displayName)
        personalityPopUp.selectItem(withTitle: profile.personalityPreset.displayName)
        let values = [profile.personality.speed, profile.personality.curiosity, profile.personality.sociability, profile.personality.courage, profile.personality.sleepiness]
        zip(sliders, values).forEach { $0.0.doubleValue = $0.1 }
        refreshPreview()
        refreshButtons()
    }

    private func refreshPreview() {
        guard let manifest = CharacterRoster(version: 1, profiles: [model.selectedProfile]).manifests.first else { return }
        previewImageView.image = ProceduralPetRenderer.image(for: manifest, size: NSSize(width: 180, height: 160))
    }

    private func refreshButtons() {
        countLabel.stringValue = "\(model.draft.profiles.count)/8"
        addButton.isEnabled = model.canAdd
        deleteButton.isEnabled = model.canDelete
        moveUpButton.isEnabled = model.selectedIndex > 0
        moveDownButton.isEnabled = model.selectedIndex < model.draft.profiles.count - 1
    }

    @objc func addCharacter(_ sender: Any?) { if model.addCharacter() { refreshAll() } }
    @objc func deleteCharacter(_ sender: Any?) { if model.deleteSelectedCharacter() { refreshAll() } }
    @objc private func moveCharacterUp(_ sender: Any?) { if model.moveSelected(by: -1) { refreshAll() } }
    @objc private func moveCharacterDown(_ sender: Any?) { if model.moveSelected(by: 1) { refreshAll() } }

    @objc private func avatarChanged(_ sender: Any?) {
        let index = avatarPopUp.indexOfSelectedItem - 1
        guard BuiltInAvatarPreset.allCases.indices.contains(index) else { return }
        model.updateSelected { $0.avatarSource = .builtIn(BuiltInAvatarPreset.allCases[index]) }
        refreshPreview()
    }

    @objc private func bodyStyleChanged(_ sender: Any?) {
        let index = bodyStylePopUp.indexOfSelectedItem
        guard BodyStyle.allCases.indices.contains(index) else { return }
        model.updateSelected { $0.bodyStyle = BodyStyle.allCases[index] }
        refreshPreview()
    }

    @objc private func outfitChanged(_ sender: Any?) {
        let index = outfitPopUp.indexOfSelectedItem
        guard OutfitPreset.allCases.indices.contains(index) else { return }
        model.updateSelected { $0.outfit = OutfitPreset.allCases[index] }
        refreshPreview()
    }

    @objc func personalityChanged(_ sender: Any?) {
        let index = personalityPopUp.indexOfSelectedItem
        guard PersonalityPreset.allCases.indices.contains(index) else { return }
        model.applyPersonalityPreset(PersonalityPreset.allCases[index])
        refreshEditor()
    }

    @objc private func sliderChanged(_ sender: NSSlider) {
        model.updateSelected { profile in
            var values = [profile.personality.speed, profile.personality.curiosity, profile.personality.sociability, profile.personality.courage, profile.personality.sleepiness]
            values[sender.tag] = sender.doubleValue
            profile.personality = Personality(speed: values[0], curiosity: values[1], sociability: values[2], courage: values[3], sleepiness: values[4])
        }
    }

    @objc private func importAvatar(_ sender: Any?) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.message = "选择一张头像照片，应用会在本机裁切并保存副本。"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let crop = try AvatarCropWindowController(imageData: Data(contentsOf: url))
            crop.onUse = { [weak self] normalizedData in
                guard let self else { return }
                let filename = try self.onImportAvatar?(normalizedData)
                if let filename { self.model.updateSelected { $0.avatarSource = .imported(filename: filename) } }
                self.refreshEditor()
            }
            crop.runModal()
        } catch {
            errorLabel.stringValue = "头像导入失败：\(error.localizedDescription)"
        }
    }

    @objc func save(_ sender: Any?) {
        do {
            let roster = try model.validatedRoster()
            try onSave?(roster)
            model.acceptSavedRoster(roster)
            errorLabel.stringValue = ""
            close()
        } catch {
            errorLabel.stringValue = "无法保存：请检查名称和人物数量"
        }
    }

    @objc func cancel(_ sender: Any?) {
        model.cancelEdits()
        close()
    }
}
