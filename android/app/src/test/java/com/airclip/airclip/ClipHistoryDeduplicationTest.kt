package com.airclip.airclip

import org.junit.Assert.assertEquals
import org.junit.Test

class ClipHistoryDeduplicationTest {

    @Test
    fun `reconciles live and history records for the same logical clip`() {
        val live = record(
            messageId = "lan-random",
            timestampMs = 10_000L,
        )
        val history = record(
            messageId = "mac-original",
            timestampMs = 10_645L,
        )

        assertEquals(listOf(live), ClipHistoryStore.deduplicate(listOf(live, history)))
    }

    @Test
    fun `keeps repeated content outside reconciliation window`() {
        val first = record(
            messageId = "first",
            timestampMs = 10_000L,
        )
        val later = record(
            messageId = "later",
            timestampMs = 12_001L,
        )

        assertEquals(listOf(first, later), ClipHistoryStore.deduplicate(listOf(first, later)))
    }

    @Test
    fun `keeps same content from different devices`() {
        val mac = record(
            messageId = "mac",
            timestampMs = 10_000L,
        )
        val android = record(
            messageId = "android",
            timestampMs = 10_100L,
            fromDeviceId = "android-device",
        )

        assertEquals(listOf(mac, android), ClipHistoryStore.deduplicate(listOf(mac, android)))
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

        assertEquals(listOf(androidShare), ClipHistoryStore.deduplicate(listOf(androidShare, macEcho)))
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
    fun `removes image bytes before history is persisted`() {
        val fullImage = record(
            messageId = "image",
            timestampMs = 10_000L,
            kind = ClipKind.IMAGE,
        ).copy(imageDataBase64 = "a".repeat(1_000_000))

        val stored = ClipHistoryStore.prepareForStorage(listOf(fullImage)).single()

        assertEquals(null, stored.imageDataBase64)
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
}
