package com.airclip.airclip

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class ClipboardColorTest {
    @Test
    fun recognizesCommonClipboardColorFormatsWithoutTreatingOtpAsColor() {
        assertEquals(0xFF2870DCL, parseClipboardColor("2870DC"))
        assertEquals(0xFF2870DCL, parseClipboardColor("#2870DC"))
        assertEquals(0x802870DCL, parseClipboardColor("0x802870DC"))
        assertEquals(0x802870DCL, parseClipboardColor("#2870DC80"))
        assertEquals(0xFF2870DCL, parseClipboardColor("rgb(40, 112, 220)"))
        assertEquals(0x802870DCL, parseClipboardColor("rgba(40, 112, 220, .5)"))
        assertEquals(0xFF2870DCL, parseClipboardColor("hsl(216, 72%, 51%)"))
        assertNull(parseClipboardColor("287012"))
        assertNull(parseClipboardColor("rgb(999, 0, 0)"))
    }
}
