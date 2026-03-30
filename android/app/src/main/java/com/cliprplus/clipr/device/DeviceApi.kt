package com.cliprplus.clipr.device

import com.cliprplus.clipr.util.RedactingLogger
import com.google.gson.Gson
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody

data class DeviceInfo(
    val device_id: String,
    val device_name: String,
    val platform: String,
    val public_key: String,       // base64 X25519 public key
    val trust_status: String,     // "trusted" | "pending"
    val created_at: String?,
    val last_seen: String?
)

data class DeviceRegisterResponse(
    val device_id: String,
    val device_name: String,
    val platform: String,
    val public_key: String,
    val trust_status: String,
    val created_at: String?,
    val last_seen: String?,
    val token: String             // device-scoped JWT — use for WS only
)

/**
 * REST client for device management endpoints.
 * All calls require AccountToken in Authorization header (per docs/protocol.md §3.4).
 * DeviceToken must NOT be passed to any method here.
 */
class DeviceApi(
    private val baseUrl: String,
    private val client: OkHttpClient
) {
    private val gson = Gson()
    private val jsonMt = "application/json".toMediaType()

    /**
     * POST /devices/register
     * Must be called with [accountToken], never deviceToken.
     */
    fun registerDevice(
        accountToken: String,
        deviceName: String,
        platform: String,
        publicKeyBase64: String
    ): DeviceRegisterResponse {
        val body = gson.toJson(
            mapOf(
                "device_name" to deviceName,
                "platform" to platform,
                "public_key" to publicKeyBase64
            )
        ).toRequestBody(jsonMt)

        val req = Request.Builder()
            .url("$baseUrl/devices/register")
            .header("Authorization", "Bearer $accountToken")
            .post(body)
            .build()

        client.newCall(req).execute().use { resp ->
            val raw = resp.body?.string() ?: error("Empty response body")
            if (!resp.isSuccessful) error("HTTP ${resp.code}: $raw")
            val result = gson.fromJson(raw, DeviceRegisterResponse::class.java)
            RedactingLogger.info("registerDevice: device_id=${result.device_id} trust=${result.trust_status}")
            RedactingLogger.logToken("device_token", result.token)
            return result
        }
    }

    /**
     * GET /devices/
     * Must be called with [accountToken], never deviceToken.
     */
    fun listDevices(accountToken: String): List<DeviceInfo> {
        val req = Request.Builder()
            .url("$baseUrl/devices/")
            .header("Authorization", "Bearer $accountToken")
            .get()
            .build()

        client.newCall(req).execute().use { resp ->
            val raw = resp.body?.string() ?: error("Empty response body")
            if (!resp.isSuccessful) error("HTTP ${resp.code}: $raw")
            val result = gson.fromJson(raw, Array<DeviceInfo>::class.java).toList()
            RedactingLogger.info("listDevices: count=${result.size}")
            return result
        }
    }
}
