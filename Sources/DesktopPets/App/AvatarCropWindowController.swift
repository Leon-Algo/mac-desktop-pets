import AppKit

@MainActor
final class AvatarCropWindowController: NSWindowController {
    let previewImageView = NSImageView()
    let zoomSlider = NSSlider(value: 1, minValue: 1, maxValue: 3, target: nil, action: nil)
    let horizontalSlider = NSSlider(value: 0, minValue: -1, maxValue: 1, target: nil, action: nil)
    let verticalSlider = NSSlider(value: 0, minValue: -1, maxValue: 1, target: nil, action: nil)
    let useButton = NSButton(title: "使用这个头像", target: nil, action: nil)
    let cancelButton = NSButton(title: "取消", target: nil, action: nil)
    private let sourceData: Data
    private let errorLabel = NSTextField(labelWithString: "")
    var onUse: ((Data) throws -> Void)?

    init(imageData: Data) throws {
        _ = try AvatarImageProcessor.normalizedPNG(from: imageData)
        sourceData = imageData
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 570),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "调整头像"
        window.isReleasedWhenClosed = false
        super.init(window: window)
        buildInterface()
        refreshPreview()
    }

    required init?(coder: NSCoder) { nil }

    func runModal() {
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        if let window { NSApp.runModal(for: window) }
    }

    private func buildInterface() {
        guard let root = window?.contentView else { return }
        let heading = NSTextField(labelWithString: "裁剪头像")
        heading.font = .systemFont(ofSize: 18, weight: .semibold)
        heading.frame = NSRect(x: 30, y: 525, width: 160, height: 26)
        root.addSubview(heading)

        let help = NSTextField(labelWithString: "调整缩放和位置，头像只会保存在这台 Mac 上。")
        help.textColor = .secondaryLabelColor
        help.frame = NSRect(x: 30, y: 500, width: 410, height: 20)
        root.addSubview(help)

        previewImageView.frame = NSRect(x: 90, y: 205, width: 300, height: 280)
        previewImageView.imageScaling = .scaleProportionallyUpOrDown
        previewImageView.wantsLayer = true
        previewImageView.layer?.cornerRadius = 14
        previewImageView.layer?.masksToBounds = true
        previewImageView.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        root.addSubview(previewImageView)

        configureSlider(zoomSlider, title: "缩放", y: 158, parent: root)
        configureSlider(horizontalSlider, title: "水平位置", y: 116, parent: root)
        configureSlider(verticalSlider, title: "垂直位置", y: 74, parent: root)
        [zoomSlider, horizontalSlider, verticalSlider].forEach {
            $0.target = self
            $0.action = #selector(sliderChanged(_:))
        }

        errorLabel.frame = NSRect(x: 30, y: 48, width: 250, height: 20)
        errorLabel.textColor = .systemRed
        root.addSubview(errorLabel)
        cancelButton.frame = NSRect(x: 278, y: 16, width: 80, height: 32)
        useButton.frame = NSRect(x: 366, y: 16, width: 98, height: 32)
        cancelButton.target = self; cancelButton.action = #selector(cancel(_:))
        useButton.target = self; useButton.action = #selector(useAvatar(_:)); useButton.keyEquivalent = "\r"
        root.addSubview(cancelButton)
        root.addSubview(useButton)
    }

    private func configureSlider(_ slider: NSSlider, title: String, y: CGFloat, parent: NSView) {
        let label = NSTextField(labelWithString: title)
        label.frame = NSRect(x: 30, y: y + 2, width: 72, height: 20)
        slider.frame = NSRect(x: 105, y: y, width: 335, height: 24)
        parent.addSubview(label)
        parent.addSubview(slider)
    }

    @objc private func sliderChanged(_ sender: Any?) { refreshPreview() }

    private func refreshPreview() {
        guard let data = try? renderedPNG() else { return }
        previewImageView.image = NSImage(data: data)
    }

    func renderedPNG() throws -> Data {
        try AvatarImageProcessor.normalizedPNG(
            from: sourceData,
            zoom: zoomSlider.doubleValue,
            offsetX: horizontalSlider.doubleValue,
            offsetY: verticalSlider.doubleValue
        )
    }

    @objc private func useAvatar(_ sender: Any?) {
        do {
            try onUse?(renderedPNG())
            finishModal()
        } catch {
            errorLabel.stringValue = "无法使用这张头像"
        }
    }

    @objc private func cancel(_ sender: Any?) { finishModal() }

    private func finishModal() {
        NSApp.stopModal()
        close()
    }
}
