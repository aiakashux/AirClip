package com.airclip.airclip.pairing

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class PairingCompletionPolicyTest {
    @Test
    fun `leaving and rejoining keeps the installation device id`() {
        assertEquals(
            "phone-installation",
            PairingCompletionPolicy.retainedDeviceId(
                currentDeviceId = "phone-installation",
                generatedDeviceId = "replacement-id",
            ),
        )
    }

    @Test
    fun `opening join does not authorize an ordinary peer connection`() {
        assertFalse(
            PairingCompletionPolicy.shouldAcceptAuth(
                isTrusted = false,
                isPairingSessionActive = true,
            ),
        )
    }

    @Test
    fun `the current device is never a remote paired device`() {
        assertFalse(PairingCompletionPolicy.isRemoteDevice("phone-id", "phone-id"))
        assertTrue(PairingCompletionPolicy.isRemoteDevice("mac-id", "phone-id"))
    }

    @Test
    fun `already paired scanner merges device when pairing into same Airclip`() {
        assertTrue(
            PairingCompletionPolicy.shouldMergeIntoExistingNetwork(
                isAlreadyPaired = true,
                currentAirclipId = "airclip-1",
                incomingAirclipId = "airclip-1",
            ),
        )
    }

    @Test
    fun `unpaired joining device adopts the incoming Airclip instead of merging`() {
        assertFalse(
            PairingCompletionPolicy.shouldMergeIntoExistingNetwork(
                isAlreadyPaired = false,
                currentAirclipId = null,
                incomingAirclipId = "airclip-1",
            ),
        )
    }

    @Test
    fun `paired device changing networks adopts the incoming Airclip after confirmation`() {
        assertFalse(
            PairingCompletionPolicy.shouldMergeIntoExistingNetwork(
                isAlreadyPaired = true,
                currentAirclipId = "airclip-1",
                incomingAirclipId = "airclip-2",
            ),
        )
    }

    @Test
    fun `manual code pairing uses current space when target is a new device`() {
        assertEquals(
            "airclip-1",
            PairingCompletionPolicy.pairingAirclipId(
                targetAirclipId = null,
                currentAirclipId = "airclip-1",
            ),
        )
    }
}
