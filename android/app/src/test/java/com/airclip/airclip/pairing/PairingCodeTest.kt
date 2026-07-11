package com.airclip.airclip.pairing

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class PairingCodeTest {

    @Test
    fun `normalizes spaces and non-digit separators`() {
        assertEquals("123456", PairingCode.normalize("123 456"))
        assertEquals("123456", PairingCode.normalize("123-456"))
    }

    @Test
    fun `accepts exactly six digits`() {
        assertTrue(PairingCode.isValid("123 456"))
        assertFalse(PairingCode.isValid("12345"))
        assertFalse(PairingCode.isValid("1234567"))
    }
}
