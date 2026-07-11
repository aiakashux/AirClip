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
private const val KEY_SENSITIVE_MASTER_RULE = "sensitive_rule_master"
private const val KEY_SENSITIVE_RULE_PREFIX = "sensitive_rule_"
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
    val historyRetentionDays = listOf(1, 3, 7, 15, 30, 0)

    private lateinit var sp: SharedPreferences
    val isInitialized: Boolean
        get() = ::sp.isInitialized

    fun init(context: Context) {
        sp = context.applicationContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
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
            val stored = sp.getInt(KEY_HISTORY_DEPTH, 4)
            if (sp.getInt(KEY_HISTORY_DEPTH_VERSION, 1) < 2) {
                val migrated = when (stored.coerceIn(0, 3)) {
                    0 -> 2 // 7 days
                    1 -> 4 // 30 days
                    2 -> 4 // closest available to legacy 90 days
                    else -> 5 // Forever
                }
                sp.edit()
                    .putInt(KEY_HISTORY_DEPTH, migrated)
                    .putInt(KEY_HISTORY_DEPTH_VERSION, 2)
                    .apply()
                return migrated
            }
            return stored.coerceIn(0, historyRetentionDays.lastIndex)
        }
        set(value) {
            sp.edit()
                .putInt(KEY_HISTORY_DEPTH, value.coerceIn(0, historyRetentionDays.lastIndex))
                .putInt(KEY_HISTORY_DEPTH_VERSION, 2)
                .apply()
        }

    var sensitiveMasterRule: SensitiveRuleAction
        get() = SensitiveRuleAction.fromStoredValue(sp.getString(KEY_SENSITIVE_MASTER_RULE, null))
        set(value) { sp.edit().putString(KEY_SENSITIVE_MASTER_RULE, value.name).apply() }

    fun sensitiveRule(category: SensitiveCategory): SensitiveRuleAction =
        if (sensitiveMasterRule == SensitiveRuleAction.ALLOW) {
            SensitiveRuleAction.ALLOW
        } else {
            SensitiveRuleAction.fromStoredValue(
                sp.getString("$KEY_SENSITIVE_RULE_PREFIX${category.name}", null)
            )
        }

    fun setSensitiveRule(category: SensitiveCategory, action: SensitiveRuleAction) {
        sp.edit()
            .putString("$KEY_SENSITIVE_RULE_PREFIX${category.name}", action.name)
            .apply()
    }

    fun sensitiveRules(): Map<SensitiveCategory, SensitiveRuleAction> =
        SensitiveCategory.entries.associateWith(::sensitiveRule)

    /** Remove all persisted UI preferences, reverting to defaults. */
    fun clearAll() {
        val editor = sp.edit()
            .remove(KEY_BASE_URL)
            .remove(KEY_EMAIL)
            .remove(KEY_SYNC_MODE)
            .remove(KEY_APPEARANCE)
            .remove(KEY_HISTORY_DEPTH)
            .remove(KEY_HISTORY_DEPTH_VERSION)
            .remove(KEY_SENSITIVE_MASTER_RULE)
        SensitiveCategory.entries.forEach {
            editor.remove("$KEY_SENSITIVE_RULE_PREFIX${it.name}")
        }
        editor.apply()
    }
}
