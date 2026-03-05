package com.cliprplus.clipr.device

import com.cliprplus.clipr.util.RedactingLogger
import com.google.gson.Gson
import okhttp3.OkHttpClient
import okhttp3.Request

/**
 * One item from the server-side clipboard history buffer.
 * Ciphertext is encrypted for THIS device only.
 * DO NOT log ciphertext — use RedactingLogger.logCiphertext if needed.
 */
data class ClipHistoryItem(
    val seq: Long,            // MED 8: Long — monotonic per-account seq
    val message_id: String,
    val from_device_id: String,
    val ciphertext: String,   // base64 — encrypted for the requesting device
    val nonce: String         // base64
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
    fun fetchHistory(deviceToken: String, afterSeq: Long, limit: Int = 20): List<ClipHistoryItem> {
        val req = Request.Builder()
            .url("$baseUrl/clips/?after_seq=$afterSeq&limit=$limit")
            .header("Authorization", "Bearer $deviceToken")
            .get()
            .build()

        client.newCall(req).execute().use { resp ->
            val raw = resp.body?.string() ?: error("Empty response body")
            if (!resp.isSuccessful) error("HTTP ${resp.code}: $raw")
            val items = gson.fromJson(raw, Array<ClipHistoryItem>::class.java).toList()
            RedactingLogger.info("ClipsApi.fetchHistory: afterSeq=$afterSeq count=${items.size}")
            return items
        }
    }
}
