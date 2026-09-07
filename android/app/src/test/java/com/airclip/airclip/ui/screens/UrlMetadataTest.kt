package com.airclip.airclip.ui.screens

import org.junit.Assert.assertEquals
import org.junit.Test

class UrlMetadataTest {
    @Test
    fun parsesOpenGraphAndResolvesRelativeImage() {
        val metadata = UrlMetadataLoader.parse(
            """<html><head>
                <meta property="og:title" content="AirClip News">
                <meta property="og:site_name" content="AirClip">
                <meta property="og:image" content="/preview.png">
            </head></html>""",
            "https://airclip.app/story",
        )

        assertEquals("AirClip News", metadata?.title)
        assertEquals("AirClip", metadata?.site)
        assertEquals("https://airclip.app/preview.png", metadata?.imageUrl)
    }
}
