import AppKit

@MainActor
final class PetWindowCoordinator {
    static let panelSize = CGSize(width: 180, height: 160)

    private var entries: [String: (panel: PetPanel, view: PetSpriteView)] = [:]
    private let orderedIdentifiers: [String]

    init(characters: [CharacterManifest]) {
        orderedIdentifiers = characters.map(\.id)
        for character in characters {
            let panel = PetPanel(identifier: character.id, size: Self.panelSize)
            let view = PetSpriteView(frame: NSRect(origin: .zero, size: Self.panelSize), character: character)
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

    func show() {
        allPanels.forEach { $0.orderFrontRegardless() }
    }

    func hide() {
        allPanels.forEach { $0.orderOut(nil) }
    }
}
