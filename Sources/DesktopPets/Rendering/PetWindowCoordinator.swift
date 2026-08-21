import AppKit

@MainActor
final class PetWindowCoordinator {
    static let basePanelSize = CGSize(width: 180, height: 160)

    private var entries: [String: (panel: PetPanel, view: PetSpriteView)] = [:]
    private let orderedIdentifiers: [String]
    private var scalePreset = PetScalePreset.original
    /// 已应用到各视图的缩放档位缓存，避免每帧（20fps）对所有宠物重复执行 setRenderScale。
    private var appliedScalePreset: PetScalePreset?

    init(characters: [CharacterManifest], interactionHandler: ((PetInteraction) -> Void)? = nil) {
        orderedIdentifiers = characters.map(\.id)
        for character in characters {
            let panel = PetPanel(identifier: character.id, size: Self.basePanelSize)
            let view = PetSpriteView(frame: NSRect(origin: .zero, size: Self.basePanelSize), character: character)
            view.interactionHandler = interactionHandler
            panel.contentView = view
            entries[character.id] = (panel, view)
        }
    }

    var panelIdentifiers: [String] { orderedIdentifiers }
    var allPanels: [PetPanel] { orderedIdentifiers.compactMap { entries[$0]?.panel } }

    func frame(for identifier: String) -> NSRect? { entries[identifier]?.panel.frame }
    var activeFeedbackCount: Int { entries.values.filter { $0.view.activeFeedbackText != nil }.count }

    func setScale(_ preset: PetScalePreset) {
        scalePreset = preset
        entries.values.forEach { $0.view.setRenderScale(CGFloat(preset.factor)) }
        appliedScalePreset = preset
    }

    func apply(poses: [PetPose]) {
        let size = scalePreset.panelSize
        let groundOffset = 20 * scalePreset.factor
        // 缩放档位未变化时不重复 setRenderScale：该方法内部会重设 frame、petLayer.bounds
        // 并重排反馈层，每帧对所有宠物重复调用属于纯空转开销。
        if appliedScalePreset != scalePreset {
            entries.values.forEach { $0.view.setRenderScale(CGFloat(scalePreset.factor)) }
            appliedScalePreset = scalePreset
        }
        for pose in poses {
            guard let entry = entries[pose.id] else { continue }
            let origin = CGPoint(
                x: pose.position.x - size.width / 2,
                y: pose.position.y - groundOffset
            )
            entry.panel.setFrame(NSRect(origin: origin, size: size), display: true)
            entry.view.apply(pose)
        }
    }

    func setClickThrough(_ enabled: Bool) {
        allPanels.forEach { $0.ignoresMouseEvents = enabled }
    }

    func updateMouseAcceptance(at screenPoint: CGPoint, fullyClickThrough: Bool) {
        for identifier in orderedIdentifiers {
            guard let entry = entries[identifier] else { continue }
            if entry.view.isDraggingPet {
                entry.panel.ignoresMouseEvents = false
                continue
            }
            guard !fullyClickThrough, entry.panel.isVisible else {
                entry.panel.ignoresMouseEvents = true
                continue
            }
            let windowPoint = entry.panel.convertPoint(fromScreen: screenPoint)
            entry.panel.ignoresMouseEvents = !entry.view.containsVisiblePet(at: windowPoint)
        }
    }

    func show() {
        allPanels.forEach { $0.orderFrontRegardless() }
    }

    func hide() {
        allPanels.forEach { $0.orderOut(nil) }
    }

    /// 关闭并断开所有宠物面板与窗口服务器的关联。在 WorldRunner 被替换或退出时调用，
    /// 避免面板仅 orderOut 而不 close 导致被窗口服务器持有、成为孤儿窗口而泄漏。
    func closeAll() {
        allPanels.forEach { $0.close() }
    }

    func show(identifier: String) { entries[identifier]?.panel.orderFrontRegardless() }
    func hide(identifier: String) { entries[identifier]?.panel.orderOut(nil) }

    func showFeedback(for identifier: String, message: String, duration: Double) {
        entries[identifier]?.view.showFeedback(message: message, duration: duration)
    }

    func feedback(for identifier: String) -> String? {
        entries[identifier]?.view.activeFeedbackText
    }
}
