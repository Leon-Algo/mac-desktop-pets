import AppKit

@MainActor
final class PetWindowCoordinator {
    static let panelSize = CGSize(width: 180, height: 160)

    private var entries: [String: (panel: PetPanel, view: PetSpriteView)] = [:]
    private let orderedIdentifiers: [String]

    init(characters: [CharacterManifest], interactionHandler: ((PetInteraction) -> Void)? = nil) {
        orderedIdentifiers = characters.map(\.id)
        for character in characters {
            let panel = PetPanel(identifier: character.id, size: Self.panelSize)
            let view = PetSpriteView(frame: NSRect(origin: .zero, size: Self.panelSize), character: character)
            view.interactionHandler = interactionHandler
            panel.contentView = view
            entries[character.id] = (panel, view)
        }
    }

    var panelIdentifiers: [String] { orderedIdentifiers }
    var allPanels: [PetPanel] { orderedIdentifiers.compactMap { entries[$0]?.panel } }

    func frame(for identifier: String) -> NSRect? { entries[identifier]?.panel.frame }

    func apply(poses: [PetPose]) {
        for pose in poses {
            guard let entry = entries[pose.id] else { continue }
            let origin = CGPoint(
                x: pose.position.x - Self.panelSize.width / 2,
                y: pose.position.y - 20
            )
            entry.panel.setFrame(NSRect(origin: origin, size: Self.panelSize), display: true)
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
