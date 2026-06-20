package com.airclip.airclip

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.graphics.BitmapFactory
import android.util.Base64
import androidx.core.content.FileProvider
import java.io.File

object ImageClipboard {
    fun decode(imageDataBase64: String?) =
        imageDataBase64
            ?.let { runCatching { Base64.decode(it, Base64.DEFAULT) }.getOrNull() }
            ?.let { bytes -> BitmapFactory.decodeByteArray(bytes, 0, bytes.size) }

    fun copy(context: Context, record: ClipItemRecord): Boolean {
        val bytes = record.imageDataBase64
            ?.let { runCatching { Base64.decode(it, Base64.DEFAULT) }.getOrNull() }
            ?: return false
        if (BitmapFactory.decodeByteArray(bytes, 0, bytes.size) == null) return false

        val directory = File(context.cacheDir, "shared_images").apply { mkdirs() }
        val file = File(directory, "${record.messageId}.png")
        file.writeBytes(bytes)

        val uri = FileProvider.getUriForFile(
            context,
            "${context.packageName}.files",
            file,
        )
        val clip = ClipData.newUri(context.contentResolver, record.displayText, uri).apply {
            description.extras = android.os.PersistableBundle().apply {
                putString("airclip_kind", ClipKind.IMAGE.name)
            }
        }
        val manager = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        manager.setPrimaryClip(clip)
        return true
    }
}
