import AppKit

@MainActor
final class PetWindowCoordinator {
    static let basePanelSize = CGSize(width: 180, height: 160)

    private var entries: [String: (panel: PetPanel, view: PetSpriteView)] = [:]
    private let orderedIdentifiers: [String]
    private var scalePreset = PetScalePreset.original

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

    func setScale(_ preset: PetScalePreset) {
        scalePreset = preset
        entries.values.forEach { $0.view.setRenderScale(CGFloat(preset.factor)) }
    }

    func apply(poses: [PetPose]) {
        let size = scalePreset.panelSize
        let groundOffset = 20 * scalePreset.factor
        for pose in poses {
            guard let entry = entries[pose.id] else { continue }
            let origin = CGPoint(
                x: pose.position.x - size.width / 2,
                y: pose.position.y - groundOffset
            )
            entry.panel.setFrame(NSRect(origin: origin, size: size), display: true)
            entry.view.setRenderScale(CGFloat(scalePreset.factor))
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

    func show(identifier: String) { entries[identifier]?.panel.orderFrontRegardless() }
    func hide(identifier: String) { entries[identifier]?.panel.orderOut(nil) }
}
