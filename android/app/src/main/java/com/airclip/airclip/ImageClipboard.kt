package com.airclip.airclip

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.graphics.BitmapFactory
import android.util.Base64
import androidx.core.content.FileProvider
import com.airclip.airclip.util.Hash
import java.io.File

object ImageClipboard {
    private const val IMAGE_DIRECTORY = "clip_images"
    private val persistedNamePattern = Regex("[a-f0-9]{64}\\.img")

    fun decode(imageDataBase64: String?) =
        imageDataBase64
            ?.let { runCatching { Base64.decode(it, Base64.DEFAULT) }.getOrNull() }
            ?.let { bytes -> BitmapFactory.decodeByteArray(bytes, 0, bytes.size) }

    fun decode(context: Context, record: ClipItemRecord) =
        decode(record.imageDataBase64)
            ?: persistedFile(context, record.imageFileName)?.let { BitmapFactory.decodeFile(it.path) }

    fun persist(context: Context, record: ClipItemRecord): ClipItemRecord {
        if (record.kind != ClipKind.IMAGE.name || record.imageDataBase64 == null) return record
        val bytes = runCatching { Base64.decode(record.imageDataBase64, Base64.DEFAULT) }.getOrNull()
            ?: return record
        if (BitmapFactory.decodeByteArray(bytes, 0, bytes.size) == null) return record

        return runCatching {
            val directory = persistedDirectory(context)
            val fileName = "${Hash.sha256Hex(record.messageId)}.img"
            val target = File(directory, fileName)
            val temporary = File(directory, "$fileName.tmp")
            temporary.writeBytes(bytes)
            check(temporary.renameTo(target) || run {
                target.delete()
                temporary.renameTo(target)
            })
            record.copy(imageFileName = fileName)
        }.getOrDefault(record)
    }

    fun withInlineData(context: Context, record: ClipItemRecord): ClipItemRecord {
        if (record.imageDataBase64 != null || record.kind != ClipKind.IMAGE.name) return record
        val bytes = persistedFile(context, record.imageFileName)?.readBytes() ?: return record
        return record.copy(imageDataBase64 = Base64.encodeToString(bytes, Base64.NO_WRAP))
    }

    fun copy(context: Context, record: ClipItemRecord): Boolean {
        val bytes = record.imageDataBase64
            ?.let { runCatching { Base64.decode(it, Base64.DEFAULT) }.getOrNull() }
            ?: persistedFile(context, record.imageFileName)?.readBytes()
            ?: return false
        if (BitmapFactory.decodeByteArray(bytes, 0, bytes.size) == null) return false

        val directory = File(context.cacheDir, "shared_images").apply { mkdirs() }
        val file = File(directory, "${Hash.sha256Hex(record.messageId)}.png")
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

    fun prunePersisted(context: Context, records: List<ClipItemRecord>) {
        val kept = records.mapNotNullTo(HashSet()) { it.imageFileName }
        persistedDirectory(context).listFiles()?.forEach { file ->
            if (file.name !in kept) file.delete()
        }
    }

    fun clearPersisted(context: Context) {
        persistedDirectory(context).deleteRecursively()
    }

    private fun persistedDirectory(context: Context) =
        File(context.filesDir, IMAGE_DIRECTORY).apply { mkdirs() }

    private fun persistedFile(context: Context, fileName: String?): File? {
        if (fileName == null || !persistedNamePattern.matches(fileName)) return null
        return File(persistedDirectory(context), fileName).takeIf { it.isFile }
    }
}
