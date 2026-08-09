import Foundation

enum PetActionID: String, Codable, CaseIterable, Hashable, Sendable {
    case wave
    case hop
    case roll
    case callDad
    case groupCallDad
}

enum PetActionScope: String, Codable, Sendable {
    case individual
    case group
}

struct PetActionDefinition: Equatable, Sendable {
    let id: PetActionID
    let scope: PetActionScope
    let title: String
    let explanation: String
    let feedback: String
    let duration: Double
}

struct PetActionRequest: Equatable, Sendable {
    let actionID: PetActionID
    let targetID: String?
}

enum PetActionOutcome: Equatable, Sendable {
    case performed(affectedIDs: [String], feedback: String, duration: Double)
    case unavailable(targetID: String?, feedback: String, duration: Double)
}

enum PetActionCatalog {
    static let individual = [
        PetActionDefinition(
            id: .wave,
            scope: .individual,
            title: "👋 打个招呼",
            explanation: "面向你摇摆着打招呼，持续约 2 秒",
            feedback: "嗨！",
            duration: 1.8
        ),
        PetActionDefinition(
            id: .hop,
            scope: .individual,
            title: "⬆️ 原地跳一下",
            explanation: "从当前位置向上跳起一次",
            feedback: "看我跳！",
            duration: 1.4
        ),
        PetActionDefinition(
            id: .roll,
            scope: .individual,
            title: "🙈 翻个跟头",
            explanation: "原地完成一次夸张的猴式翻滚",
            feedback: "翻个跟头！",
            duration: 1.4
        ),
        PetActionDefinition(
            id: .callDad,
            scope: .individual,
            title: "📣 叫爸爸",
            explanation: "原地弹跳并喊一声爸爸",
            feedback: "爸爸！",
            duration: 1.8
        ),
    ]

    static let group = [
        PetActionDefinition(
            id: .groupCallDad,
            scope: .group,
            title: "📣 全部人物一起喊爸爸",
            explanation: "召回全部人物，集合后一起喊爸爸",
            feedback: "爸爸！",
            duration: 2
        ),
    ]

    static let all = individual + group

    static func definition(for id: PetActionID) -> PetActionDefinition? {
        all.first { $0.id == id }
    }
}
