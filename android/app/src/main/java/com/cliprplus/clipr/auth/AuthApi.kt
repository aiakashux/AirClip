package com.cliprplus.clipr.auth

import com.cliprplus.clipr.util.RedactingLogger
import com.google.gson.Gson
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody

data class AuthResponse(
    val token: String,
    val account_id: String
)

/**
 * REST client for account auth endpoints.
 * Uses AccountToken only — never DeviceToken (per docs/protocol.md §3.4).
 */
class AuthApi(
    private val baseUrl: String,
    private val client: OkHttpClient
) {
    private val gson = Gson()
    private val jsonMt = "application/json".toMediaType()

    /** POST /auth/register */
    fun register(email: String, password: String): AuthResponse =
        post("$baseUrl/auth/register", mapOf("email" to email, "password" to password))

    /** POST /auth/login */
    fun login(email: String, password: String): AuthResponse =
        post("$baseUrl/auth/login", mapOf("email" to email, "password" to password))

    private fun post(url: String, body: Map<String, String>): AuthResponse {
        val reqBody = gson.toJson(body).toRequestBody(jsonMt)
        val req = Request.Builder().url(url).post(reqBody).build()
        client.newCall(req).execute().use { resp ->
            val raw = resp.body?.string() ?: error("Empty response body")
            if (!resp.isSuccessful) error("HTTP ${resp.code}: $raw")
            val result = gson.fromJson(raw, AuthResponse::class.java)
            RedactingLogger.logToken("account_token", result.token)
            return result
        }
    }
}
