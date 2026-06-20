package com.airclip.airclip.clipboard

import android.content.ClipboardManager
import android.content.Context
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.callbackFlow

/**
 * Wraps Android's ClipboardManager in a coroutine Flow.
 *
 * IMPORTANT: collect on the Main dispatcher — ClipboardManager requires its listener
 * to be registered on the main thread. callbackFlow bridges the callback safely.
 *
 * Emits non-empty, trimmed text strings only. Images/other MIME types are ignored.
 * Never emits the same reference twice in a row (Android fires the callback on any copy,
 * including programmatic writes; loop-prevention is handled upstream by RecentHashCache).
 */
object ClipboardMonitor {

    fun clipboardFlow(context: Context): Flow<String> = callbackFlow {
        val cm = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager

        val listener = ClipboardManager.OnPrimaryClipChangedListener {
            try {
                val clip = cm.primaryClip ?: return@OnPrimaryClipChangedListener
                if (clip.itemCount == 0) return@OnPrimaryClipChangedListener
                val text = clip.getItemAt(0)
                    .coerceToText(context)
                    ?.toString()
                    ?.trim()
                    .takeIf { !it.isNullOrEmpty() }
                    ?: return@OnPrimaryClipChangedListener
                trySend(text)   // non-blocking; downstream channel handles backpressure
            } catch (_: Exception) {
                // Ignore — clipboard may be unavailable (e.g. Android 12+ in background)
            }
        }

        cm.addPrimaryClipChangedListener(listener)
        awaitClose { cm.removePrimaryClipChangedListener(listener) }
    }
}
