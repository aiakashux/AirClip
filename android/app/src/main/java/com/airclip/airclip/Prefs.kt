package com.airclip.airclip

import android.content.Context
import android.content.SharedPreferences

private const val PREFS_NAME   = "airclip_prefs"
private const val KEY_BASE_URL = "server_url"
private const val KEY_EMAIL    = "email"
private const val KEY_SYNC_MODE = "sync_mode"
private const val KEY_APPEARANCE = "appearance_setting"
private const val KEY_HISTORY_DEPTH = "history_depth"
private const val KEY_HISTORY_DEPTH_VERSION = "history_depth_version"
private const val HISTORY_DEPTH_VERSION = 4
private const val DEFAULT_HISTORY_DEPTH = 2
private const val KEY_ANALYTICS_ENABLED = "analytics_enabled"
private const val KEY_LAST_UPDATE_CHECK = "last_update_check"
private const val DEFAULT_URL  = "http://10.0.2.2:8000"

enum class AppAppearanceSetting(val label: String) {
    SYSTEM("System"),
    LIGHT("Light"),
    DARK("Dark");

    companion object {
        fun fromStoredValue(value: String?): AppAppearanceSetting =
            entries.firstOrNull { it.name == value } ?: SYSTEM
    }
}

/**
 * Thin SharedPreferences wrapper for non-sensitive UI state that survives
 * process restarts (server URL and email address — never tokens or keys).
 *
 * Call [init] once in [MainViewModel]'s init block before reading properties.
 */
object Prefs {
    val historyRetentionDays = listOf(1, 3, 7, 15, 0)

    private lateinit var sp: SharedPreferences
    val isInitialized: Boolean
        get() = ::sp.isInitialized

    fun init(context: Context) {
        sp = context.applicationContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val legacySensitiveKeys = sp.all.keys.filter { it.startsWith("sensitive_rule_") }
        if (legacySensitiveKeys.isNotEmpty()) {
            sp.edit().apply {
                legacySensitiveKeys.forEach(::remove)
            }.apply()
        }
    }

    var serverUrl: String
        get() = sp.getString(KEY_BASE_URL, DEFAULT_URL) ?: DEFAULT_URL
        set(value) { sp.edit().putString(KEY_BASE_URL, value).apply() }

    var email: String
        get() = sp.getString(KEY_EMAIL, "") ?: ""
        set(value) { sp.edit().putString(KEY_EMAIL, value).apply() }

    var syncMode: SyncMode
        get() = SyncMode.fromStoredValue(sp.getString(KEY_SYNC_MODE, null))
        set(value) { sp.edit().putString(KEY_SYNC_MODE, value.name).apply() }

    var appearanceSetting: AppAppearanceSetting
        get() = AppAppearanceSetting.fromStoredValue(sp.getString(KEY_APPEARANCE, null))
        set(value) { sp.edit().putString(KEY_APPEARANCE, value.name).apply() }

    var historyDepth: Int
        get() {
            val stored = if (sp.contains(KEY_HISTORY_DEPTH)) {
                sp.getInt(KEY_HISTORY_DEPTH, DEFAULT_HISTORY_DEPTH)
            } else {
                null
            }
            val version = sp.getInt(KEY_HISTORY_DEPTH_VERSION, 1)
            val migrated = migratedHistoryDepth(stored, version)
            if (version < HISTORY_DEPTH_VERSION || stored == null) {
                sp.edit()
                    .putInt(KEY_HISTORY_DEPTH, migrated)
                    .putInt(KEY_HISTORY_DEPTH_VERSION, HISTORY_DEPTH_VERSION)
                    .apply()
            }
            return migrated
        }
        set(value) {
            sp.edit()
                .putInt(KEY_HISTORY_DEPTH, value.coerceIn(0, historyRetentionDays.lastIndex))
                .putInt(KEY_HISTORY_DEPTH_VERSION, HISTORY_DEPTH_VERSION)
                .apply()
        }

    var analyticsEnabled: Boolean
        get() = sp.getBoolean(KEY_ANALYTICS_ENABLED, false)
        set(value) { sp.edit().putBoolean(KEY_ANALYTICS_ENABLED, value).apply() }

    var lastUpdateCheckMs: Long
        get() = sp.getLong(KEY_LAST_UPDATE_CHECK, 0L)
        set(value) { sp.edit().putLong(KEY_LAST_UPDATE_CHECK, value).apply() }

    /** Remove all persisted UI preferences, reverting to defaults. */
    fun clearAll() {
        val editor = sp.edit()
            .remove(KEY_BASE_URL)
            .remove(KEY_EMAIL)
            .remove(KEY_SYNC_MODE)
            .remove(KEY_APPEARANCE)
            .remove(KEY_HISTORY_DEPTH)
            .remove(KEY_HISTORY_DEPTH_VERSION)
            .remove(KEY_ANALYTICS_ENABLED)
            .remove(KEY_LAST_UPDATE_CHECK)
        sp.all.keys.filter { it.startsWith("sensitive_rule_") }.forEach(editor::remove)
        editor.apply()
    }
}

internal fun migratedHistoryDepth(stored: Int?, version: Int): Int {
    if (stored == null) return DEFAULT_HISTORY_DEPTH

    val previousValue = if (version < 2) {
        when (stored.coerceIn(0, 3)) {
            0 -> 2
            else -> 4
        }
    } else {
        stored.coerceIn(0, Prefs.historyRetentionDays.lastIndex)
    }

    return if (version < HISTORY_DEPTH_VERSION && previousValue == 4) {
        DEFAULT_HISTORY_DEPTH
    } else {
        previousValue
    }
}
