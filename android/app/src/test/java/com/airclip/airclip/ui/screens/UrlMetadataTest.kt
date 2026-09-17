package com.airclip.airclip.ui.screens

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test
import okio.Buffer
import kotlinx.coroutines.runBlocking

class UrlMetadataTest {
    @Test
    fun parsesOpenGraphAndResolvesRelativeImage() {
        val metadata = UrlMetadataLoader.parse(
            """<html><head>
                <meta property="og:title" content="Airclip News">
                <meta property="og:site_name" content="Airclip">
                <meta property="og:image" content="/preview.png">
            </head></html>""",
            "https://airclip.app/story",
        )

        assertEquals("Airclip News", metadata?.title)
        assertEquals("Airclip", metadata?.site)
        assertEquals("https://airclip.app/preview.png", metadata?.imageUrl)
    }

    @Test
    fun leavesImageEmptyWhenPageHasNoPreviewImage() {
        val metadata = UrlMetadataLoader.parse(
            "<html><head><title>Airclip</title></head></html>",
            "https://airclip.app",
        )

        assertNull(metadata?.imageUrl)
    }

    @Test
    fun ignoresFaviconsWhenPageHasNoPreviewImage() {
        val metadata = UrlMetadataLoader.parse(
            """<html><head><title>Airclip</title><link rel="icon" href="/favicon.png"></head></html>""",
            "https://airclip.app",
        )

        assertNull(metadata?.imageUrl)
    }

    @Test
    fun readsShortHtmlResponsesWithoutDiscardingOpenGraphTags() {
        val html = "<meta property=\"og:title\" content=\"Airclip\">"

        val bytes = UrlMetadataLoader.readUpTo(Buffer().writeUtf8(html))

        assertEquals(html, bytes.toString(Charsets.UTF_8))
    }

    @Test
    fun extractsEmbeddedLinksInReadingOrderAndTrimsPunctuation() {
        assertEquals(
            listOf("https://first.example/story", "http://second.example/news"),
            UrlMetadataLoader.urlsIn(
                "Read https://first.example/story, then (http://second.example/news).",
            ),
        )
    }

    @Test
    fun usesFirstEmbeddedLinkThatHasAnOgImage() = runBlocking {
        val visited = mutableListOf<String>()
        val result = UrlMetadataLoader.firstPreviewWithImage(
            "https://one.example then https://two.example and https://three.example",
        ) { url ->
            visited += url
            UrlMetadata(url, url, if (url.contains("two")) "https://images.example/two.jpg" else null)
        }

        assertEquals("https://two.example", result?.first)
        assertEquals(listOf("https://one.example", "https://two.example"), visited)
    }
}
