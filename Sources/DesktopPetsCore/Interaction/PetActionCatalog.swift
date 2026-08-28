import Foundation

public enum PetActionID: String, Codable, CaseIterable, Hashable, Sendable {
    case wave
    case hop
    case roll
    case callDad
    case groupCallDad
}

public enum PetActionScope: String, Codable, Sendable {
    case individual
    case group
}

public struct PetActionDefinition: Equatable, Sendable {
    public let id: PetActionID
    public let scope: PetActionScope
    public let title: String
    public let explanation: String
    public let feedback: String
    public let duration: Double
}

public struct PetActionRequest: Equatable, Sendable {
    public let actionID: PetActionID
    public let targetID: String?

    public init(actionID: PetActionID, targetID: String?) {
        self.actionID = actionID
        self.targetID = targetID
    }
}

public enum PetActionOutcome: Equatable, Sendable {
    case performed(affectedIDs: [String], feedback: String, duration: Double)
    case unavailable(targetID: String?, feedback: String, duration: Double)
}

public enum PetActionCatalog {
    public static let individual = [
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

    public static let group = [
        PetActionDefinition(
            id: .groupCallDad,
            scope: .group,
            title: "📣 全部人物一起喊爸爸",
            explanation: "召回全部人物，集合后一起喊爸爸",
            feedback: "爸爸！",
            duration: 2
        ),
    ]

    public static let all = individual + group

    public static func definition(for id: PetActionID) -> PetActionDefinition? {
        all.first { $0.id == id }
    }
}
