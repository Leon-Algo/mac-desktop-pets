import Foundation

struct PetWorld: Sendable {
    private(set) var agents: [PetAgent]
    private var random: SeededRandom
    private var paused = false

    init(characters: [CharacterManifest], display: WorldRect, seed: UInt64) {
        let spacing = min(180, display.width / Double(max(characters.count + 1, 1)))
        agents = characters.enumerated().map { index, character in
            PetAgent(
                id: character.id,
                personality: character.personality,
                position: WorldPoint(x: display.minX + spacing * Double(index + 1), y: display.minY),
                facing: index.isMultiple(of: 2) ? .right : .left,
                supportID: "screen-floor-\(display.x)-\(display.y)"
            )
        }
        random = SeededRandom(seed: seed)
    }

    init(agents: [PetAgent], seed: UInt64) {
        self.agents = agents
        random = SeededRandom(seed: seed)
    }

    var poses: [PetPose] { agents.map(\.pose) }

    mutating func setPaused(_ value: Bool) {
        paused = value
    }

    mutating func recall(to display: WorldRect) {
        let spacing = display.width / Double(max(agents.count + 1, 1))
        for index in agents.indices {
            agents[index].position = WorldPoint(x: display.minX + spacing * Double(index + 1), y: display.minY)
            agents[index].velocity = WorldVector(dx: 0, dy: 0)
            agents[index].state = .crawl
            agents[index].stateTime = 0
            agents[index].supportID = "screen-floor-\(display.x)-\(display.y)"
        }
    }

    mutating func step(deltaTime: Double, obstacles: ObstacleMap) {
        guard !paused, deltaTime.isFinite, deltaTime > 0, !obstacles.displays.isEmpty else { return }
        var remaining = min(deltaTime, 1)
        while remaining > 0 {
            let dt = min(remaining, 1.0 / 60.0)
            substep(dt: dt, obstacles: obstacles)
            remaining -= dt
        }
    }

    private mutating func substep(dt: Double, obstacles: ObstacleMap) {
        for index in agents.indices {
            agents[index].stateTime += dt
            switch agents[index].state {
            case .crawl, .chase:
                updateCrawling(index: index, dt: dt, obstacles: obstacles)
            case .fall, .jump:
                updateAirborne(index: index, dt: dt, obstacles: obstacles)
            case .climb:
                updateClimbing(index: index, dt: dt, obstacles: obstacles)
            case .turn:
                if agents[index].stateTime >= 0.35 { transition(index, to: .crawl) }
            case .idle, .greet, .play:
                if agents[index].stateTime >= 1.2 + agents[index].personality.curiosity {
                    transition(index, to: .crawl)
                }
            case .hang:
                if agents[index].stateTime >= 1.5 { transition(index, to: .fall) }
            case .sleep:
                if agents[index].stateTime >= 3.0 + agents[index].personality.sleepiness * 4 {
                    transition(index, to: .idle)
                }
            }

            if !agents[index].position.isFinite {
                agents[index].position = obstacles.clamped(WorldPoint(x: 0, y: 0), margin: 1)
                transition(index, to: .fall)
            } else {
                let previousX = agents[index].position.x
                let clamped = obstacles.clamped(agents[index].position, margin: 0)
                if clamped != agents[index].position {
                    agents[index].position = clamped
                    if clamped.x != previousX {
                        agents[index].facing = agents[index].facing == .right ? .left : .right
                    }
                }
            }
        }
        triggerPairInteractions()
    }

    private mutating func updateCrawling(index: Int, dt: Double, obstacles: ObstacleMap) {
        let speed = 55 + agents[index].personality.speed * 80
        agents[index].position.x += Double(agents[index].facing.rawValue) * speed * dt

        let probe = WorldPoint(x: agents[index].position.x, y: agents[index].position.y + 2)
        if let support = obstacles.supportingSurface(below: probe, within: 4) {
            agents[index].position.y = support.y
            agents[index].supportID = support.obstacleID
        } else {
            transition(index, to: .fall)
            agents[index].velocity = WorldVector(dx: Double(agents[index].facing.rawValue) * speed * 0.55, dy: 0)
            return
        }

        if agents[index].stateTime > 4 {
            let roll = random.nextDouble()
            if roll < 0.08 + agents[index].personality.sleepiness * 0.08 {
                transition(index, to: .sleep)
            } else if roll < 0.22 {
                transition(index, to: .idle)
            } else if roll < 0.30 + agents[index].personality.courage * 0.08 {
                transition(index, to: .jump)
                agents[index].velocity = WorldVector(dx: Double(agents[index].facing.rawValue) * speed, dy: 240)
            } else if let edge = obstacles.nearestClimbableEdge(to: agents[index].position, within: 18), random.nextDouble() < agents[index].personality.courage {
                agents[index].position.x = edge.x
                agents[index].supportID = edge.obstacleID
                transition(index, to: .climb)
            } else {
                agents[index].facing = agents[index].facing == .right ? .left : .right
                transition(index, to: .turn)
            }
        }
    }

    private mutating func updateAirborne(index: Int, dt: Double, obstacles: ObstacleMap) {
        let previous = agents[index].position
        agents[index].position.x += agents[index].velocity.dx * dt
        agents[index].position.y += agents[index].velocity.dy * dt
        agents[index].velocity.dy -= 620 * dt
        if agents[index].velocity.dy <= 0 { agents[index].state = .fall }

        let maximumDrop = max(0, previous.y - agents[index].position.y) + 2
        if let surface = obstacles.supportingSurface(below: previous, within: maximumDrop),
           agents[index].position.y <= surface.y {
            agents[index].position.y = surface.y
            agents[index].velocity = WorldVector(dx: 0, dy: 0)
            agents[index].supportID = surface.obstacleID
            transition(index, to: .crawl)
        }
    }

    private mutating func updateClimbing(index: Int, dt: Double, obstacles: ObstacleMap) {
        agents[index].position.y += (42 + agents[index].personality.speed * 48) * dt
        guard let edge = obstacles.nearestClimbableEdge(to: agents[index].position, within: 3) else {
            transition(index, to: .fall)
            return
        }
        agents[index].position.x = edge.x
        if agents[index].position.y >= edge.maxY {
            agents[index].position.y = edge.maxY
            agents[index].position.x += edge.side == .left ? 8 : -8
            transition(index, to: .crawl)
        }
    }

    private mutating func triggerPairInteractions() {
        guard agents.count > 1 else { return }
        for first in 0..<(agents.count - 1) {
            for second in (first + 1)..<agents.count {
                let dx = agents[first].position.x - agents[second].position.x
                let dy = agents[first].position.y - agents[second].position.y
                let near = dx * dx + dy * dy < 70 * 70
                let ready = agents[first].stateTime > 2 && agents[second].stateTime > 2
                guard near, ready, agents[first].state == .crawl, agents[second].state == .crawl else { continue }
                let sociability = (agents[first].personality.sociability + agents[second].personality.sociability) / 2
                if random.nextDouble() < sociability * 0.12 {
                    transition(first, to: .play)
                    transition(second, to: .greet)
                }
            }
        }
    }

    private mutating func transition(_ index: Int, to state: PetState) {
        agents[index].state = state
        agents[index].stateTime = 0
        if state != .crawl { agents[index].supportID = state == .climb ? agents[index].supportID : nil }
    }
}
