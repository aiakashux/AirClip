package com.airclip.airclip

import com.google.gson.Gson
import com.google.gson.JsonObject

internal data class DecodedClipboardPayload(
    val text: String,
    val kind: ClipKind,
    val imageDataBase64: String? = null,
    val file: FileClipMetadata? = null,
)

internal object ClipboardWirePayload {
    private val gson = Gson()

    fun encode(record: ClipItemRecord): String =
        gson.toJson(
            mapOf(
                "kindRaw" to record.kind.lowercase(),
                "text" to record.displayText,
                "imageDataBase64" to record.imageDataBase64,
                "file" to record.file,
            )
        )

    fun decode(plaintext: String): DecodedClipboardPayload {
        val packet = runCatching {
            gson.fromJson(plaintext, JsonObject::class.java)
        }.getOrNull()

        val kindRaw = packet?.get("kindRaw")?.takeIf { it.isJsonPrimitive }?.asString
        val text = packet?.get("text")?.takeIf { it.isJsonPrimitive }?.asString
        val imageDataBase64 = packet?.get("imageDataBase64")
            ?.takeIf { it.isJsonPrimitive }
            ?.asString
        val file = packet?.get("file")?.takeIf { it.isJsonObject }?.let {
            runCatching { gson.fromJson(it, FileClipMetadata::class.java) }.getOrNull()
        }

        if (kindRaw != null && text != null) {
            val kind = runCatching { ClipKind.valueOf(kindRaw.uppercase()) }
                .getOrDefault(detectClipKind(text))
            return DecodedClipboardPayload(
                text = text,
                kind = kind,
                imageDataBase64 = imageDataBase64,
                file = file,
            )
        }

        return DecodedClipboardPayload(
            text = plaintext,
            kind = detectClipKind(plaintext),
        )
    }
}
