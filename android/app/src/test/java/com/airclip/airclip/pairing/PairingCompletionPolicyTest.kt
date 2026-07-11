package com.airclip.airclip.pairing

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class PairingCompletionPolicyTest {
    @Test
    fun `already paired scanner merges device when pairing into same AirClip`() {
        assertTrue(
            PairingCompletionPolicy.shouldMergeIntoExistingNetwork(
                isAlreadyPaired = true,
                currentAirClipId = "airclip-1",
                incomingAirClipId = "airclip-1",
            ),
        )
    }

    @Test
    fun `unpaired joining device adopts the incoming AirClip instead of merging`() {
        assertFalse(
            PairingCompletionPolicy.shouldMergeIntoExistingNetwork(
                isAlreadyPaired = false,
                currentAirClipId = null,
                incomingAirClipId = "airclip-1",
            ),
        )
    }

    @Test
    fun `paired device changing networks adopts the incoming AirClip after confirmation`() {
        assertFalse(
            PairingCompletionPolicy.shouldMergeIntoExistingNetwork(
                isAlreadyPaired = true,
                currentAirClipId = "airclip-1",
                incomingAirClipId = "airclip-2",
            ),
        )
    }
}
