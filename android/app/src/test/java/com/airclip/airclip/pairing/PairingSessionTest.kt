package com.airclip.airclip.pairing

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class PairingSessionTest {
    @Test
    fun refreshNotifiesTheUiWithTheCurrentPayload() {
        val payloads = mutableListOf<PairingPayload>()
        try {
            PairingSession.start(null, "device", "Phone", "My Space", "key", payloads::add)
            PairingSession.refreshNow()

            assertEquals(2, payloads.size)
            assertEquals(PairingSession.currentCode, payloads.last().code)
            assertEquals("My Space", payloads.last().space_name)
        } finally {
            PairingSession.stop()
        }
    }

    @Test
    fun previousCodeRemainsValidAfterRefresh() {
        try {
            PairingSession.start(null, "device", "Phone", "My Space", "key")
            val previousCode = PairingSession.currentCode!!

            PairingSession.refreshNow()

            assertTrue(PairingSession.verifyCode(previousCode))
        } finally {
            PairingSession.stop()
        }
    }

    @Test
    fun onlyTheImmediatelyPreviousCodeRemainsValid() {
        try {
            PairingSession.start(null, "device", "Phone", "My Space", "key")
            val expiredCode = PairingSession.currentCode!!
            PairingSession.refreshNow()
            val previousCode = PairingSession.currentCode!!

            PairingSession.refreshNow()

            assertFalse(PairingSession.verifyCode(expiredCode))
            assertTrue(PairingSession.verifyCode(previousCode))
        } finally {
            PairingSession.stop()
        }
    }
}
