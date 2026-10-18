package com.airclip.airclip

import org.junit.Assert.assertEquals
import org.junit.Test

class ClipHistoryDeduplicationTest {

    @Test
    fun `history backfill is not truncated at the legacy twenty item limit`() {
        val retained = (1..21).toList()

        assertEquals(retained, ClipHistoryStore.backfill(retained))
    }

    @Test
    fun `code-like text stays regular text`() {
        assertEquals(ClipKind.TEXT, detectClipKind("fun copy() { return true }"))
    }

    @Test
    fun `repeated content keeps one record and promotes the newest copy`() {
        val live = record(
            messageId = "lan-random",
            timestampMs = 10_000L,
        )
        val history = record(
            messageId = "mac-original",
            timestampMs = 10_645L,
        )

        assertEquals(listOf(history), ClipHistoryStore.deduplicate(listOf(live, history)))
    }

    @Test
    fun `promotes repeated content even when the earlier copy is old`() {
        val first = record(
            messageId = "first",
            timestampMs = 10_000L,
        )
        val later = record(
            messageId = "later",
            timestampMs = 12_001L,
        )

        assertEquals(listOf(later), ClipHistoryStore.deduplicate(listOf(first, later)))
    }

    @Test
    fun `promotes repeated content copied on another device`() {
        val mac = record(
            messageId = "mac",
            timestampMs = 10_000L,
        )
        val android = record(
            messageId = "android",
            timestampMs = 10_100L,
            fromDeviceId = "android-device",
        )

        assertEquals(listOf(android), ClipHistoryStore.deduplicate(listOf(mac, android)))
    }

    @Test
    fun `deduplicates same image content even when echoed later from another device`() {
        val androidShare = record(
            messageId = "android-local",
            timestampMs = 10_000L,
            fromDeviceId = "android-device",
            kind = ClipKind.IMAGE,
        )
        val macEcho = record(
            messageId = "mac-history",
            timestampMs = 75_000L,
            fromDeviceId = "mac-device",
            kind = ClipKind.IMAGE,
        )

        assertEquals(listOf(macEcho), ClipHistoryStore.deduplicate(listOf(androidShare, macEcho)))
    }

    @Test
    fun `same file metadata promotes newest copy even when transfer ids differ`() {
        val original = record(
            messageId = "old-file",
            timestampMs = 10_000L,
            kind = ClipKind.FILE,
        ).copy(file = file(id = "transfer-1"), sourceFilePath = "/tmp/report.pdf")
        val copiedAgain = record(
            messageId = "new-file",
            timestampMs = 80_000L,
            kind = ClipKind.FILE,
        ).copy(file = file(id = "transfer-2"), sourceFilePath = "/tmp/report.pdf")

        val result = ClipHistoryStore.deduplicate(listOf(original, copiedAgain)).single()

        assertEquals("new-file", result.messageId)
        assertEquals(80_000L, result.timestampMs)
        assertEquals("/tmp/report.pdf", result.sourceFilePath)
    }

    @Test
    fun `preserves full text when duplicate history arrives for preview-only record`() {
        val previewOnly = record(
            messageId = "preview-only",
            timestampMs = 10_000L,
            preview = "a long clip",
            contentText = null,
        )
        val fullText = record(
            messageId = "full-text",
            timestampMs = 10_500L,
            preview = "a long clip",
            contentText = "a long clipboard value that arrived later",
        )

        assertEquals(
            "a long clipboard value that arrived later",
            ClipHistoryStore.deduplicate(listOf(previewOnly, fullText)).single().contentText,
        )
    }

    @Test
    fun `preserves persisted image when duplicate upgrades a preview-only record`() {
        val previewOnly = record(
            messageId = "preview-only",
            timestampMs = 10_000L,
            kind = ClipKind.IMAGE,
        )
        val persisted = record(
            messageId = "persisted",
            timestampMs = 75_000L,
            kind = ClipKind.IMAGE,
        ).copy(imageFileName = "persisted-image.img")

        assertEquals(
            "persisted-image.img",
            ClipHistoryStore.deduplicate(listOf(previewOnly, persisted)).single().imageFileName,
        )
    }

    @Test
    fun `stores an image file reference without embedding image bytes`() {
        val fullImage = record(
            messageId = "image",
            timestampMs = 10_000L,
            kind = ClipKind.IMAGE,
        ).copy(
            imageDataBase64 = "a".repeat(1_000_000),
            imageFileName = "persisted-image.img",
        )

        val stored = ClipHistoryStore.prepareForStorage(listOf(fullImage)).single()

        assertEquals(null, stored.imageDataBase64)
        assertEquals("persisted-image.img", stored.imageFileName)
        assertEquals(ClipKind.IMAGE.name, stored.kind)
        assertEquals("content-hash", stored.cipherHash)
    }

    @Test
    fun `trims huge text before history is persisted`() {
        val fullText = record(
            messageId = "text",
            timestampMs = 10_000L,
            preview = "large text",
            contentText = "x".repeat(ClipHistoryStore.MAX_PERSISTED_TEXT_CHARS + 100),
        )

        val stored = ClipHistoryStore.prepareForStorage(listOf(fullText)).single()

        assertEquals(ClipHistoryStore.MAX_PERSISTED_TEXT_CHARS, stored.contentText?.length)
    }

    private fun record(
        messageId: String,
        timestampMs: Long,
        fromDeviceId: String = "mac-device",
        preview: String = "same clip",
        contentText: String? = preview,
        kind: ClipKind = ClipKind.TEXT,
    ) = ClipItemRecord(
        messageId = messageId,
        seq = 0L,
        fromDeviceId = fromDeviceId,
        timestampMs = timestampMs,
        cipherHash = "content-hash",
        preview = preview,
        contentText = contentText,
        kind = kind.name,
    )

    private fun file(id: String) = FileClipMetadata(
        id = id,
        name = "report.pdf",
        size = 1_024L,
        mimeType = "application/pdf",
        modifiedAtMs = 123_456L,
    )
}
