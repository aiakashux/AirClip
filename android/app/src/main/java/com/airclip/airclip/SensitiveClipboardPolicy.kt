package com.airclip.airclip

enum class SensitiveCategory(val label: String) {
    PASSWORD("Password"),
    API_TOKEN("API key or token"),
    PRIVATE_KEY("Private key"),
    SEED_PHRASE("Recovery phrase"),
    PAYMENT_CARD("Payment card"),
    ONE_TIME_CODE("One-time code"),
}

enum class SensitiveConfidence {
    MEDIUM,
    HIGH,
}

data class SensitiveFinding(
    val category: SensitiveCategory,
    val confidence: SensitiveConfidence,
    val reason: String,
)

data class SensitiveAssessment(
    val findings: List<SensitiveFinding>,
) {
    val isSensitive: Boolean get() = findings.isNotEmpty()
    val primaryFinding: SensitiveFinding? get() = findings.firstOrNull()
}

enum class SensitiveSendIntent {
    AUTOMATIC,
    MANUAL,
}

enum class SensitiveSendDecision {
    ALLOW,
    BLOCK,
    REQUIRE_CONFIRMATION,
}

enum class SensitiveRuleAction(val label: String) {
    ALWAYS_BLOCK("Block"),
    ASK("Ask"),
    ALLOW("Allow");

    companion object {
        fun fromStoredValue(value: String?): SensitiveRuleAction =
            entries.firstOrNull { it.name == value } ?: ASK
    }
}

object SensitiveClipboardPolicy {
    fun decide(
        assessment: SensitiveAssessment,
        intent: SensitiveSendIntent,
        action: SensitiveRuleAction = SensitiveRuleAction.ASK,
    ): SensitiveSendDecision {
        if (!assessment.isSensitive) return SensitiveSendDecision.ALLOW
        return when (action) {
            SensitiveRuleAction.ALWAYS_BLOCK -> SensitiveSendDecision.BLOCK
            SensitiveRuleAction.ALLOW -> SensitiveSendDecision.ALLOW
            SensitiveRuleAction.ASK -> when (intent) {
                SensitiveSendIntent.AUTOMATIC -> SensitiveSendDecision.BLOCK
                SensitiveSendIntent.MANUAL -> SensitiveSendDecision.REQUIRE_CONFIRMATION
            }
        }
    }
}

object SensitiveClipboardClassifier {
    private val privateKeyPattern =
        Regex("""-----BEGIN (?:[A-Z0-9 ]+ )?PRIVATE KEY-----""", RegexOption.IGNORE_CASE)
    private val knownTokenPatterns = listOf(
        Regex("""\bsk-(?:proj-)?[A-Za-z0-9_-]{20,}\b"""),
        Regex("""\bgh[pousr]_[A-Za-z0-9]{20,}\b"""),
        Regex("""\bAKIA[0-9A-Z]{16}\b"""),
        Regex("""\beyJ[A-Za-z0-9_-]{5,}\.eyJ[A-Za-z0-9_-]{5,}\.[A-Za-z0-9_-]{8,}\b"""),
        Regex("""(?i)\bBearer\s+[A-Za-z0-9._~+/-]{16,}=*\b"""),
        Regex("""\bxox[baprs]-[A-Za-z0-9-]{20,}\b"""),
        Regex("""\bnpm_[A-Za-z0-9]{20,}\b"""),
        Regex("""\bpypi-[A-Za-z0-9_-]{20,}\b"""),
        Regex("""\bAIza[0-9A-Za-z_-]{30,}\b"""),
        Regex("""\bsk_live_[A-Za-z0-9]{16,}\b"""),
    )
    private val assignedSecretPattern = Regex(
        """(?i)\b(api[_-]?key|access[_-]?token|auth[_-]?token|client[_-]?secret|secret[_-]?key)\b\s*[:=]\s*["']?([A-Za-z0-9._~+/-]{8,}=*)"""
    )
    private val contextualPasswordPattern = Regex(
        """(?i)\b(password|passwd|pwd|passcode)\b\s*[:=]\s*["']?(\S{4,})"""
    )
    private val otpPattern = Regex(
        """(?i)\b(otp|one[- ]time|verification|security|login|authentication)\b[^\n\d]{0,32}\b(\d{4,8})\b"""
    )
    private val seedContextPattern = Regex(
        """(?i)\b(seed|recovery|mnemonic)\s+(phrase|words?)\b"""
    )
    private val bip39SampleWords = setOf(
        "abandon", "ability", "able", "about", "above", "absent", "absorb", "abstract",
        "absurd", "abuse", "access", "accident", "account", "accuse", "achieve", "acid",
        "acoustic", "acquire", "across", "act", "action", "actor", "actress", "actual",
        "adapt", "add", "addict", "address", "adjust", "admit", "adult", "advance",
    )

    fun classify(text: String): SensitiveAssessment {
        val value = text.trim()
        if (value.isEmpty()) return SensitiveAssessment(emptyList())
        if (looksLikeFilePath(value)) return SensitiveAssessment(emptyList())

        val findings = listOfNotNull(
            privateKeyFinding(value),
            tokenFinding(value),
            seedPhraseFinding(value),
            paymentCardFinding(value),
            contextualPasswordFinding(value),
            otpFinding(value),
            passwordLikeFinding(value),
        )
        return SensitiveAssessment(findings.distinctBy { it.category })
    }

    private fun privateKeyFinding(text: String): SensitiveFinding? =
        privateKeyPattern.find(text)?.let {
            SensitiveFinding(
                SensitiveCategory.PRIVATE_KEY,
                SensitiveConfidence.HIGH,
                "Private-key header detected",
            )
        }

    private fun tokenFinding(text: String): SensitiveFinding? {
        if (knownTokenPatterns.any { it.containsMatchIn(text) }) {
            return SensitiveFinding(
                SensitiveCategory.API_TOKEN,
                SensitiveConfidence.HIGH,
                "Recognized token format",
            )
        }
        if (assignedSecretPattern.containsMatchIn(text)) {
            return SensitiveFinding(
                SensitiveCategory.API_TOKEN,
                SensitiveConfidence.HIGH,
                "Secret field with a credential-like value",
            )
        }
        return null
    }

    private fun seedPhraseFinding(text: String): SensitiveFinding? {
        val words = text
            .lowercase()
            .replace(Regex("""[^a-z\s]"""), " ")
            .split(Regex("""\s+"""))
            .filter { it.isNotEmpty() }
        val validLengths = setOf(12, 15, 18, 21, 24)
        val hasContext = seedContextPattern.containsMatchIn(text)
        val candidateWords = if (hasContext && words.size - 2 in validLengths) {
            words.drop(2)
        } else {
            words
        }
        if (candidateWords.size !in validLengths) return null

        val knownWords = candidateWords.count { it in bip39SampleWords }
        if (hasContext || knownWords >= 8) {
            return SensitiveFinding(
                SensitiveCategory.SEED_PHRASE,
                SensitiveConfidence.HIGH,
                "Recovery-phrase word sequence detected",
            )
        }
        return null
    }

    private fun paymentCardFinding(text: String): SensitiveFinding? {
        val hasValidCandidate = Regex("""(?<!\d)(?:\d[ -]?){12,18}\d(?!\d)""")
            .findAll(text)
            .map { it.value.filter(Char::isDigit) }
            .any {
                it.length in 13..19 && it.toSet().size > 1 && passesLuhn(it)
            }
        if (!hasValidCandidate) return null
        return SensitiveFinding(
            SensitiveCategory.PAYMENT_CARD,
            SensitiveConfidence.HIGH,
            "Card-length number passed checksum validation",
        )
    }

    private fun contextualPasswordFinding(text: String): SensitiveFinding? =
        contextualPasswordPattern.find(text)?.let {
            SensitiveFinding(
                SensitiveCategory.PASSWORD,
                SensitiveConfidence.HIGH,
                "Password field with a value",
            )
        }

    private fun otpFinding(text: String): SensitiveFinding? =
        otpPattern.find(text)?.let {
            SensitiveFinding(
                SensitiveCategory.ONE_TIME_CODE,
                SensitiveConfidence.MEDIUM,
                "Verification-code context with a short number",
            )
        }

    private fun passwordLikeFinding(text: String): SensitiveFinding? {
        if (text.length !in 12..128 || text.any(Char::isWhitespace)) return null
        if (looksLikeWebUrl(text) || looksLikeFilePath(text)) return null
        if (text.matches(Regex("""[0-9a-fA-F-]{32,36}"""))) return null
        val classes = listOf(
            text.any(Char::isLowerCase),
            text.any(Char::isUpperCase),
            text.any(Char::isDigit),
            text.any { !it.isLetterOrDigit() },
        ).count { it }
        if (classes < 4) return null
        return SensitiveFinding(
            SensitiveCategory.PASSWORD,
            SensitiveConfidence.MEDIUM,
            "High-entropy password-like string",
        )
    }

    private fun looksLikeWebUrl(text: String): Boolean {
        if (text.any(Char::isWhitespace)) return false
        return runCatching {
            val uri = java.net.URI(text)
            val scheme = uri.scheme?.lowercase()
            scheme == "http" || scheme == "https"
        }.getOrDefault(false)
    }

    private fun looksLikeFilePath(text: String): Boolean {
        if (text.any { it == '\n' || it == '\r' }) return false
        val lower = text.lowercase()
        if (lower.startsWith("file://")) return true
        if (lower.startsWith("/") || lower.startsWith("~/")) return true
        if (Regex("""^[a-zA-Z]:[\\/]""").containsMatchIn(text)) return true
        if (lower.contains("/")) {
            val pathExtensions = setOf(
                ".app", ".css", ".csv", ".doc", ".docx", ".gif", ".heic", ".html",
                ".jpeg", ".jpg", ".js", ".json", ".md", ".mov", ".mp4", ".pdf",
                ".png", ".py", ".rtf", ".svg", ".swift", ".txt", ".ts", ".tsx",
                ".webp", ".xls", ".xlsx", ".zip",
            )
            return pathExtensions.any { lower.endsWith(it) }
        }
        return false
    }

    private fun passesLuhn(digits: String): Boolean {
        var sum = 0
        var doubleDigit = false
        for (char in digits.reversed()) {
            var digit = char.digitToInt()
            if (doubleDigit) {
                digit *= 2
                if (digit > 9) digit -= 9
            }
            sum += digit
            doubleDigit = !doubleDigit
        }
        return sum % 10 == 0
    }
}
