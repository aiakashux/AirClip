package com.airclip.airclip

import android.content.Context
import com.google.gson.Gson
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.OkHttpClient
import okhttp3.Request

data class UpdateInfo(
    val versionCode: Int,
    val versionName: String,
    val releaseNotes: String,
    val downloadUrl: String,
)

data class UpdateCheckResult(val update: UpdateInfo? = null, val failed: Boolean = false)

object UpdatePolicy {
    const val DAY_MS = 86_400_000L
    private const val DOWNLOAD_HOST = "airclip-silk.vercel.app"

    fun shouldCheck(nowMs: Long, lastCheckMs: Long): Boolean = nowMs - lastCheckMs >= DAY_MS

    fun isValidUpdate(info: UpdateInfo, installedVersionCode: Int): Boolean {
        val uri = runCatching { java.net.URI(info.downloadUrl) }.getOrNull() ?: return false
        return info.versionCode > installedVersionCode &&
            info.versionName.isNotBlank() && info.releaseNotes.length in 1..500 &&
            uri.scheme == "https" && uri.host == DOWNLOAD_HOST
    }
}

class AppUpdateManager(
    private val context: Context,
    private val client: OkHttpClient,
) {
    private val gson = Gson()

    suspend fun check(force: Boolean = false): UpdateCheckResult = withContext(Dispatchers.IO) {
        val now = System.currentTimeMillis()
        if (!force && !UpdatePolicy.shouldCheck(now, Prefs.lastUpdateCheckMs)) return@withContext UpdateCheckResult()
        Prefs.lastUpdateCheckMs = now
        PrivacyAnalytics.record(context, AnalyticsEvent.UPDATE_CHECK)

        runCatching {
            val request = Request.Builder()
                .url("https://airclip-silk.vercel.app/updates/android/stable.json")
                .header("Accept", "application/json")
                .build()
            client.newCall(request).execute().use { response ->
                require(response.isSuccessful)
                val info = gson.fromJson(requireNotNull(response.body).charStream(), UpdateInfo::class.java)
                info.takeIf { UpdatePolicy.isValidUpdate(it, BuildConfig.VERSION_CODE) }
            }
        }.fold(onSuccess = { info ->
            info?.let { PrivacyAnalytics.record(context, AnalyticsEvent.UPDATE_AVAILABLE) }
            UpdateCheckResult(update = info)
        }, onFailure = {
            PrivacyAnalytics.record(context, AnalyticsEvent.UPDATE_FAILURE)
            UpdateCheckResult(failed = true)
        })
    }
}
