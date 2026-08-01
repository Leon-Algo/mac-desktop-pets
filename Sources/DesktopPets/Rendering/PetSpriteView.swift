import AppKit
import QuartzCore

@MainActor
final class PetSpriteView: NSView {
    static let requiresDisplayLink = false
    private let petLayer = CALayer()

    init(frame frameRect: NSRect, character: CharacterManifest) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        let image = ProceduralPetRenderer.image(for: character, size: frameRect.size)
        var proposed = NSRect(origin: .zero, size: image.size)
        petLayer.contents = image.cgImage(forProposedRect: &proposed, context: nil, hints: nil)
        petLayer.contentsGravity = .resizeAspect
        petLayer.contentsScale = NSScreen.main?.backingScaleFactor ?? 2
        petLayer.bounds = CGRect(origin: .zero, size: frameRect.size)
        petLayer.anchorPoint = CGPoint(x: 0.5, y: 0.12)
        petLayer.position = CGPoint(x: frameRect.width / 2, y: 20)
        layer?.addSublayer(petLayer)
    }

    required init?(coder: NSCoder) {
        nil
    }

    func apply(_ pose: PetPose) {
        let direction = pose.facing == .right ? 1.0 : -1.0
        let stride = sin(pose.phase * .pi * 2)
        var angle = stride * 0.025
        var opacity: Float = 1
        switch pose.state {
        case .climb, .hang: angle = direction * -.pi / 2
        case .jump: angle = direction * 0.12
        case .fall: angle = direction * -0.12
        case .sleep: angle = direction * -0.05; opacity = 0.88
        case .play, .greet: angle = stride * 0.08
        default: break
        }
        let transform = CGAffineTransform(
            scaleX: direction * (1 + abs(stride) * 0.025),
            y: 1 - abs(stride) * 0.035
        ).rotated(by: angle)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        petLayer.setAffineTransform(transform)
        petLayer.position = CGPoint(x: bounds.midX, y: 20 + max(0, stride) * 4)
        petLayer.opacity = opacity
        CATransaction.commit()
    }
}
