package com.airclip.airclip

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Test

class PrivacyAnalyticsTest {
    @Test
    fun payloadContainsOnlyDocumentedCoarseFields() {
        val payload = AnalyticsPayload.create(
            appVersion = "2.0",
            osMajor = "14",
            counts = mapOf(AnalyticsEvent.PAIRING_SUCCESS to 1),
        )

        assertEquals(setOf("schemaVersion", "appVersion", "platform", "osMajor", "counts"), payload.keys)
        assertFalse(payload.toString().contains("device", ignoreCase = true))
        assertFalse(payload.toString().contains("timestamp", ignoreCase = true))
    }
}
