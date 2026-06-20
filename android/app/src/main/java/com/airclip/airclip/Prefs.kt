package com.airclip.airclip

import android.content.Context
import android.content.SharedPreferences

private const val PREFS_NAME   = "airclip_prefs"
private const val KEY_BASE_URL = "server_url"
private const val KEY_EMAIL    = "email"
private const val KEY_SYNC_MODE = "sync_mode"
private const val KEY_SENSITIVE_RULE_PREFIX = "sensitive_rule_"
private const val DEFAULT_URL  = "http://10.0.2.2:8000"

/**
 * Thin SharedPreferences wrapper for non-sensitive UI state that survives
 * process restarts (server URL and email address — never tokens or keys).
 *
 * Call [init] once in [MainViewModel]'s init block before reading properties.
 */
object Prefs {
    private lateinit var sp: SharedPreferences

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

    fun sensitiveRule(category: SensitiveCategory): SensitiveRuleAction =
        SensitiveRuleAction.fromStoredValue(
            sp.getString("$KEY_SENSITIVE_RULE_PREFIX${category.name}", null)
        )

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
        SensitiveCategory.entries.forEach {
            editor.remove("$KEY_SENSITIVE_RULE_PREFIX${it.name}")
        }
        editor.apply()
    }
}
