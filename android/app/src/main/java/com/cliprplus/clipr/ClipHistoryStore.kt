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
 * One persisted clipboard item (received from a peer, or sent locally).
 *
 * [preview] is the first 40 chars of plaintext — UI display only.
 * MUST NOT be passed to any logger.
 */
data class ClipItemRecord(
    val messageId: String,
    val seq: Long,
    val fromDeviceId: String,
    val timestampMs: Long,
    val cipherHash: String,   // sha256 prefix — safe to log
    val preview: String       // first 40 chars — UI display only; NEVER logged
)

/**
 * Persists clipboard history across process kills. Items are bounded by both
 * [MAX_ITEMS] count and [TTL_MS] age — whichever limit triggers first wins.
 *
 * All public functions are suspend and safe to call from IO coroutines.
 */
object ClipHistoryStore {
    private val gson     = Gson()
    private val listType = object : TypeToken<List<ClipItemRecord>>() {}.type

    const val MAX_ITEMS = 20
    const val TTL_MS    = 30 * 60 * 1000L   // 30 minutes

    /**
     * Drop items older than [TTL_MS], sort newest-first by [ClipItemRecord.timestampMs],
     * then cap at [MAX_ITEMS].
     */
    private fun prune(
        items: List<ClipItemRecord>,
        now: Long = System.currentTimeMillis()
    ): List<ClipItemRecord> =
        items
            .filter { now - it.timestampMs <= TTL_MS }
            .sortedByDescending { it.timestampMs }
            .take(MAX_ITEMS)

    /**
     * Load persisted items from disk, pruned by age and count.
     * Returns empty list on first run, parse error, or if all items have expired.
     */
    suspend fun load(context: Context): List<ClipItemRecord> {
        val prefs = context.clipHistoryDataStore.data.firstOrNull() ?: return emptyList()
        val json  = prefs[KEY_HISTORY] ?: return emptyList()
        val raw   = try {
            gson.fromJson<List<ClipItemRecord>>(json, listType) ?: emptyList()
        } catch (_: Exception) {
            emptyList()
        }
        return prune(raw)
    }

    /**
     * Merge [newItems] into the persisted list:
     *   1. combine existing + new
     *   2. deduplicate by messageId (existing wins on conflict)
     *   3. drop items older than [TTL_MS]
     *   4. sort by timestampMs descending (newest first)
     *   5. trim to [MAX_ITEMS]
     *
     * Returns the updated list.
     */
    suspend fun merge(context: Context, newItems: List<ClipItemRecord>): List<ClipItemRecord> {
        val existing = load(context)
        val merged   = prune((existing + newItems).distinctBy { it.messageId })
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
