package com.airclip.airclip.pairing

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class PairingCodeTest {

    @Test
    fun `normalizes spaces and non-digit separators`() {
        assertEquals("12345678", PairingCode.normalize("1234 5678"))
        assertEquals("12345678", PairingCode.normalize("1234-5678"))
    }

    @Test
    fun `accepts exactly eight digits`() {
        assertTrue(PairingCode.isValid("1234 5678"))
        assertFalse(PairingCode.isValid("1234567"))
        assertFalse(PairingCode.isValid("123456789"))
    }
}
