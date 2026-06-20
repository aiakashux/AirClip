package com.airclip.airclip.widget

import android.app.Activity
import android.content.ClipboardManager
import android.content.Context
import android.os.Bundle
import com.airclip.airclip.Prefs
import com.airclip.airclip.AirClipIdentity
import com.airclip.airclip.ManualSendBootstrap
import com.airclip.airclip.SyncEngine
import com.airclip.airclip.SyncService
import com.airclip.airclip.SensitiveClipboardClassifier
import com.airclip.airclip.SensitiveClipboardPolicy
import com.airclip.airclip.SensitiveSendDecision
import com.airclip.airclip.SensitiveSendIntent
import com.airclip.airclip.crypto.KeyManager
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import okhttp3.OkHttpClient
import java.util.concurrent.TimeUnit

/**
 * Transparent, no-UI Activity launched by the widget's "Send" button.
 *
 * Why an Activity? Android 10+ forbids clipboard reads from background contexts
 * (services, broadcast receivers). An Activity briefly gains focus, reads the
 * clipboard, fires the send, then finishes — the user never sees it.
 *
 * Declared with Theme.Translucent.NoTitleBar so it appears invisible.
 */
class ClipboardSendActivity : Activity() {
    private var clipboardHandled = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        Prefs.init(applicationContext)
        if (!Prefs.syncMode.allowsManualSend) {
            finish()
        }
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (!hasFocus || clipboardHandled || isFinishing) return
        clipboardHandled = true
        handleClipboard()
    }

    private fun handleClipboard() {
        // Android 10+ permits clipboard reads only after this Activity has focus.
        val cm   = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        val text = cm.primaryClip
            ?.takeIf { it.itemCount > 0 }
            ?.getItemAt(0)
            ?.coerceToText(this)
            ?.toString()
            ?.trim()

        if (text.isNullOrBlank()) {
            finish()
            return
        }

        val assessment = SensitiveClipboardClassifier.classify(text)
        val action = assessment.primaryFinding
            ?.let { Prefs.sensitiveRule(it.category) }
            ?: com.airclip.airclip.SensitiveRuleAction.ASK
        when (SensitiveClipboardPolicy.decide(
            assessment,
            SensitiveSendIntent.MANUAL,
            action,
        )) {
            SensitiveSendDecision.ALLOW -> send(text, sensitiveOverride = false)
            SensitiveSendDecision.REQUIRE_CONFIRMATION -> {
                val label = assessment.primaryFinding?.category?.label ?: "Sensitive content"
                android.app.AlertDialog.Builder(this)
                    .setTitle("Send sensitive clipboard item?")
                    .setMessage("$label detected. Only continue if you intend to share it with your paired devices.")
                    .setNegativeButton("Cancel") { _, _ -> finish() }
                    .setPositiveButton("Send anyway") { _, _ ->
                        send(text, sensitiveOverride = true)
                    }
                    .setOnCancelListener { finish() }
                    .show()
            }
            SensitiveSendDecision.BLOCK -> finish()
        }
    }

    private fun send(text: String, sensitiveOverride: Boolean) {
        CoroutineScope(Dispatchers.IO).launch {
            if (prepareSyncRuntime()) {
                SyncEngine.sendClip(text, sensitiveOverride)
                WidgetState.save(this@ClipboardSendActivity, WidgetState.SYNCED)
                WidgetState.notifyWidgets(this@ClipboardSendActivity)
            }
        }
        finish()
    }

    /**
     * SyncEngine.init() is normally called by MainViewModel. If this Activity
     * is started without the main app being alive (widget cold-start), we
     * re-hydrate the minimum state needed to send. Safe to call multiple times.
     */
    private suspend fun prepareSyncRuntime(): Boolean {
        val ctx = applicationContext
        val km = KeyManager(application)
        val client = OkHttpClient.Builder()
            .connectTimeout(10, TimeUnit.SECONDS)
            .readTimeout(15, TimeUnit.SECONDS)
            .build()

        return ManualSendBootstrap.prepare(
            mode = Prefs.syncMode,
            loadIdentity = {
                AirClipIdentity.loadFromDisk(ctx)
                AirClipIdentity.isPaired
            },
            loadKeys = {
                km.loadFromDisk()
                km.isInitialized
            },
            initialize = {
                SyncEngine.init(ctx, km, client)
            },
            startRuntime = {
                SyncService.start(ctx)
                SyncEngine.connect()
            },
            awaitPeer = {
                SyncEngine.awaitConnectedPeer()
            },
        )
    }
}
