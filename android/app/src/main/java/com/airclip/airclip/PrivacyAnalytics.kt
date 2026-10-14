package com.airclip.airclip

import android.content.Context
import android.os.Build
import com.google.gson.Gson
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody

enum class AnalyticsEvent(val wireName: String) {
    PAIRING_SUCCESS("pairing_success"),
    PAIRING_FAILURE("pairing_failure"),
    FIRST_TRANSFER("first_transfer"),
    TRANSFER_FAILURE("transfer_failure"),
    UPDATE_CHECK("update_check"),
    UPDATE_AVAILABLE("update_available"),
    UPDATE_OPENED("update_opened"),
    UPDATE_FAILURE("update_failure"),
}

object AnalyticsPayload {
    fun create(appVersion: String, osMajor: String, counts: Map<AnalyticsEvent, Int>): Map<String, Any> = mapOf(
        "schemaVersion" to 1,
        "appVersion" to appVersion,
        "platform" to "android",
        "osMajor" to osMajor,
        "counts" to counts.mapKeys { it.key.wireName },
    )
}

object PrivacyAnalytics {
    private const val PREFS = "airclip_private_analytics"
    private const val LAST_UPLOAD = "last_upload"
    private const val FIRST_TRANSFER_RECORDED = "first_transfer_recorded"
    private const val ENDPOINT = "https://airclip-silk.vercel.app/api/analytics"

    fun record(context: Context, event: AnalyticsEvent) {
        if (!Prefs.analyticsEnabled) return
        val sp = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        if (event == AnalyticsEvent.FIRST_TRANSFER && sp.getBoolean(FIRST_TRANSFER_RECORDED, false)) return
        sp.edit()
            .putInt(event.wireName, sp.getInt(event.wireName, 0) + 1)
            .apply {
                if (event == AnalyticsEvent.FIRST_TRANSFER) putBoolean(FIRST_TRANSFER_RECORDED, true)
            }
            .apply()
    }

    fun setEnabled(context: Context, enabled: Boolean) {
        Prefs.analyticsEnabled = enabled
        if (!enabled) context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().clear().apply()
    }

    fun flushIfDue(context: Context, client: OkHttpClient) {
        if (!Prefs.analyticsEnabled) return
        val sp = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val now = System.currentTimeMillis()
        if (!UpdatePolicy.shouldCheck(now, sp.getLong(LAST_UPLOAD, 0L))) return
        val counts = AnalyticsEvent.entries.associateWith { sp.getInt(it.wireName, 0) }.filterValues { it > 0 }
        if (counts.isEmpty()) return

        val body = Gson().toJson(
            AnalyticsPayload.create(BuildConfig.VERSION_NAME, Build.VERSION.RELEASE.substringBefore('.'), counts)
        ).toRequestBody("application/json".toMediaType())
        val request = Request.Builder().url(ENDPOINT).post(body).build()
        runCatching { client.newCall(request).execute().use { require(it.isSuccessful) } }
            .onSuccess {
                val editor = sp.edit().putLong(LAST_UPLOAD, now)
                counts.keys.forEach { editor.remove(it.wireName) }
                editor.apply()
            }
    }
}
