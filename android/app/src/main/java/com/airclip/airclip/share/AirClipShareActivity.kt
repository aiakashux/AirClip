package com.airclip.airclip.share

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.database.Cursor
import android.net.Uri
import android.os.Bundle
import android.provider.OpenableColumns
import android.util.Base64
import android.widget.Toast
import com.airclip.airclip.AirClipIdentity
import com.airclip.airclip.ManualSendBootstrap
import com.airclip.airclip.Prefs
import com.airclip.airclip.SyncEngine
import com.airclip.airclip.SyncService
import com.airclip.airclip.crypto.KeyManager
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import okhttp3.OkHttpClient
import java.util.concurrent.TimeUnit

private const val MAX_TEXT_BYTES = 256 * 1024

class AirClipShareActivity : Activity() {
    private val scope = CoroutineScope(Dispatchers.IO)

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        Prefs.init(applicationContext)
        scope.launch {
            val result = handleShare(intent)
            withContext(Dispatchers.Main) {
                Toast.makeText(this@AirClipShareActivity, result.message, Toast.LENGTH_SHORT).show()
                finish()
            }
        }
    }

    private suspend fun handleShare(intent: Intent): ShareResult {
        if (intent.action != Intent.ACTION_SEND && intent.action != Intent.ACTION_SEND_MULTIPLE) {
            return ShareResult("AirClip could not read this share.")
        }

        val sharedItems = extractSharedItems(intent)
        if (sharedItems.isEmpty()) {
            return ShareResult("This share type is not supported yet.")
        }
        if (!prepareSyncRuntime()) {
            return ShareResult("AirClip is not ready to share.")
        }

        SyncEngine.markLocalActivity()
        sharedItems.forEach { item ->
            when (item) {
                is SharedItem.Image -> SyncEngine.sendImageClip(item.label, item.imageDataBase64)
                is SharedItem.Text -> SyncEngine.sendClip(item.text, sensitiveOverride = true)
            }
        }
        return ShareResult(
            if (sharedItems.size == 1) "Shared to AirClip" else "Shared ${sharedItems.size} items to AirClip"
        )
    }

    private fun extractSharedItems(intent: Intent): List<SharedItem> {
        val items = mutableListOf<SharedItem>()
        streamUris(intent).forEach { uri ->
            val mimeType = contentResolver.getType(uri) ?: intent.type.orEmpty()
            when {
                mimeType.startsWith("image/") -> imageItem(uri)?.let(items::add)
                mimeType.startsWith("text/") -> textItem(uri)?.let(items::add)
            }
        }

        val text = intent.getStringExtra(Intent.EXTRA_TEXT)
            ?.trim()
            ?.takeIf { it.isNotEmpty() }
        if (items.isEmpty() && text != null) {
            items += SharedItem.Text(text)
        }

        return items
    }

    private fun streamUris(intent: Intent): List<Uri> {
        val extras = when (intent.action) {
            Intent.ACTION_SEND_MULTIPLE -> {
                @Suppress("DEPRECATION")
                intent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM).orEmpty()
            }
            Intent.ACTION_SEND -> {
                @Suppress("DEPRECATION")
                listOfNotNull(intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM))
            }
            else -> emptyList()
        }
        val clipUris = intent.clipData?.let { clipData ->
            (0 until clipData.itemCount).mapNotNull { index -> clipData.getItemAt(index).uri }
        }.orEmpty()
        return (extras + clipUris).distinct()
    }

    private fun imageItem(uri: Uri): SharedItem.Image? {
        val bytes = contentResolver.openInputStream(uri)?.use { it.readBytes() } ?: return null
        val label = displayName(uri) ?: "Shared image"
        return SharedItem.Image(
            label = label,
            imageDataBase64 = Base64.encodeToString(bytes, Base64.NO_WRAP),
        )
    }

    private fun textItem(uri: Uri): SharedItem.Text? {
        val bytes = contentResolver.openInputStream(uri)?.use { stream ->
            val raw = stream.readBytes()
            if (raw.size > MAX_TEXT_BYTES) raw.copyOf(MAX_TEXT_BYTES) else raw
        } ?: return null
        val text = bytes.toString(Charsets.UTF_8).trim()
        return text.takeIf { it.isNotEmpty() }?.let { SharedItem.Text(it) }
    }

    private fun displayName(uri: Uri): String? {
        val cursor: Cursor = contentResolver.query(
            uri,
            arrayOf(OpenableColumns.DISPLAY_NAME),
            null,
            null,
            null,
        ) ?: return null
        return cursor.use {
            if (!it.moveToFirst()) return@use null
            val index = it.getColumnIndex(OpenableColumns.DISPLAY_NAME)
            if (index >= 0) it.getString(index) else null
        }
    }

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
                true
            },
        )
    }
}

private sealed interface SharedItem {
    data class Text(val text: String) : SharedItem
    data class Image(val label: String, val imageDataBase64: String) : SharedItem
}

private data class ShareResult(val message: String)
