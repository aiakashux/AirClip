import Foundation

@main
struct SensitiveClipboardPolicyCheck {
    static func main() {
        assertCategory(
            "sk-proj-abcdefghijklmnopqrstuvwxyz123456",
            .apiToken,
            .high
        )
        assertCategory(
            "-----BEGIN PRIVATE KEY-----\nabc123\n-----END PRIVATE KEY-----",
            .privateKey,
            .high
        )
        assertCategory(
            "abandon ability able about above absent absorb abstract absurd abuse access accident",
            .seedPhrase,
            .high
        )
        assertCategory("Card: 4111 1111 1111 1111", .paymentCard, .high)
        assertCategory(
            "seed phrase: abandon ability able about above absent absorb abstract absurd abuse access accident",
            .seedPhrase,
            .high
        )
        assertCategory("password: CorrectHorseBatteryStaple!", .password, .high)
        assertCategory("Your verification code is 482193", .oneTimeCode, .medium)
        assertCategory("vN7!mQ2#xP9@rT4$", .password, .medium)

        let safe = [
            "https://airclip.app/docs?token=design",
            "Meet me at 4:30 near the station.",
            "8489F297-D408-40D4-8FD3-812F198AA801",
            "+1 (415) 555-0132",
            "/Users/akash/Downloads/resume-final.pdf",
            "file:///Users/akash/Documents/history/report.png",
            "C:\\Users\\Akash\\Desktop\\portfolio.html",
            "https://www.figma.com/design/p6I5nXWy6uzKwQcwwdu8xp/AirClip?node-id=286-6709&t=uuB8tXRKrzMhu6yF-11",
            "file:///Users/cosmic-sky/Downloads/ideascale-cs-chunk1.html",
            "This sentence has exactly twelve ordinary lowercase words and should remain normal text."
        ]
        precondition(safe.allSatisfy {
            !SensitiveClipboardClassifier.classify($0).isSensitive
        })

        let assessment = SensitiveClipboardClassifier.classify(
            "client_secret=abcDEF1234567890xyz"
        )
        precondition(
            SensitiveClipboardPolicy.decide(assessment, intent: .automatic) == .block
        )
        precondition(
            SensitiveClipboardPolicy.decide(assessment, intent: .manual) == .requireConfirmation
        )
        precondition(
            SensitiveClipboardPolicy.decide(
                SensitiveClipboardClassifier.classify("normal clipboard text"),
                intent: .automatic
            ) == .allow
        )
        precondition(
            SensitiveClipboardPolicy.decide(
                assessment,
                intent: .manual,
                action: .alwaysBlock
            ) == .block
        )
        precondition(
            SensitiveClipboardPolicy.decide(
                assessment,
                intent: .automatic,
                action: .allow
            ) == .allow
        )
        precondition(
            SensitiveClipboardPolicy.decide(
                assessment,
                intent: .manual,
                action: .ask
            ) == .requireConfirmation
        )
        precondition(SensitiveRuleAction.fromStoredValue(nil) == .allow)
        precondition(SensitiveRuleAction.fromStoredValue("invalid") == .allow)
    }

    private static func assertCategory(
        _ text: String,
        _ category: SensitiveCategory,
        _ confidence: SensitiveConfidence
    ) {
        let assessment = SensitiveClipboardClassifier.classify(text)
        precondition(assessment.isSensitive)
        precondition(assessment.primaryFinding?.category == category)
        precondition(assessment.primaryFinding?.confidence == confidence)
    }
}
