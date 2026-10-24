package com.airclip.airclip

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertFalse
import org.junit.Test

class ClipboardWirePayloadTest {
    @Test
    fun `rejects file paths and invalid metadata from a peer`() {
        for (id in listOf("../escape", "/absolute", "a/b", "a\\b", "", ".", "a".repeat(129))) {
            val encoded = com.google.gson.Gson().toJson(mapOf(
                "kindRaw" to "file", "text" to "unsafe",
                "file" to mapOf("id" to id, "name" to "file.txt", "size" to 1, "mimeType" to "text/plain"),
            ))
            val decoded = ClipboardWirePayload.decode(encoded)
            assertEquals(ClipKind.TEXT, decoded.kind)
            assertNull(decoded.file)
        }
        assertNull(ClipboardWirePayload.decode("""{"kindRaw":"file","text":"missing","file":{"id":"safe","size":1}}""").file)
        assertNull(ClipboardWirePayload.decode("""{"kindRaw":"file","text":"negative","file":{"id":"safe","name":"a","size":-1}}""").file)
    }


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
        assertEquals(ClipKind.TEXT, decoded.kind)
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

    @Test
    fun `file clip round trip carries metadata but no file bytes`() {
        val file = FileClipMetadata(
            id = "source-file-1", name = "movie.mp4", size = 1_073_741_824L,
            mimeType = "video/mp4", durationMs = 7_200_000L, width = 1920, height = 1080,
        )
        val record = ClipItemRecord(
            messageId = "message-1", seq = 0L, fromDeviceId = "android",
            timestampMs = 12_345L, cipherHash = "hash", preview = file.name,
            contentText = file.name, kind = ClipKind.FILE.name,
            file = file, sourceFilePath = "/private/source-file-1",
        )

        val encoded = ClipboardWirePayload.encode(record)
        val decoded = ClipboardWirePayload.decode(encoded)

        assertEquals(ClipKind.FILE, decoded.kind)
        assertEquals(file, decoded.file)
        assertFalse(encoded.contains("sourceFilePath"))
        assertFalse(encoded.contains("/private/source-file-1"))
    }
}
