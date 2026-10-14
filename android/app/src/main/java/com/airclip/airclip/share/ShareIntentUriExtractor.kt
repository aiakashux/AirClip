package com.airclip.airclip.share

import android.content.Intent
import android.net.Uri

internal object ShareIntentUriExtractor {
    fun extract(intent: Intent): List<Uri> {
        val candidates = mutableListOf<Uri>()
        intent.data?.let(candidates::add)

        @Suppress("DEPRECATION")
        runCatching { intent.extras?.get(Intent.EXTRA_STREAM) }
            .getOrNull()
            .let { collectUris(it, candidates) }
        runCatching { intent.getCharSequenceExtra(Intent.EXTRA_TEXT) }
            .getOrNull()
            ?.toString()
            ?.toSharedFileUri()
            ?.let(candidates::add)

        intent.clipData?.let { clipData ->
            for (index in 0 until clipData.itemCount) {
                val item = clipData.getItemAt(index)
                item.uri?.let(candidates::add)
                item.intent?.data?.let(candidates::add)
                item.text?.toString()?.toSharedFileUri()?.let(candidates::add)
            }
        }

        return candidates
            .filter { it.isReadableFileUri() }
            .distinctBy(Uri::toString)
    }

    private fun collectUris(value: Any?, destination: MutableList<Uri>) {
        when (value) {
            null -> Unit
            is Uri -> destination += value
            is Intent -> value.data?.let(destination::add)
            is CharSequence -> value.toString().toSharedFileUri()?.let(destination::add)
            is Iterable<*> -> value.forEach { collectUris(it, destination) }
            is Array<*> -> value.forEach { collectUris(it, destination) }
        }
    }

    private fun String.toSharedFileUri(): Uri? {
        val candidate = trim()
        if (candidate.isEmpty()) return null
        return runCatching { Uri.parse(candidate) }
            .getOrNull()
            ?.takeIf { it.isReadableFileUri() }
    }

    private fun Uri.isReadableFileUri(): Boolean = when (scheme?.lowercase()) {
        "content", "file", "android.resource" -> true
        null -> path?.startsWith('/') == true
        else -> false
    }
}
