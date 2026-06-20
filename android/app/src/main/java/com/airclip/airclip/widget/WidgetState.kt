package com.airclip.airclip.widget

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent

private const val PREFS_NAME      = "airclip_widget"
private const val KEY_STATE       = "state"
private const val KEY_PREVIEW     = "preview"
private const val KEY_LAST_TEXT   = "last_text"   // full text for re-paste (capped at 1 000 chars)
private const val KEY_LAST_SYNC   = "last_sync_ms"

/**
 * Widget state constants + SharedPreferences helpers.
 *
 * States:
 *   NO_DEVICES    — no LAN peer connected (show "No devices nearby")
 *   SYNCED        — last action completed (show "AirClip in sync" + elapsed time)
 *   PENDING       — inbound clip waiting to be pasted (show preview + Paste button)
 *   READY_TO_SEND — outbound clip on clipboard (show "Ready to sync" + Send button)
 */
object WidgetState {
    const val NO_DEVICES    = "no_devices"
    const val SYNCED        = "synced"
    const val PENDING       = "pending"
    const val READY_TO_SEND = "ready_to_send"

    // ------------------------------------------------------------------
    // Persistence
    // ------------------------------------------------------------------

    /**
     * Save widget state and optionally a preview / full text.
     * Call [notifyWidgets] separately to push the update to the home screen.
     */
    fun save(
        context: Context,
        state:    String,
        preview:  String? = null,
        lastText: String? = null,
    ) {
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE).edit().apply {
            putString(KEY_STATE, state)
            if (preview  != null) putString(KEY_PREVIEW,   preview)
            if (lastText != null) putString(KEY_LAST_TEXT,  lastText.take(1_000))
            if (state == SYNCED) putLong(KEY_LAST_SYNC, System.currentTimeMillis())
        }.apply()
    }

    fun getState(context: Context): String =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getString(KEY_STATE, NO_DEVICES) ?: NO_DEVICES

    fun getPreview(context: Context): String =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getString(KEY_PREVIEW, "") ?: ""

    fun getLastText(context: Context): String =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getString(KEY_LAST_TEXT, "") ?: ""

    fun getLastSyncMs(context: Context): Long =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getLong(KEY_LAST_SYNC, 0L)

    // ------------------------------------------------------------------
    // Widget refresh
    // ------------------------------------------------------------------

    /**
     * Trigger [AppWidgetManager] to call [AirClipWidget.onUpdate], which redraws
     * all home-screen instances. No-op if no widget is placed.
     */
    fun notifyWidgets(context: Context) {
        val manager = AppWidgetManager.getInstance(context)
        val ids     = manager.getAppWidgetIds(ComponentName(context, AirClipWidget::class.java))
        if (ids.isEmpty()) return
        val intent = Intent(context, AirClipWidget::class.java).apply {
            action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
        }
        context.sendBroadcast(intent)
    }

    // ------------------------------------------------------------------
    // Human-readable elapsed time
    // ------------------------------------------------------------------

    fun elapsedLabel(syncMs: Long): String {
        if (syncMs == 0L) return ""
        val diff = System.currentTimeMillis() - syncMs
        return when {
            diff < 60_000      -> "just now"
            diff < 3_600_000   -> "${diff / 60_000} min ago"
            diff < 86_400_000  -> "${diff / 3_600_000} hr ago"
            else               -> "earlier"
        }
    }
}
