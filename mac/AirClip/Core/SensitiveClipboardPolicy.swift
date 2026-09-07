import Foundation

enum SensitiveCategory: String, CaseIterable {
    case password
    case apiToken
    case privateKey
    case seedPhrase
    case paymentCard
    case oneTimeCode

    var label: String {
        switch self {
        case .password: return "Password"
        case .apiToken: return "API key or token"
        case .privateKey: return "Private key"
        case .seedPhrase: return "Recovery phrase"
        case .paymentCard: return "Payment card"
        case .oneTimeCode: return "One-time code"
        }
    }
}

enum SensitiveConfidence {
    case medium
    case high
}

struct SensitiveFinding: Equatable {
    let category: SensitiveCategory
    let confidence: SensitiveConfidence
    let reason: String
}

struct SensitiveAssessment: Equatable {
    let findings: [SensitiveFinding]

    var isSensitive: Bool { !findings.isEmpty }
    var primaryFinding: SensitiveFinding? { findings.first }
}

enum SensitiveSendIntent {
    case automatic
    case manual
}

enum SensitiveSendDecision {
    case allow
    case block
    case requireConfirmation
}

enum SensitiveRuleAction: String, CaseIterable {
    case allow
    case ask
    case alwaysBlock

    var label: String {
        switch self {
        case .alwaysBlock: return "Block"
        case .ask: return "Ask"
        case .allow: return "Allow"
        }
    }

    static func fromStoredValue(_ value: String?) -> SensitiveRuleAction {
        value.flatMap(SensitiveRuleAction.init(rawValue:)) ?? .allow
    }
}

enum SensitiveClipboardPolicy {
    static func decide(
        _ assessment: SensitiveAssessment,
        intent: SensitiveSendIntent,
        action: SensitiveRuleAction = .ask
    ) -> SensitiveSendDecision {
        guard assessment.isSensitive else { return .allow }
        switch action {
        case .alwaysBlock:
            return .block
        case .allow:
            return .allow
        case .ask:
            switch intent {
            case .automatic: return .block
            case .manual: return .requireConfirmation
            }
        }
    }
}

enum SensitiveClipboardClassifier {
    private static let privateKeyPattern =
        #"-----BEGIN (?:[A-Z0-9 ]+ )?PRIVATE KEY-----"#
    private static let knownTokenPatterns = [
        #"\bsk-(?:proj-)?[A-Za-z0-9_-]{20,}\b"#,
        #"\bgh[pousr]_[A-Za-z0-9]{20,}\b"#,
        #"\bAKIA[0-9A-Z]{16}\b"#,
        #"\beyJ[A-Za-z0-9_-]{5,}\.eyJ[A-Za-z0-9_-]{5,}\.[A-Za-z0-9_-]{8,}\b"#,
        #"\bBearer\s+[A-Za-z0-9._~+/-]{16,}=*\b"#,
        #"\bxox[baprs]-[A-Za-z0-9-]{20,}\b"#,
        #"\bnpm_[A-Za-z0-9]{20,}\b"#,
        #"\bpypi-[A-Za-z0-9_-]{20,}\b"#,
        #"\bAIza[0-9A-Za-z_-]{30,}\b"#,
        #"\bsk_live_[A-Za-z0-9]{16,}\b"#
    ]
    private static let assignedSecretPattern =
        #"\b(api[_-]?key|access[_-]?token|auth[_-]?token|client[_-]?secret|secret[_-]?key)\b\s*[:=]\s*["']?([A-Za-z0-9._~+/-]{8,}=*)"#
    private static let contextualPasswordPattern =
        #"\b(password|passwd|pwd|passcode)\b\s*[:=]\s*["']?(\S{4,})"#
    private static let otpPattern =
        #"\b(otp|one[- ]time|verification|security|login|authentication)\b[^\n\d]{0,32}\b(\d{4,8})\b"#
    private static let seedContextPattern =
        #"\b(seed|recovery|mnemonic)\s+(phrase|words?)\b"#
    private static let bip39SampleWords: Set<String> = [
        "abandon", "ability", "able", "about", "above", "absent", "absorb", "abstract",
        "absurd", "abuse", "access", "accident", "account", "accuse", "achieve", "acid",
        "acoustic", "acquire", "across", "act", "action", "actor", "actress", "actual",
        "adapt", "add", "addict", "address", "adjust", "admit", "adult", "advance"
    ]

    static func classify(_ text: String) -> SensitiveAssessment {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return SensitiveAssessment(findings: []) }
        guard !looksLikeFilePath(value) else { return SensitiveAssessment(findings: []) }

        let findings = [
            privateKeyFinding(value),
            tokenFinding(value),
            seedPhraseFinding(value),
            paymentCardFinding(value),
            contextualPasswordFinding(value),
            otpFinding(value),
            passwordLikeFinding(value)
        ].compactMap { $0 }

        var seen = Set<SensitiveCategory>()
        return SensitiveAssessment(findings: findings.filter { seen.insert($0.category).inserted })
    }

    private static func looksLikeFilePath(_ text: String) -> Bool {
        guard !text.contains(where: \.isNewline) else { return false }
        let lowercased = text.lowercased()
        if lowercased.hasPrefix("file://") { return true }
        if lowercased.hasPrefix("/") || lowercased.hasPrefix("~/") { return true }
        if matches(#"^[a-zA-Z]:[\\/]"#, in: text) { return true }
        if lowercased.contains("/") {
            let pathExtensions = [
                ".app", ".css", ".csv", ".doc", ".docx", ".gif", ".heic", ".html",
                ".jpeg", ".jpg", ".js", ".json", ".md", ".mov", ".mp4", ".pdf",
                ".png", ".py", ".rtf", ".svg", ".swift", ".txt", ".ts", ".tsx",
                ".webp", ".xls", ".xlsx", ".zip"
            ]
            return pathExtensions.contains { lowercased.hasSuffix($0) }
        }
        return false
    }

    private static func privateKeyFinding(_ text: String) -> SensitiveFinding? {
        guard matches(privateKeyPattern, in: text, caseInsensitive: true) else { return nil }
        return SensitiveFinding(
            category: .privateKey,
            confidence: .high,
            reason: "Private-key header detected"
        )
    }

    private static func tokenFinding(_ text: String) -> SensitiveFinding? {
        if knownTokenPatterns.contains(where: {
            matches($0, in: text, caseInsensitive: $0.contains("Bearer"))
        }) {
            return SensitiveFinding(
                category: .apiToken,
                confidence: .high,
                reason: "Recognized token format"
            )
        }
        guard matches(assignedSecretPattern, in: text, caseInsensitive: true) else { return nil }
        return SensitiveFinding(
            category: .apiToken,
            confidence: .high,
            reason: "Secret field with a credential-like value"
        )
    }

    private static func seedPhraseFinding(_ text: String) -> SensitiveFinding? {
        let words = text
            .lowercased()
            .components(separatedBy: CharacterSet.letters.inverted)
            .filter { !$0.isEmpty }
        let validLengths = [12, 15, 18, 21, 24]
        let hasContext = matches(seedContextPattern, in: text, caseInsensitive: true)
        let candidateWords = hasContext && validLengths.contains(words.count - 2)
            ? Array(words.dropFirst(2))
            : words
        guard validLengths.contains(candidateWords.count) else { return nil }
        let knownWords = candidateWords.filter { bip39SampleWords.contains($0) }.count
        guard hasContext || knownWords >= 8 else {
            return nil
        }
        return SensitiveFinding(
            category: .seedPhrase,
            confidence: .high,
            reason: "Recovery-phrase word sequence detected"
        )
    }

    private static func paymentCardFinding(_ text: String) -> SensitiveFinding? {
        guard let regex = try? NSRegularExpression(
            pattern: #"(?<!\d)(?:\d[ -]?){12,18}\d(?!\d)"#
        ) else {
            return nil
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        let candidate = regex.matches(in: text, range: range)
            .compactMap { Range($0.range, in: text) }
            .map { text[$0].filter(\.isNumber) }
            .first {
                (13...19).contains($0.count)
                    && Set($0).count > 1
                    && passesLuhn(String($0))
            }
        guard candidate != nil else { return nil }
        return SensitiveFinding(
            category: .paymentCard,
            confidence: .high,
            reason: "Card-length number passed checksum validation"
        )
    }

    private static func contextualPasswordFinding(_ text: String) -> SensitiveFinding? {
        guard matches(contextualPasswordPattern, in: text, caseInsensitive: true) else { return nil }
        return SensitiveFinding(
            category: .password,
            confidence: .high,
            reason: "Password field with a value"
        )
    }

    private static func otpFinding(_ text: String) -> SensitiveFinding? {
        guard matches(otpPattern, in: text, caseInsensitive: true) else { return nil }
        return SensitiveFinding(
            category: .oneTimeCode,
            confidence: .medium,
            reason: "Verification-code context with a short number"
        )
    }

    private static func passwordLikeFinding(_ text: String) -> SensitiveFinding? {
        guard (12...128).contains(text.count),
              !text.contains(where: \.isWhitespace),
              !looksLikeWebURL(text),
              !looksLikeFilePath(text),
              !matches(#"^[0-9a-f-]{32,36}$"#, in: text, caseInsensitive: true)
        else {
            return nil
        }
        let classes = [
            text.contains(where: \.isLowercase),
            text.contains(where: \.isUppercase),
            text.contains(where: \.isNumber),
            text.contains { !$0.isLetter && !$0.isNumber }
        ].filter { $0 }.count
        guard classes == 4 else { return nil }
        return SensitiveFinding(
            category: .password,
            confidence: .medium,
            reason: "High-entropy password-like string"
        )
    }

    private static func looksLikeWebURL(_ text: String) -> Bool {
        guard !text.contains(where: \.isWhitespace),
              let url = URL(string: text),
              let scheme = url.scheme?.lowercased()
        else {
            return false
        }
        return scheme == "http" || scheme == "https"
    }

    private static func passesLuhn(_ digits: String) -> Bool {
        var sum = 0
        var shouldDouble = false
        for character in digits.reversed() {
            guard var digit = character.wholeNumberValue else { return false }
            if shouldDouble {
                digit *= 2
                if digit > 9 { digit -= 9 }
            }
            sum += digit
            shouldDouble.toggle()
        }
        return sum.isMultiple(of: 10)
    }

    private static func matches(
        _ pattern: String,
        in text: String,
        caseInsensitive: Bool = false
    ) -> Bool {
        let options: NSRegularExpression.Options = caseInsensitive ? [.caseInsensitive] : []
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else {
            return false
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.firstMatch(in: text, range: range) != nil
    }
}
