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

    private fun record(
        messageId: String,
        timestampMs: Long,
        fromDeviceId: String = "mac-device",
        preview: String = "same clip",
        contentText: String? = preview,
    ) = ClipItemRecord(
        messageId = messageId,
        seq = 0L,
        fromDeviceId = fromDeviceId,
        timestampMs = timestampMs,
        cipherHash = "content-hash",
        preview = preview,
        contentText = contentText,
    )
}
