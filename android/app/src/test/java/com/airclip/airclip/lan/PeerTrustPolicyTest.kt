package com.airclip.airclip.lan

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class PeerTrustPolicyTest {
    @Test
    fun `reconnect cannot replace a paired encryption key`() {
        assertTrue(matchesPairedKey("paired-key", "paired-key"))
        assertFalse(matchesPairedKey("paired-key", "attacker-key"))
        assertFalse(matchesPairedKey(null, "attacker-key"))
        assertFalse(matchesPairedKey("", ""))
    }

    @Test
    fun `removed device cannot authenticate with a retained space id`() {
        assertFalse(isTrustedPeer("space", "space", "removed", setOf("phone")))
        assertFalse(isTrustedPeer("other", "space", "phone", setOf("phone")))
        assertTrue(isTrustedPeer("space", "space", "phone", setOf("phone")))
    }
}
