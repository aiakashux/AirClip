package com.airclip.airclip.pairing

import org.junit.Assert.assertEquals
import org.junit.Test

class PairingSessionTest {
    @Test
    fun refreshNotifiesTheUiWithTheCurrentPayload() {
        val payloads = mutableListOf<PairingPayload>()
        try {
            PairingSession.start(null, "device", "Phone", "key", payloads::add)
            PairingSession.refreshNow()

            assertEquals(2, payloads.size)
            assertEquals(PairingSession.currentCode, payloads.last().code)
        } finally {
            PairingSession.stop()
        }
    }
}
