package com.airclip.airclip

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import com.google.gson.Gson
import com.google.gson.reflect.TypeToken
import kotlinx.coroutines.flow.firstOrNull
import kotlin.math.abs
import kotlin.math.roundToInt

// One DataStore per application — singleton enforced by the delegate.
private val Context.clipHistoryDataStore: DataStore<Preferences>
    by preferencesDataStore(name = "airclip_history")

private val KEY_HISTORY = stringPreferencesKey("history_json")

enum class ClipKind {
    URL, CODE, COLOR, EMAIL, IMAGE, TEXT
}

fun detectClipKind(text: String): ClipKind {
    val t = text.trim()
    if (t.startsWith("http://") || t.startsWith("https://")) return ClipKind.URL
    if (parseClipboardColor(t) != null) return ClipKind.COLOR
    if (t.count { it == '@' } == 1) {
        val parts = t.split("@")
        if (parts.size == 2 && parts[1].contains('.') && !t.contains(' ') && t.length <= 254) {
            return ClipKind.EMAIL
        }
    }
    val imageExts = listOf("png", "jpg", "jpeg", "gif", "webp", "heic", "heif", "bmp", "tif", "tiff")
    val ext = t.substringAfterLast('.', missingDelimiterValue = "").lowercase()
    if (ext in imageExts || t.startsWith("data:image/")) return ClipKind.IMAGE
    return ClipKind.TEXT
}

internal fun parseClipboardColor(text: String): Long? {
    val value = text.trim()
    parseHexColor(value)?.let { return it }

    val rgb = Regex("""(?i)^rgba?\(\s*(\d{1,3})\s*,\s*(\d{1,3})\s*,\s*(\d{1,3})(?:\s*,\s*(0|1|0?\.\d+))?\s*\)$""")
        .matchEntire(value)
    if (rgb != null) {
        val channels = rgb.groupValues.drop(1).take(3).map(String::toInt)
        if (channels.any { it !in 0..255 }) return null
        val alpha = rgb.groupValues[4].takeIf(String::isNotEmpty)?.toFloatOrNull() ?: 1f
        if (alpha !in 0f..1f) return null
        return argb((alpha * 255).roundToInt(), channels[0], channels[1], channels[2])
    }

    val hsl = Regex("""(?i)^hsla?\(\s*(-?\d+(?:\.\d+)?)\s*,\s*(\d+(?:\.\d+)?)%\s*,\s*(\d+(?:\.\d+)?)%(?:\s*,\s*(0|1|0?\.\d+))?\s*\)$""")
        .matchEntire(value) ?: return null
    val saturation = hsl.groupValues[2].toFloatOrNull()?.div(100f) ?: return null
    val lightness = hsl.groupValues[3].toFloatOrNull()?.div(100f) ?: return null
    val alpha = hsl.groupValues[4].takeIf(String::isNotEmpty)?.toFloatOrNull() ?: 1f
    if (saturation !in 0f..1f || lightness !in 0f..1f || alpha !in 0f..1f) return null

    val hue = ((hsl.groupValues[1].toFloat() % 360f) + 360f) % 360f
    val chroma = (1f - abs(2f * lightness - 1f)) * saturation
    val x = chroma * (1f - abs((hue / 60f) % 2f - 1f))
    val (r1, g1, b1) = when {
        hue < 60f -> Triple(chroma, x, 0f)
        hue < 120f -> Triple(x, chroma, 0f)
        hue < 180f -> Triple(0f, chroma, x)
        hue < 240f -> Triple(0f, x, chroma)
        hue < 300f -> Triple(x, 0f, chroma)
        else -> Triple(chroma, 0f, x)
    }
    val m = lightness - chroma / 2f
    return argb(
        (alpha * 255).roundToInt(),
        ((r1 + m) * 255).roundToInt(),
        ((g1 + m) * 255).roundToInt(),
        ((b1 + m) * 255).roundToInt(),
    )
}

private fun parseHexColor(text: String): Long? {
    val prefixed = text.startsWith("#") || text.startsWith("0x", ignoreCase = true)
    val hex = when {
        text.startsWith("#") -> text.drop(1)
        text.startsWith("0x", ignoreCase = true) -> text.drop(2)
        else -> text
    }
    if (hex.length !in setOf(3, 4, 6, 8) || hex.any { it.digitToIntOrNull(16) == null }) return null
    if (!prefixed && (hex.length !in setOf(6, 8) || hex.none { it.lowercaseChar() in 'a'..'f' })) return null

    val expanded = if (hex.length <= 4) hex.flatMap { listOf(it, it) }.joinToString("") else hex
    val raw = expanded.toLong(16)
    return if (expanded.length == 6) 0xFF000000L or raw else if (text.startsWith("0x", ignoreCase = true)) {
        raw
    } else {
        val alpha = raw and 0xFF
        (alpha shl 24) or (raw ushr 8)
    }
}

private fun argb(alpha: Int, red: Int, green: Int, blue: Int): Long =
    (alpha.toLong() shl 24) or (red.toLong() shl 16) or (green.toLong() shl 8) or blue.toLong()

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
    val preview: String,      // first 40 chars — UI display only; NEVER logged
    val contentText: String? = null, // full plaintext for local clipboard/history actions; NEVER logged
    val kind: String = ClipKind.TEXT.name,
    val imageDataBase64: String? = null,
    val imageFileName: String? = null,
    val isSaved: Boolean = false,
) {
    val displayText: String
        get() = contentText ?: preview
}

/**
 * Persists clipboard history across process kills. Unsaved items are bounded by both
 * [MAX_ITEMS] count and the configured history depth; saved items are retained until explicitly removed.
 *
 * All public functions are suspend and safe to call from IO coroutines.
 */
object ClipHistoryStore {
    private val gson     = Gson()
    private val listType = object : TypeToken<List<ClipItemRecord>>() {}.type

    const val MAX_ITEMS = 500
    internal const val RECONCILIATION_WINDOW_MS = 2_000L
    internal const val MAX_PERSISTED_TEXT_CHARS = 16_384
    internal const val MAX_HISTORY_JSON_CHARS = 8_000_000

    internal fun deduplicate(items: List<ClipItemRecord>): List<ClipItemRecord> {
        val deduplicated = mutableListOf<ClipItemRecord>()
        for (record in items) {
            val existingIndex = deduplicated.indexOfFirst { existing ->
                existing.messageId == record.messageId ||
                    (
                        (existing.kind == ClipKind.IMAGE.name || record.kind == ClipKind.IMAGE.name) &&
                            existing.cipherHash == record.cipherHash
                    ) ||
                    (
                        existing.fromDeviceId == record.fromDeviceId &&
                            existing.cipherHash == record.cipherHash &&
                            kotlin.math.abs(existing.timestampMs - record.timestampMs) <=
                                RECONCILIATION_WINDOW_MS
                    )
            }
            if (existingIndex < 0) {
                deduplicated += record
            } else {
                val existing = deduplicated[existingIndex]
                val shouldPreserveSaved = record.isSaved && !existing.isSaved
                val shouldPreserveFullText = existing.contentText == null && record.contentText != null
                val shouldPreserveImage = existing.imageFileName == null && record.imageFileName != null
                if (shouldPreserveSaved || shouldPreserveFullText || shouldPreserveImage) {
                    deduplicated[existingIndex] = existing.copy(
                        isSaved = existing.isSaved || record.isSaved,
                        contentText = existing.contentText ?: record.contentText,
                        imageDataBase64 = existing.imageDataBase64 ?: record.imageDataBase64,
                        imageFileName = existing.imageFileName ?: record.imageFileName,
                    )
                }
            }
        }
        return deduplicated
    }

    internal fun prepareForStorage(items: List<ClipItemRecord>): List<ClipItemRecord> =
        items.map { record ->
            val trimmedContent = record.contentText?.take(MAX_PERSISTED_TEXT_CHARS)
            record.copy(
                contentText = trimmedContent,
                preview = record.preview.take(120),
                imageDataBase64 = null,
            )
        }

    /**
     * Drop unsaved items older than the configured history depth, sort newest-first by [ClipItemRecord.timestampMs],
     * then cap unsaved items around saved clips. Saved clips can temporarily exceed [MAX_ITEMS].
     */
    private fun prune(
        items: List<ClipItemRecord>,
        now: Long = System.currentTimeMillis()
    ): List<ClipItemRecord> {
        val sorted = items.sortedByDescending { it.timestampMs }
        val saved = sorted.filter { it.isSaved }
        val unsavedSlots = (MAX_ITEMS - saved.size).coerceAtLeast(0)
        val retentionDays = if (Prefs.isInitialized) {
            Prefs.historyRetentionDays[Prefs.historyDepth]
        } else {
            30
        }
        val cutoff = if (retentionDays > 0) {
            now - retentionDays * 24L * 60L * 60L * 1000L
        } else {
            Long.MIN_VALUE
        }
        val unsaved = sorted
            .filter { !it.isSaved && it.timestampMs >= cutoff }
            .take(unsavedSlots)

        return (saved + unsaved).sortedByDescending { it.timestampMs }
    }

    /**
     * Load persisted items from disk, pruned by age and count.
     * Returns empty list on first run, parse error, or if all items have expired.
     */
    suspend fun load(context: Context): List<ClipItemRecord> {
        val prefs = context.clipHistoryDataStore.data.firstOrNull() ?: return emptyList()
        val json  = prefs[KEY_HISTORY] ?: return emptyList()
        if (json.length > MAX_HISTORY_JSON_CHARS) {
            context.clipHistoryDataStore.edit { it.remove(KEY_HISTORY) }
            return emptyList()
        }
        val raw   = try {
            gson.fromJson<List<ClipItemRecord>>(json, listType) ?: emptyList()
        } catch (_: Exception) {
            emptyList()
        }
        val loaded = runCatching {
            prepareForStorage(prune(deduplicate(raw.mapNotNull(::sanitize))))
        }.getOrDefault(emptyList())
        ImageClipboard.prunePersisted(context, loaded)
        return loaded
    }

    /**
     * Merge [newItems] into the persisted list:
     *   1. combine existing + new
     *   2. deduplicate by messageId or matching source/content within the
     *      transport reconciliation window (existing wins on conflict)
     *   3. drop unsaved items older than the configured history depth
     *   4. sort by timestampMs descending (newest first)
     *   5. trim unsaved items to [MAX_ITEMS], protecting saved clips
     *
     * Returns the updated list.
     */
    suspend fun merge(context: Context, newItems: List<ClipItemRecord>): List<ClipItemRecord> {
        val existing = load(context)
        val savedById = existing.associateBy { it.messageId }.mapValues { it.value.isSaved }
        val persistedNewItems = newItems.map { ImageClipboard.persist(context, it) }
        val merged = prepareForStorage(
            prune(
                deduplicate(existing + persistedNewItems)
                    .map { record ->
                        record.copy(isSaved = savedById[record.messageId] == true || record.isSaved)
                    }
            )
        )
        context.clipHistoryDataStore.edit { prefs ->
            prefs[KEY_HISTORY] = gson.toJson(merged)
        }
        ImageClipboard.prunePersisted(context, merged)
        return merged
    }

    /** Toggle saved state for a single item. */
    suspend fun setSaved(context: Context, messageId: String, saved: Boolean): List<ClipItemRecord> {
        val existing = load(context)
        val updated = existing.map { if (it.messageId == messageId) it.copy(isSaved = saved) else it }
        context.clipHistoryDataStore.edit { prefs ->
            prefs[KEY_HISTORY] = gson.toJson(prune(updated))
        }
        val pruned = prune(updated)
        ImageClipboard.prunePersisted(context, pruned)
        return pruned
    }

    /**
     * Remove a single item by [messageId] from both the persisted store and the returned list.
     * Returns the updated list (empty list if the item was the last one).
     * No-op (returns current list) if the messageId is not found.
     */
    suspend fun remove(context: Context, messageId: String): List<ClipItemRecord> {
        val existing = load(context)
        val updated  = existing.filter { it.messageId != messageId }
        if (updated.size == existing.size) return existing  // nothing changed
        context.clipHistoryDataStore.edit { prefs ->
            if (updated.isEmpty()) prefs.remove(KEY_HISTORY)
            else prefs[KEY_HISTORY] = gson.toJson(updated)
        }
        ImageClipboard.prunePersisted(context, updated)
        return updated
    }

    suspend fun pruneToRetention(context: Context, days: Int): List<ClipItemRecord> {
        val existing = load(context)
        if (days <= 0) return existing

        val cutoff = System.currentTimeMillis() - days * 24L * 60L * 60L * 1000L
        val updated = existing.filter { it.isSaved || it.timestampMs >= cutoff }
        context.clipHistoryDataStore.edit { prefs ->
            if (updated.isEmpty()) prefs.remove(KEY_HISTORY)
            else prefs[KEY_HISTORY] = gson.toJson(updated)
        }
        ImageClipboard.prunePersisted(context, updated)
        return updated
    }

    /** Clear persisted history from disk (called on logout or device session reset). */
    suspend fun clear(context: Context) {
        context.clipHistoryDataStore.edit { it.remove(KEY_HISTORY) }
        ImageClipboard.clearPersisted(context)
    }

    private fun sanitize(record: ClipItemRecord): ClipItemRecord? = runCatching {
        val messageId = record.messageId.takeIf { it.isNotBlank() } ?: return null
        val fromDeviceId = record.fromDeviceId.takeIf { it.isNotBlank() } ?: "unknown"
        val timestampMs = record.timestampMs.takeIf { it > 0L } ?: System.currentTimeMillis()
        val preview = record.preview
        val kind = runCatching { ClipKind.valueOf(record.kind) }
            .getOrElse { detectClipKind(record.displayText) }
            .let { if (it == ClipKind.CODE) ClipKind.TEXT else it }
        record.copy(
            messageId = messageId,
            fromDeviceId = fromDeviceId,
            timestampMs = timestampMs,
            preview = preview,
            contentText = record.contentText,
            kind = kind.name,
            cipherHash = record.cipherHash.takeIf { it.isNotBlank() } ?: record.displayText.hashCode().toString(),
        )
    }.getOrNull()
}
