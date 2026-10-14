package com.airclip.airclip.share

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.database.Cursor
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.pdf.PdfRenderer
import android.media.MediaMetadataRetriever
import android.util.Size
import android.net.Uri
import android.os.Bundle
import android.os.ParcelFileDescriptor
import android.provider.OpenableColumns
import android.util.Base64
import android.util.Log
import android.widget.Toast
import com.airclip.airclip.AirclipIdentity
import com.airclip.airclip.ManualSendBootstrap
import com.airclip.airclip.Prefs
import com.airclip.airclip.SyncEngine
import com.airclip.airclip.FileClipMetadata
import com.airclip.airclip.SyncService
import com.airclip.airclip.crypto.KeyManager
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import okhttp3.OkHttpClient
import java.util.concurrent.TimeUnit
import java.io.File
import java.io.ByteArrayOutputStream
import java.io.InputStream
import java.util.UUID
import java.util.Locale

private const val MAX_TEXT_BYTES = 256 * 1024

class AirclipShareActivity : Activity() {
    private val scope = CoroutineScope(Dispatchers.IO)

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        Prefs.init(applicationContext)
        scope.launch {
            val result = handleShare(intent)
            withContext(Dispatchers.Main) {
                Toast.makeText(this@AirclipShareActivity, result.message, Toast.LENGTH_SHORT).show()
                finish()
            }
        }
    }

    private suspend fun handleShare(intent: Intent): ShareResult {
        if (intent.action != Intent.ACTION_SEND && intent.action != Intent.ACTION_SEND_MULTIPLE) {
            return ShareResult("Airclip could not read this share.")
        }

        val sharedUris = streamUris(intent)
        val sharedItems = extractSharedItems(intent, sharedUris)
        if (sharedItems.isEmpty()) {
            return ShareResult(
                if (sharedUris.isEmpty()) {
                    "This share type is not supported yet."
                } else {
                    "Airclip could not access this file. Try sharing it from the Files app."
                }
            )
        }
        if (!prepareSyncRuntime()) {
            return ShareResult("Airclip is not ready to share.")
        }

        SyncEngine.markLocalActivity()
        sharedItems.forEach { item ->
            when (item) {
                is SharedItem.Image -> SyncEngine.sendImageClip(item.label, item.imageDataBase64)
                is SharedItem.Text -> SyncEngine.sendClip(item.text)
                is SharedItem.File -> SyncEngine.sendFileClip(item.metadata, item.path)
            }
        }
        return ShareResult(
            if (sharedItems.size == 1) "Shared to Airclip" else "Shared ${sharedItems.size} items to Airclip"
        )
    }

    private fun extractSharedItems(intent: Intent, sharedUris: List<Uri>): List<SharedItem> {
        val items = mutableListOf<SharedItem>()
        sharedUris.forEach { uri ->
            val mimeType = runCatching { contentResolver.getType(uri) }.getOrNull()
                ?: intent.type.orEmpty().takeUnless { it == "*/*" }.orEmpty()
            val extension = displayName(uri)?.substringAfterLast('.', "")?.lowercase(Locale.ROOT)
            val isImage = mimeType.startsWith("image/") || extension in setOf(
                "png", "jpg", "jpeg", "gif", "webp", "heic", "heif", "bmp", "tif", "tiff"
            )
            val item = if (isImage) imageItem(uri) ?: fileItem(uri, mimeType) else fileItem(uri, mimeType)
            item?.let(items::add)
        }

        val text = runCatching { intent.getCharSequenceExtra(Intent.EXTRA_TEXT)?.toString() }
            .getOrNull()
            ?.trim()
            ?.takeIf { it.isNotEmpty() }
        if (items.isEmpty() && text != null) {
            items += SharedItem.Text(text)
        }

        return items
    }

    private fun streamUris(intent: Intent): List<Uri> {
        return ShareIntentUriExtractor.extract(intent)
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

    private fun fileItem(uri: Uri, mimeType: String): SharedItem.File? {
        val id = UUID.randomUUID().toString()
        val directory = File(filesDir, "shared-file-sources").apply { mkdirs() }
        val destination = File(directory, id)
        val copied = runCatching {
            openSharedInputStream(uri)?.use { input ->
                destination.outputStream().buffered().use { output -> input.copyTo(output, 256 * 1024) }
            } ?: return null
        }.onFailure {
            Log.w("AirclipShare", "Could not read shared ${uri.scheme ?: "path"} URI", it)
        }.isSuccess
        if (!copied) {
            destination.delete()
            return null
        }
        val media = if (mimeType.startsWith("audio/") || mimeType.startsWith("video/")) {
            runCatching { MediaMetadataRetriever().apply { setDataSource(destination.absolutePath) } }.getOrNull()
        } else null
        val sharedName = displayName(uri)
        val thumbnail = runCatching {
            val bitmap = contentResolver.loadThumbnail(uri, Size(320, 320), null)
            encodeThumbnail(bitmap)
        }.getOrNull() ?: imageThumbnail(destination, mimeType, sharedName)
            ?: pdfThumbnail(destination, mimeType, sharedName) ?: runCatching {
            val bitmap = media?.embeddedPicture?.let { BitmapFactory.decodeByteArray(it, 0, it.size) }
                ?: if (mimeType.startsWith("video/")) media?.getFrameAtTime(0) else null
            bitmap?.let(::encodeThumbnail)
        }.getOrNull()
        val duration = media?.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)?.toLongOrNull()
        val width = media?.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)?.toIntOrNull()
        val height = media?.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)?.toIntOrNull()
        val artist = media?.extractMetadata(MediaMetadataRetriever.METADATA_KEY_ARTIST)
        val album = media?.extractMetadata(MediaMetadataRetriever.METADATA_KEY_ALBUM)
        media?.release()
        val metadata = FileClipMetadata(
            id = id,
            name = sharedName?.substringAfterLast('/')?.takeIf { it.isNotBlank() } ?: "Shared file",
            size = destination.length(),
            mimeType = mimeType.ifBlank { "application/octet-stream" },
            thumbnailBase64 = thumbnail,
            durationMs = duration,
            width = width,
            height = height,
            artist = artist,
            album = album,
        )
        return SharedItem.File(metadata, destination.absolutePath)
    }

    private fun displayName(uri: Uri): String? {
        if (uri.scheme == "file" || uri.scheme == null) {
            return uri.path?.let(::File)?.name?.takeIf { it.isNotBlank() }
        }
        return runCatching {
            val cursor: Cursor = contentResolver.query(
                uri,
                arrayOf(OpenableColumns.DISPLAY_NAME),
                null,
                null,
                null,
            ) ?: return@runCatching null
            cursor.use {
                if (!it.moveToFirst()) return@use null
                val index = it.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                if (index >= 0) it.getString(index) else null
            }
        }.getOrNull()
    }

    private fun openSharedInputStream(uri: Uri): InputStream? {
        return when (uri.scheme?.lowercase()) {
            "file", null -> uri.path?.let(::File)?.takeIf(File::isFile)?.inputStream()
            else -> contentResolver.openInputStream(uri)
                ?: contentResolver.openFileDescriptor(uri, "r")
                    ?.let(android.os.ParcelFileDescriptor::AutoCloseInputStream)
        }
    }

    private fun imageThumbnail(file: File, mimeType: String, name: String?): String? {
        val extension = name?.substringAfterLast('.', "")?.lowercase().orEmpty()
        if (!mimeType.startsWith("image/") && extension !in setOf(
                "png", "jpg", "jpeg", "gif", "webp", "heic", "heif", "bmp", "tif", "tiff",
            )) return null
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(file.path, bounds)
        if (bounds.outWidth <= 0 || bounds.outHeight <= 0) return null
        var sample = 1
        while (maxOf(bounds.outWidth, bounds.outHeight) / sample > 640) sample *= 2
        val bitmap = BitmapFactory.decodeFile(file.path, BitmapFactory.Options().apply {
            inSampleSize = sample
        }) ?: return null
        return encodeThumbnail(bitmap)
    }

    private fun pdfThumbnail(file: File, mimeType: String, name: String?): String? {
        if (mimeType != "application/pdf" && !name.orEmpty().endsWith(".pdf", ignoreCase = true)) return null
        return runCatching {
            val descriptor = ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY)
            PdfRenderer(descriptor).use { renderer ->
                if (renderer.pageCount == 0) return@use null
                renderer.openPage(0).use { page ->
                    val scale = minOf(1f, 640f / maxOf(page.width, page.height).coerceAtLeast(1))
                    val bitmap = Bitmap.createBitmap(
                        (page.width * scale).toInt().coerceAtLeast(1),
                        (page.height * scale).toInt().coerceAtLeast(1),
                        Bitmap.Config.ARGB_8888,
                    )
                    bitmap.eraseColor(android.graphics.Color.WHITE)
                    page.render(bitmap, null, null, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
                    encodeThumbnail(bitmap)
                }
            }
        }.getOrNull()
    }

    private fun encodeThumbnail(bitmap: Bitmap): String? {
        val scale = minOf(1f, 320f / maxOf(bitmap.width, bitmap.height).coerceAtLeast(1))
        val resized = if (scale < 1f) Bitmap.createScaledBitmap(
            bitmap,
            (bitmap.width * scale).toInt().coerceAtLeast(1),
            (bitmap.height * scale).toInt().coerceAtLeast(1),
            true,
        ) else bitmap
        val output = ByteArrayOutputStream()
        resized.compress(Bitmap.CompressFormat.JPEG, 76, output)
        return output.toByteArray().takeIf { it.size <= 160 * 1024 }
            ?.let { Base64.encodeToString(it, Base64.NO_WRAP) }
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
                AirclipIdentity.loadFromDisk(ctx)
                AirclipIdentity.isPaired
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
    data class File(val metadata: FileClipMetadata, val path: String) : SharedItem
}

private data class ShareResult(val message: String)
