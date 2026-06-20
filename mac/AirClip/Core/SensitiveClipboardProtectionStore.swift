import Combine
import Foundation

@MainActor
final class SensitiveClipboardProtectionStore: ObservableObject {
    static let shared = SensitiveClipboardProtectionStore()

    @Published private(set) var masterAction: SensitiveRuleAction
    @Published private(set) var rules: [SensitiveCategory: SensitiveRuleAction]
    private let defaults: UserDefaults
    private static let masterRuleKey = "sensitiveClipboardRule.master"

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.masterAction = SensitiveRuleAction.fromStoredValue(
            defaults.string(forKey: Self.masterRuleKey)
        )
        self.rules = Dictionary(uniqueKeysWithValues: SensitiveCategory.allCases.map {
            ($0, SensitiveRuleAction.fromStoredValue(
                defaults.string(forKey: Self.ruleKey(for: $0))
            ))
        })
    }

    func action(for category: SensitiveCategory) -> SensitiveRuleAction {
        guard masterAction != .allow else { return .allow }
        return rules[category] ?? .ask
    }

    func setMasterAction(_ action: SensitiveRuleAction) {
        defaults.set(action.rawValue, forKey: Self.masterRuleKey)
        masterAction = action
    }

    func setAction(_ action: SensitiveRuleAction, for category: SensitiveCategory) {
        defaults.set(action.rawValue, forKey: Self.ruleKey(for: category))
        rules[category] = action
    }

    func allowsAutomaticSend(_ packet: ClipboardPacket) -> Bool {
        let assessment = SensitiveClipboardClassifier.classify(packet.text)
        guard let finding = assessment.primaryFinding else {
            return true
        }
        let decision = SensitiveClipboardPolicy.decide(
            assessment,
            intent: .automatic,
            action: action(for: finding.category)
        )
        return decision != .block
    }

    func requestManualSend(_ packet: ClipboardPacket) -> SensitiveSendDecision {
        let assessment = SensitiveClipboardClassifier.classify(packet.text)
        guard let finding = assessment.primaryFinding else { return .allow }
        let decision = SensitiveClipboardPolicy.decide(
            assessment,
            intent: .manual,
            action: action(for: finding.category)
        )
        return decision
    }

    private static func ruleKey(for category: SensitiveCategory) -> String {
        "sensitiveClipboardRule.\(category.rawValue)"
    }
}
