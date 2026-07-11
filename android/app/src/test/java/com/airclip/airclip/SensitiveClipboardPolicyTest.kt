package com.airclip.airclip

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class SensitiveClipboardPolicyTest {

    @Test
    fun `detects high confidence secret formats`() {
        assertCategory(
            "sk-proj-abcdefghijklmnopqrstuvwxyz123456",
            SensitiveCategory.API_TOKEN,
            SensitiveConfidence.HIGH,
        )
        assertCategory(
            "-----BEGIN PRIVATE KEY-----\nabc123\n-----END PRIVATE KEY-----",
            SensitiveCategory.PRIVATE_KEY,
            SensitiveConfidence.HIGH,
        )
        assertCategory(
            "abandon ability able about above absent absorb abstract absurd abuse access accident",
            SensitiveCategory.SEED_PHRASE,
            SensitiveConfidence.HIGH,
        )
        assertCategory(
            "Card: 4111 1111 1111 1111",
            SensitiveCategory.PAYMENT_CARD,
            SensitiveConfidence.HIGH,
        )
        assertCategory(
            "seed phrase: abandon ability able about above absent absorb abstract absurd abuse access accident",
            SensitiveCategory.SEED_PHRASE,
            SensitiveConfidence.HIGH,
        )
    }

    @Test
    fun `detects contextual and password-like values`() {
        assertCategory(
            "password: CorrectHorseBatteryStaple!",
            SensitiveCategory.PASSWORD,
            SensitiveConfidence.HIGH,
        )
        assertCategory(
            "Your verification code is 482193",
            SensitiveCategory.ONE_TIME_CODE,
            SensitiveConfidence.MEDIUM,
        )
        assertCategory(
            "vN7!mQ2#xP9@rT4$",
            SensitiveCategory.PASSWORD,
            SensitiveConfidence.MEDIUM,
        )
    }

    @Test
    fun `allows normal clipboard content`() {
        val safe = listOf(
            "https://airclip.app/docs?token=design",
            "Meet me at 4:30 near the station.",
            "8489F297-D408-40D4-8FD3-812F198AA801",
            "+1 (415) 555-0132",
            "/Users/akash/Downloads/resume-final.pdf",
            "file:///Users/akash/Documents/history/report.png",
            "C:\\Users\\Akash\\Desktop\\portfolio.html",
            "https://www.figma.com/design/p6I5nXWy6uzKwQcwwdu8xp/AirClip?node-id=286-6709&t=uuB8tXRKrzMhu6yF-11",
            "file:///Users/cosmic-sky/Downloads/ideascale-cs-chunk1.html",
            "This sentence has exactly twelve ordinary lowercase words and should remain normal text.",
        )

        safe.forEach { text ->
            assertFalse("$text should be allowed", SensitiveClipboardClassifier.classify(text).isSensitive)
        }
    }

    @Test
    fun `automatic sends block and manual sends require confirmation`() {
        val assessment = SensitiveClipboardClassifier.classify(
            "client_secret=abcDEF1234567890xyz"
        )

        assertEquals(
            SensitiveSendDecision.BLOCK,
            SensitiveClipboardPolicy.decide(assessment, SensitiveSendIntent.AUTOMATIC),
        )
        assertEquals(
            SensitiveSendDecision.REQUIRE_CONFIRMATION,
            SensitiveClipboardPolicy.decide(assessment, SensitiveSendIntent.MANUAL),
        )
        assertEquals(
            SensitiveSendDecision.ALLOW,
            SensitiveClipboardPolicy.decide(
                SensitiveClipboardClassifier.classify("normal clipboard text"),
                SensitiveSendIntent.AUTOMATIC,
            ),
        )
    }

    @Test
    fun `category actions can block ask or allow`() {
        val assessment = SensitiveClipboardClassifier.classify(
            "client_secret=abcDEF1234567890xyz"
        )

        assertEquals(
            SensitiveSendDecision.BLOCK,
            SensitiveClipboardPolicy.decide(
                assessment,
                SensitiveSendIntent.MANUAL,
                SensitiveRuleAction.ALWAYS_BLOCK,
            ),
        )
        assertEquals(
            SensitiveSendDecision.REQUIRE_CONFIRMATION,
            SensitiveClipboardPolicy.decide(
                assessment,
                SensitiveSendIntent.MANUAL,
                SensitiveRuleAction.ASK,
            ),
        )
        assertEquals(
            SensitiveSendDecision.ALLOW,
            SensitiveClipboardPolicy.decide(
                assessment,
                SensitiveSendIntent.AUTOMATIC,
                SensitiveRuleAction.ALLOW,
            ),
        )
        assertEquals(SensitiveRuleAction.ALLOW, SensitiveRuleAction.fromStoredValue(null))
        assertEquals(SensitiveRuleAction.ALLOW, SensitiveRuleAction.fromStoredValue("invalid"))
    }

    private fun assertCategory(
        text: String,
        category: SensitiveCategory,
        confidence: SensitiveConfidence,
    ) {
        val assessment = SensitiveClipboardClassifier.classify(text)
        assertTrue("Expected sensitive classification for $text", assessment.isSensitive)
        assertEquals(category, assessment.primaryFinding?.category)
        assertEquals(confidence, assessment.primaryFinding?.confidence)
    }
}
