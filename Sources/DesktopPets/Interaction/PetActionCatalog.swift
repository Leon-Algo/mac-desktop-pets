import Foundation

enum PetActionID: String, Codable, CaseIterable, Hashable, Sendable {
    case wave
    case hop
    case roll
    case sleep
    case gatherPlay
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
            id: .sleep,
            scope: .individual,
            title: "💤 趴下睡觉",
            explanation: "在当前位置趴下休息约 4 秒",
            feedback: "先睡一会儿…",
            duration: 4
        ),
    ]

    static let group = [
        PetActionDefinition(
            id: .gatherPlay,
            scope: .group,
            title: "🎉 四人集合玩耍",
            explanation: "把四个人召集到一起玩耍",
            feedback: "集合玩耍！",
            duration: 2
        ),
    ]

    static let all = individual + group

    static func definition(for id: PetActionID) -> PetActionDefinition? {
        all.first { $0.id == id }
    }
}
