package com.airclip.airclip.share

import android.content.ClipData
import android.content.Intent
import android.net.Uri
import androidx.test.core.app.ApplicationProvider
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner

@RunWith(RobolectricTestRunner::class)
class ShareIntentUriExtractorTest {
    @Test
    fun `reads a shared file URI from intent data`() {
        val uri = Uri.parse("content://files.example/documents/report.pdf")
        val intent = Intent(Intent.ACTION_SEND).apply {
            type = "application/pdf"
            data = uri
        }

        assertEquals(listOf(uri), ShareIntentUriExtractor.extract(intent))
    }

    @Test
    fun `reads all URI locations without duplicates`() {
        val first = Uri.parse("content://files.example/documents/one.pdf")
        val second = Uri.parse("content://files.example/documents/two.pdf")
        val intent = Intent(Intent.ACTION_SEND_MULTIPLE).apply {
            type = "application/pdf"
            data = first
            putParcelableArrayListExtra(Intent.EXTRA_STREAM, arrayListOf(first, second))
            clipData = ClipData.newUri(
                ApplicationProvider.getApplicationContext<android.content.Context>().contentResolver,
                "documents",
                second,
            )
        }

        assertEquals(listOf(first, second), ShareIntentUriExtractor.extract(intent))
    }

    @Test
    fun `reads URI strings and arrays used by nonstandard file providers`() {
        val first = "content://files.example/documents/one.pdf"
        val second = Uri.parse("content://files.example/documents/two.pdf")
        val intent = Intent(Intent.ACTION_SEND_MULTIPLE).apply {
            type = "application/pdf"
            putExtra(Intent.EXTRA_STREAM, arrayOf(first, second))
        }

        assertEquals(
            listOf(Uri.parse(first), second),
            ShareIntentUriExtractor.extract(intent),
        )
    }

    @Test
    fun `does not treat a shared web link as a file`() {
        val intent = Intent(Intent.ACTION_SEND).apply {
            type = "text/plain"
            data = Uri.parse("https://example.com/report.pdf")
            putExtra(Intent.EXTRA_TEXT, "https://example.com/report.pdf")
        }

        assertEquals(emptyList<Uri>(), ShareIntentUriExtractor.extract(intent))
    }

    @Test
    fun `reads a content URI sent as shared text by a file provider`() {
        val uri = Uri.parse("content://files.example/documents/report.pdf")
        val intent = Intent(Intent.ACTION_SEND).apply {
            type = "application/pdf"
            putExtra(Intent.EXTRA_TEXT, uri.toString())
        }

        assertEquals(listOf(uri), ShareIntentUriExtractor.extract(intent))
    }
}
