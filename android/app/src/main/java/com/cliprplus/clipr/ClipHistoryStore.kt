package com.cliprplus.clipr

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import com.google.gson.Gson
import com.google.gson.reflect.TypeToken
import kotlinx.coroutines.flow.firstOrNull

// One DataStore per application — singleton enforced by the delegate.
private val Context.clipHistoryDataStore: DataStore<Preferences>
    by preferencesDataStore(name = "clipr_history")

private val KEY_HISTORY = stringPreferencesKey("history_json")

/**
 * One persisted received clipboard item.
 *
 * [preview] is the first 40 chars of decrypted plaintext — UI display only.
 * MUST NOT be passed to any logger.
 */
data class ClipItemRecord(
    val messageId: String,
    val seq: Long,
    val fromDeviceId: String,
    val timestampMs: Long,
    val cipherHash: String,   // sha256Short — safe to log
    val preview: String       // first 40 chars — UI display only; NEVER logged
)

/**
 * Persists the received clipboard history (up to [MAX_ITEMS] newest items) across
 * process kills. Uses DataStore<Preferences> + Gson — no new dependencies.
 *
 * All public functions are suspend and safe to call from IO coroutines.
 */
object ClipHistoryStore {
    private val gson = Gson()
    private val listType = object : TypeToken<List<ClipItemRecord>>() {}.type

    const val MAX_ITEMS = 20

    /** Load persisted items from disk. Returns empty list on first run or parse error. */
    suspend fun load(context: Context): List<ClipItemRecord> {
        val prefs = context.clipHistoryDataStore.data.firstOrNull() ?: return emptyList()
        val json  = prefs[KEY_HISTORY] ?: return emptyList()
        return try {
            gson.fromJson(json, listType) ?: emptyList()
        } catch (_: Exception) {
            emptyList()
        }
    }

    /**
     * Merge [newItems] into the persisted list:
     *   1. combine existing + new
     *   2. deduplicate by messageId (existing wins on conflict)
     *   3. sort by seq descending (newest first)
     *   4. trim to [MAX_ITEMS]
     *
     * Returns the updated list.
     */
    suspend fun merge(context: Context, newItems: List<ClipItemRecord>): List<ClipItemRecord> {
        val existing = load(context)
        val merged   = (existing + newItems)
            .distinctBy { it.messageId }
            .sortedByDescending { it.seq }
            .take(MAX_ITEMS)
        context.clipHistoryDataStore.edit { prefs ->
            prefs[KEY_HISTORY] = gson.toJson(merged)
        }
        return merged
    }

    /** Clear persisted history from disk (called on logout or device session reset). */
    suspend fun clear(context: Context) {
        context.clipHistoryDataStore.edit { it.remove(KEY_HISTORY) }
    }
}
