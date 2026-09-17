package com.airclip.airclip.device

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class WifiMismatchGuidanceTest {
    @Test
    fun `shows a trusted last-known network only when all offline peers agree`() {
        assertEquals(
            "This device is on “Network 2”. Other devices were last seen on “Network 1”.",
            WifiMismatchGuidance.message("Network 2", listOf("Network 1", "Network 1"), true),
        )
        assertEquals(
            "Check that all devices are on the same Wi-Fi.",
            WifiMismatchGuidance.message("Network 1", listOf("Network 1"), true),
        )
        assertEquals(
            "Check that all devices are on the same Wi-Fi.",
            WifiMismatchGuidance.message("Network 2", listOf("Network 1", "Network 3"), true),
        )
        assertNull(WifiMismatchGuidance.message("Network 2", listOf("Network 1"), false))
    }
}
