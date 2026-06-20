package com.airclip.airclip

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class ClipboardWirePayloadTest {

    @Test
    fun `decodes mac clipboard packet`() {
        val decoded = ClipboardWirePayload.decode(
            """{"kindRaw":"url","text":"https://airclip.test","imageDataBase64":null}"""
        )

        assertEquals("https://airclip.test", decoded.text)
        assertEquals(ClipKind.URL, decoded.kind)
        assertNull(decoded.imageDataBase64)
    }

    @Test
    fun `preserves image data from mac clipboard packet`() {
        val decoded = ClipboardWirePayload.decode(
            """{"kindRaw":"image","text":"Image 640×480","imageDataBase64":"iVBORw0KGgo="}"""
        )

        assertEquals("Image 640×480", decoded.text)
        assertEquals(ClipKind.IMAGE, decoded.kind)
        assertEquals("iVBORw0KGgo=", decoded.imageDataBase64)
    }

    @Test
    fun `preserves ordinary json clipboard text`() {
        val plaintext = """{"message":"keep this json"}"""

        val decoded = ClipboardWirePayload.decode(plaintext)

        assertEquals(plaintext, decoded.text)
        assertEquals(ClipKind.CODE, decoded.kind)
    }

    @Test
    fun `falls back to content detection for unknown packet kind`() {
        val decoded = ClipboardWirePayload.decode(
            """{"kindRaw":"future-kind","text":"https://airclip.test"}"""
        )

        assertEquals("https://airclip.test", decoded.text)
        assertEquals(ClipKind.URL, decoded.kind)
    }

    @Test
    fun `encodes android history record as mac clipboard packet shape`() {
        val encoded = ClipboardWirePayload.encode(
            ClipItemRecord(
                messageId = "android-message",
                seq = 0L,
                fromDeviceId = "android-device",
                timestampMs = 12_345L,
                cipherHash = "hash",
                preview = "https://airclip.test",
                contentText = "https://airclip.test",
                kind = ClipKind.URL.name,
                imageDataBase64 = null,
            )
        )

        val decoded = ClipboardWirePayload.decode(encoded)

        assertEquals("https://airclip.test", decoded.text)
        assertEquals(ClipKind.URL, decoded.kind)
        assertNull(decoded.imageDataBase64)
    }

    @Test
    fun `encodes full text instead of preview for android backfill`() {
        val fullText = "A long clipboard value that should not be reduced to forty characters."
        val encoded = ClipboardWirePayload.encode(
            ClipItemRecord(
                messageId = "android-message",
                seq = 0L,
                fromDeviceId = "android-device",
                timestampMs = 12_345L,
                cipherHash = "hash",
                preview = fullText.take(40),
                contentText = fullText,
                kind = ClipKind.TEXT.name,
            )
        )

        val decoded = ClipboardWirePayload.decode(encoded)

        assertEquals(fullText, decoded.text)
        assertEquals(ClipKind.TEXT, decoded.kind)
    }
}
