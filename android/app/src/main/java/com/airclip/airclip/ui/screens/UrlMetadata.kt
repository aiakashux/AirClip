package com.airclip.airclip.ui.screens

import android.util.LruCache
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.OkHttpClient
import okhttp3.Request
import okio.Buffer
import okio.BufferedSource
import org.jsoup.Jsoup
import org.jsoup.nodes.Document
import java.net.URI
import java.nio.charset.StandardCharsets
import java.util.concurrent.TimeUnit

internal data class UrlMetadata(
    val title: String,
    val site: String,
    val imageUrl: String?,
)

internal object UrlMetadataLoader {
    private const val MAX_HTML_BYTES = 512L * 1024L
    private val webUrlPattern = Regex("""https?://[^\s<>\"']+""", RegexOption.IGNORE_CASE)
    private val cache = LruCache<String, UrlMetadata>(100)
    private val client = OkHttpClient.Builder()
        .callTimeout(6, TimeUnit.SECONDS)
        .build()

    suspend fun load(url: String): UrlMetadata? = withContext(Dispatchers.IO) {
        cache.get(url) ?: fetch(url)?.also { cache.put(url, it) }
    }

    internal fun parse(html: String, baseUrl: String): UrlMetadata? =
        parseDocument(Jsoup.parse(html, baseUrl), baseUrl)

    internal fun urlsIn(text: String): List<String> = webUrlPattern.findAll(text)
        .map { it.value.trimEnd('.', ',', ';', ':', '!', '?', ')', ']', '}') }
        .filter(String::isNotEmpty)
        .toList()

    internal suspend fun firstPreviewWithImage(
        text: String,
        fetchMetadata: suspend (String) -> UrlMetadata? = { load(it) },
    ): Pair<String, UrlMetadata>? {
        for (url in urlsIn(text)) {
            val metadata = fetchMetadata(url) ?: continue
            if (metadata.imageUrl != null) return url to metadata
        }
        return null
    }

    private fun fetch(url: String): UrlMetadata? = runCatching {
        val uri = URI(url)
        if (uri.scheme !in setOf("http", "https") || uri.host.isNullOrBlank()) return null

        val request = Request.Builder()
            .url(url)
            .header("User-Agent", "Airclip/1.0 link preview")
            .build()
        client.newCall(request).execute().use { response ->
            if (!response.isSuccessful) return null
            val body = response.body ?: return null
            val contentType = body.contentType()
            if (contentType?.type != "text" || contentType.subtype != "html") return null
            val bytes = readUpTo(body.source())
            val charset = contentType.charset(StandardCharsets.UTF_8) ?: StandardCharsets.UTF_8
            parse(String(bytes, charset), response.request.url.toString())
        }
    }.getOrNull()

    internal fun readUpTo(source: BufferedSource): ByteArray {
        val buffer = Buffer()
        while (buffer.size < MAX_HTML_BYTES) {
            val read = source.read(buffer, minOf(8_192L, MAX_HTML_BYTES - buffer.size))
            if (read == -1L) break
        }
        return buffer.readByteArray()
    }

    private fun parseDocument(document: Document, baseUrl: String): UrlMetadata? {
        val title = document.selectFirst("meta[property=og:title]")?.attr("content")
            ?.trim()?.takeIf(String::isNotEmpty)
            ?: document.title().trim().takeIf(String::isNotEmpty)
            ?: return null
        val site = document.selectFirst("meta[property=og:site_name]")?.attr("content")
            ?.trim()?.takeIf(String::isNotEmpty)
            ?: runCatching { URI(baseUrl).host.removePrefix("www.") }.getOrDefault("")
        val image = document.selectFirst("meta[property=og:image]")?.absUrl("content")
            ?.takeIf(String::isNotEmpty)
            ?: document.selectFirst("meta[name=twitter:image]")?.absUrl("content")?.takeIf(String::isNotEmpty)
        return UrlMetadata(title.take(180), site.take(80), image)
    }
}
