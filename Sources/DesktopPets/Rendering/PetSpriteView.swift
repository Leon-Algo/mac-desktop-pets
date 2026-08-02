import AppKit
import QuartzCore

@MainActor
final class PetSpriteView: NSView {
    static let requiresDisplayLink = false
    let petIdentifier: String
    var interactionHandler: ((PetInteraction) -> Void)?
    private(set) var isDraggingPet = false
    private let petLayer = CALayer()
    private let alphaMask: PetAlphaMask
    private var clickInterpreter = ClickInterpreter()
    private var pendingSingleClick: DispatchWorkItem?

    init(frame frameRect: NSRect, character: CharacterManifest) {
        petIdentifier = character.id
        let image = ProceduralPetRenderer.image(for: character, size: frameRect.size)
        alphaMask = PetAlphaMask(image: image)
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
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

    func containsVisiblePet(at point: CGPoint) -> Bool {
        guard let rootLayer = layer else { return false }
        let local = petLayer.convert(point, from: rootLayer)
        guard petLayer.bounds.width > 0, petLayer.bounds.height > 0 else { return false }
        return alphaMask.containsOpaquePixel(
            normalizedPoint: CGPoint(
                x: local.x / petLayer.bounds.width,
                y: local.y / petLayer.bounds.height
            )
        )
    }

    override func mouseDown(with event: NSEvent) {
        switch clickInterpreter.register(clickCount: event.clickCount) {
        case let .scheduleSingle(token):
            pendingSingleClick?.cancel()
            let work = DispatchWorkItem { [weak self] in
                guard let self, self.clickInterpreter.resolveSingle(token: token) else { return }
                self.interactionHandler?(.react(id: self.petIdentifier))
            }
            pendingSingleClick = work
            DispatchQueue.main.asyncAfter(deadline: .now() + NSEvent.doubleClickInterval, execute: work)
        case .emitDouble:
            pendingSingleClick?.cancel()
            pendingSingleClick = nil
            interactionHandler?(.gatherAndPlay(leaderID: petIdentifier))
        case .ignore:
            break
        }
    }

    override func mouseDragged(with event: NSEvent) {
        pendingSingleClick?.cancel()
        pendingSingleClick = nil
        clickInterpreter.cancelPendingSingle()
        let position = screenPosition(for: event)
        if isDraggingPet {
            interactionHandler?(.drag(id: petIdentifier, position: position))
        } else {
            isDraggingPet = true
            interactionHandler?(.beginDrag(id: petIdentifier, position: position))
        }
    }

    override func mouseUp(with event: NSEvent) {
        guard isDraggingPet else { return }
        isDraggingPet = false
        interactionHandler?(.release(id: petIdentifier, position: screenPosition(for: event)))
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = NSMenu(title: "人物操作")
        addMenuItem("做个动作", action: #selector(reactFromMenu(_:)), to: menu)
        addMenuItem("暂停/继续这个人", action: #selector(togglePauseFromMenu(_:)), to: menu)
        addMenuItem("召回这个人", action: #selector(recallFromMenu(_:)), to: menu)
        menu.addItem(.separator())
        addMenuItem("隐藏这个人", action: #selector(hideFromMenu(_:)), to: menu)
        return menu
    }

    @objc private func reactFromMenu(_ sender: Any?) { interactionHandler?(.react(id: petIdentifier)) }
    @objc private func togglePauseFromMenu(_ sender: Any?) { interactionHandler?(.togglePause(id: petIdentifier)) }
    @objc private func recallFromMenu(_ sender: Any?) { interactionHandler?(.recall(id: petIdentifier)) }
    @objc private func hideFromMenu(_ sender: Any?) { interactionHandler?(.hide(id: petIdentifier)) }

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

    private func screenPosition(for event: NSEvent) -> WorldPoint {
        guard let window else { return WorldPoint(x: event.locationInWindow.x, y: event.locationInWindow.y) }
        let point = window.convertPoint(toScreen: event.locationInWindow)
        return WorldPoint(x: point.x, y: point.y)
    }

    private func addMenuItem(_ title: String, action: Selector, to menu: NSMenu) {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        menu.addItem(item)
    }
}
