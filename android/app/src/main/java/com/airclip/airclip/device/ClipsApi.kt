package com.airclip.airclip.device

import com.airclip.airclip.util.RedactingLogger
import com.google.gson.Gson
import okhttp3.OkHttpClient
import okhttp3.Request

/**
 * One item from the server-side clipboard history buffer.
 * Ciphertext is encrypted for THIS device only.
 * DO NOT log ciphertext — use RedactingLogger.logCiphertext if needed.
 */
data class ClipHistoryItem(
    val seq: Long,            // MED 8: Long — converted from JSON string in fetchHistory
    val message_id: String,
    val from_device_id: String,
    val ciphertext: String,   // base64 — encrypted for the requesting device
    val nonce: String         // base64
)

// Backend serialises seq as a JSON string (e.g. "5") — Gson cannot coerce
// string → Long in POJO mode, so we parse into this raw type first.
private data class ClipHistoryItemRaw(
    val seq: String,
    val message_id: String,
    val from_device_id: String,
    val ciphertext: String,
    val nonce: String
)

/**
 * REST client for the /clips history endpoint.
 * Auth: device-scoped JWT (token_type="device") — NOT account token.
 */
class ClipsApi(
    private val baseUrl: String,
    private val client: OkHttpClient
) {
    private val gson = Gson()

    /**
     * GET /clips/?after_seq=<afterSeq>&limit=<limit>
     * Returns clips with seq > afterSeq encrypted for the requesting device, ascending.
     * Must be called with [deviceToken], not accountToken.
     */
    /**
     * DELETE /clips/<messageId>
     * Idempotent — returns true on 204, false on any error.
     * Must be called with [deviceToken], not accountToken.
     */
    fun deleteClip(deviceToken: String, messageId: String): Boolean {
        val req = Request.Builder()
            .url("$baseUrl/clips/$messageId")
            .header("Authorization", "Bearer $deviceToken")
            .delete()
            .build()

        return try {
            client.newCall(req).execute().use { resp ->
                RedactingLogger.info("ClipsApi.deleteClip: messageId=${messageId.take(8)}… status=${resp.code}")
                resp.isSuccessful
            }
        } catch (e: Exception) {
            RedactingLogger.info("ClipsApi.deleteClip: error ${e.message}")
            false
        }
    }

    fun fetchHistory(deviceToken: String, afterSeq: Long, limit: Int = 20): List<ClipHistoryItem> {
        val req = Request.Builder()
            .url("$baseUrl/clips/?after_seq=$afterSeq&limit=$limit")
            .header("Authorization", "Bearer $deviceToken")
            .get()
            .build()

        client.newCall(req).execute().use { resp ->
            val raw = resp.body?.string() ?: error("Empty response body")
            if (!resp.isSuccessful) error("HTTP ${resp.code}: $raw")
            // Parse into raw first (seq as String), then convert seq to Long.
            val rawItems = gson.fromJson(raw, Array<ClipHistoryItemRaw>::class.java).toList()
            val items = rawItems.map { r ->
                ClipHistoryItem(
                    seq            = r.seq.toLongOrNull() ?: error("Invalid seq '${r.seq}'"),
                    message_id     = r.message_id,
                    from_device_id = r.from_device_id,
                    ciphertext     = r.ciphertext,
                    nonce          = r.nonce
                )
            }
            RedactingLogger.info("ClipsApi.fetchHistory: afterSeq=$afterSeq count=${items.size}")
            return items
        }
    }
}
