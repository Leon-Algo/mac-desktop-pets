import AppKit
import SpriteKit

@MainActor
final class PetSpriteView: SKView {
    private let petNode: ProceduralPetNode

    init(frame frameRect: NSRect, character: CharacterManifest) {
        petNode = ProceduralPetNode(character: character, size: frameRect.size)
        super.init(frame: frameRect)
        allowsTransparency = true
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        let scene = SKScene(size: frameRect.size)
        scene.scaleMode = .resizeFill
        scene.backgroundColor = .clear
        scene.addChild(petNode)
        petNode.position = CGPoint(x: frameRect.width / 2, y: 20)
        presentScene(scene)
    }

    required init?(coder: NSCoder) {
        nil
    }

    func apply(_ pose: PetPose) {
        petNode.apply(pose)
    }
}
