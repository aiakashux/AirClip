package com.airclip.airclip.widget

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.view.View
import android.widget.RemoteViews
import com.airclip.airclip.R

/**
 * AirClip home-screen widget (4×1).
 *
 * Four visual states driven by [WidgetState]:
 *
 *   NO_DEVICES    — grey dot  | "No devices nearby"  | "Same WiFi needed"
 *   SYNCED        — green dot | "AirClip in sync"        | "2 min ago"
 *   PENDING       — blue dot  | "New from Mac"        | preview  | [Paste]
 *   READY_TO_SEND — accent    | "Ready to sync"       |           | [Send]
 *
 * Tap actions:
 *   [Paste] — re-writes last received text to clipboard (already there, confirms)
 *   [Send]  — launches ClipboardSendActivity (transparent) to read + send clipboard
 */
class AirClipWidget : AppWidgetProvider() {

    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        ids.forEach { buildAndUpdate(context, manager, it) }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)   // handles ACTION_APPWIDGET_UPDATE etc.
        when (intent.action) {
            ACTION_PASTE -> handlePaste(context)
            ACTION_SEND  -> handleSend(context)
        }
    }

    // ------------------------------------------------------------------
    // Action handlers
    // ------------------------------------------------------------------

    private fun handlePaste(context: Context) {
        val text = WidgetState.getLastText(context)
        if (text.isNotBlank()) {
            val cm = context.getSystemService(Context.CLIPBOARD_SERVICE)
                as android.content.ClipboardManager
            cm.setPrimaryClip(android.content.ClipData.newPlainText("AirClip", text))
        }
        // Transition widget back to synced
        WidgetState.save(context, WidgetState.SYNCED)
        WidgetState.notifyWidgets(context)
    }

    private fun handleSend(context: Context) {
        // Launch transparent Activity — the only way to read clipboard on Android 10+
        val launch = Intent(context, ClipboardSendActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        context.startActivity(launch)
    }

    // ------------------------------------------------------------------
    // RemoteViews builder
    // ------------------------------------------------------------------

    companion object {
        const val ACTION_PASTE = "com.airclip.airclip.WIDGET_PASTE"
        const val ACTION_SEND  = "com.airclip.airclip.WIDGET_SEND"

        // Dot colours matching AirClip's design tokens
        private val COLOR_GREEN  = Color.parseColor("#59D499")
        private val COLOR_BLUE   = Color.parseColor("#56C2FF")
        private val COLOR_ACCENT = Color.parseColor("#5647F2")
        private val COLOR_GREY   = Color.parseColor("#848484")
        private val COLOR_YELLOW = Color.parseColor("#FFC531")

        fun buildAndUpdate(context: Context, manager: AppWidgetManager, widgetId: Int) {
            val views = buildViews(context)
            manager.updateAppWidget(widgetId, views)
        }

        private fun buildViews(context: Context): RemoteViews {
            val views   = RemoteViews(context.packageName, R.layout.widget_airclip)
            val state   = WidgetState.getState(context)
            val preview = WidgetState.getPreview(context)
            val syncMs  = WidgetState.getLastSyncMs(context)

            when (state) {
                WidgetState.NO_DEVICES -> {
                    views.setInt(R.id.widget_dot, "setBackgroundColor", COLOR_GREY)
                    views.setTextViewText(R.id.widget_primary,   "No devices nearby")
                    views.setTextViewText(R.id.widget_secondary, "Same WiFi needed")
                    views.setViewVisibility(R.id.widget_secondary,   View.VISIBLE)
                    views.setViewVisibility(R.id.widget_action_btn,  View.GONE)
                    clearPendingIntents(views, context)
                }

                WidgetState.SYNCED -> {
                    val elapsed = WidgetState.elapsedLabel(syncMs)
                    views.setInt(R.id.widget_dot, "setBackgroundColor", COLOR_GREEN)
                    views.setTextViewText(R.id.widget_primary,   "AirClip in sync")
                    views.setTextViewText(R.id.widget_secondary, elapsed)
                    views.setViewVisibility(R.id.widget_secondary,  if (elapsed.isNotEmpty()) View.VISIBLE else View.GONE)
                    views.setViewVisibility(R.id.widget_action_btn, View.GONE)
                    clearPendingIntents(views, context)
                }

                WidgetState.PENDING -> {
                    views.setInt(R.id.widget_dot, "setBackgroundColor", COLOR_BLUE)
                    views.setTextViewText(R.id.widget_primary,   "New from Mac")
                    views.setTextViewText(R.id.widget_secondary,
                        if (preview.isNotEmpty()) "\"${preview.take(30)}${if (preview.length > 30) "…" else ""}\"" else "")
                    views.setViewVisibility(R.id.widget_secondary,  if (preview.isNotEmpty()) View.VISIBLE else View.GONE)
                    views.setTextViewText(R.id.widget_action_btn,   "Paste")
                    views.setViewVisibility(R.id.widget_action_btn, View.VISIBLE)
                    views.setOnClickPendingIntent(R.id.widget_action_btn, pasteIntent(context))
                }

                WidgetState.READY_TO_SEND -> {
                    views.setInt(R.id.widget_dot, "setBackgroundColor", COLOR_ACCENT)
                    views.setTextViewText(R.id.widget_primary,   "Ready to sync")
                    views.setTextViewText(R.id.widget_secondary, "")
                    views.setViewVisibility(R.id.widget_secondary,  View.GONE)
                    views.setTextViewText(R.id.widget_action_btn,   "Send")
                    views.setViewVisibility(R.id.widget_action_btn, View.VISIBLE)
                    views.setOnClickPendingIntent(R.id.widget_action_btn, sendIntent(context))
                }
            }

            // Root tap → open app
            views.setOnClickPendingIntent(R.id.widget_root, openAppIntent(context))
            return views
        }

        private fun clearPendingIntents(views: RemoteViews, context: Context) {
            // Set no-op intent so stale tap listeners don't fire
            views.setOnClickPendingIntent(R.id.widget_action_btn, openAppIntent(context))
        }

        private fun pasteIntent(context: Context): android.app.PendingIntent {
            val intent = Intent(context, AirClipWidget::class.java).apply { action = ACTION_PASTE }
            return android.app.PendingIntent.getBroadcast(
                context, 0, intent,
                android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
            )
        }

        private fun sendIntent(context: Context): android.app.PendingIntent {
            val intent = Intent(context, AirClipWidget::class.java).apply { action = ACTION_SEND }
            return android.app.PendingIntent.getBroadcast(
                context, 1, intent,
                android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
            )
        }

        private fun openAppIntent(context: Context): android.app.PendingIntent {
            val intent = Intent(context, com.airclip.airclip.MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            return android.app.PendingIntent.getActivity(
                context, 2, intent,
                android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
            )
        }
    }
}
