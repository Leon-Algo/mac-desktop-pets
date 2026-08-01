import AppKit
import SpriteKit

@MainActor
final class ProceduralPetNode: SKSpriteNode {
    private let baseSize: CGSize

    init(character: CharacterManifest, size: CGSize) {
        baseSize = size
        let image = ProceduralPetRenderer.image(for: character, size: size)
        super.init(texture: SKTexture(image: image), color: .clear, size: size)
        anchorPoint = CGPoint(x: 0.5, y: 0.12)
    }

    required init?(coder aDecoder: NSCoder) {
        nil
    }

    func apply(_ pose: PetPose) {
        let direction = pose.facing == .right ? 1.0 : -1.0
        let stride = sin(pose.phase * .pi * 2)
        xScale = direction * (1 + abs(stride) * 0.025)
        yScale = 1 - abs(stride) * 0.035
        position = CGPoint(x: baseSize.width / 2, y: 20 + max(0, stride) * 4)
        switch pose.state {
        case .climb, .hang:
            zRotation = direction * -.pi / 2
        case .jump:
            zRotation = direction * 0.12
        case .fall:
            zRotation = direction * -0.12
        case .sleep:
            zRotation = direction * -0.05
            alpha = 0.88
        case .play, .greet:
            zRotation = stride * 0.08
            alpha = 1
        default:
            zRotation = stride * 0.025
            alpha = 1
        }
    }
}
