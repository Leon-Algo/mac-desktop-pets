import AppKit
import OSLog

@MainActor
final class ControlCenterPanelController: NSObject {
    static let panelSize = NSSize(width: 96, height: 38)

    let panel: NSPanel
    let button: NSButton
    private let menu: NSMenu
    private let logger = Logger(subsystem: "com.codex.DesktopPets", category: "ControlCenter")

    var isVisible: Bool { panel.isVisible }

    init(menu: NSMenu) {
        self.menu = menu
        panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: Self.panelSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        button = NSButton(title: L10n.localized("panel.buttonTitle", fallback: "🐾 总台"), target: nil, action: nil)
        super.init()

        panel.identifier = NSUserInterfaceItemIdentifier("desktop-pets-control-center")
        panel.title = L10n.localized("menu.controlCenterTitle", fallback: "桌面伙伴总台")
        panel.setAccessibilityLabel(L10n.localized("menu.controlCenterTitle", fallback: "桌面伙伴总台"))
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.isMovable = false
        panel.isReleasedWhenClosed = false
        panel.animationBehavior = .none

        let material = NSVisualEffectView(frame: NSRect(origin: .zero, size: Self.panelSize))
        material.material = .hudWindow
        material.blendingMode = .behindWindow
        material.state = .active
        material.wantsLayer = true
        material.layer?.cornerRadius = 11
        material.layer?.masksToBounds = true

        button.frame = NSRect(x: 5, y: 4, width: 86, height: 30)
        button.bezelStyle = .rounded
        button.font = .systemFont(ofSize: 13, weight: .semibold)
        button.target = self
        button.action = #selector(openMenu(_:))
        button.toolTip = ControlHintPolicy.guidance
        button.setAccessibilityLabel(L10n.localized("menu.controlCenterTitle", fallback: "桌面伙伴总台"))
        material.addSubview(button)
        panel.contentView = material
        reposition(on: NSScreen.main)
    }

    static func frame(in visibleFrame: NSRect) -> NSRect {
        NSRect(
            x: visibleFrame.maxX - panelSize.width - 16,
            y: visibleFrame.maxY - panelSize.height - 16,
            width: panelSize.width,
            height: panelSize.height
        )
    }

    func reposition(on screen: NSScreen?) {
        guard let visibleFrame = screen?.visibleFrame else { return }
        panel.setFrame(Self.frame(in: visibleFrame), display: true)
    }

    func repositionOnCurrentScreen() {
        reposition(on: NSScreen.main ?? NSScreen.screens.first)
    }

    func show(openingMenu: Bool = false) {
        reposition(on: NSScreen.main)
        panel.orderFrontRegardless()
        logger.info("Fallback control center shown")
        if openingMenu {
            DispatchQueue.main.async { [weak self] in self?.presentMenu() }
        }
    }

    func hide() {
        panel.orderOut(nil)
        logger.info("Fallback control center hidden")
    }

    func toggle() {
        isVisible ? hide() : show()
    }

    func presentMenu() {
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.minY), in: button)
    }

    @objc private func openMenu(_ sender: Any?) {
        logger.info("Fallback control menu opened")
        presentMenu()
    }
}
