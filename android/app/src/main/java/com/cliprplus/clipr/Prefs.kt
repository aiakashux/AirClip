package com.cliprplus.clipr

import android.content.Context
import android.content.SharedPreferences

private const val PREFS_NAME   = "cliprplus_prefs"
private const val KEY_BASE_URL = "server_url"
private const val KEY_EMAIL    = "email"
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

    /** Remove all persisted UI preferences, reverting to defaults. */
    fun clearAll() {
        sp.edit().remove(KEY_BASE_URL).remove(KEY_EMAIL).apply()
    }
}
