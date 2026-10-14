package com.airclip.airclip

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class HistoryMutationPolicyTest {
    @Test
    fun `cleared and individually deleted clips cannot return during backfill`() {
        assertFalse(shouldAcceptHistoryItem("old", "mac", 100, 100, emptySet()))
        assertFalse(shouldAcceptHistoryItem("deleted", "mac", 200, 100, setOf("deleted")))
        assertFalse(shouldAcceptHistoryItem("different-id", "mac", 201, 100, emptySet(), setOf("mac|200")))
        assertTrue(shouldAcceptHistoryItem("new", "mac", 5_000, 100, emptySet(), setOf("mac|200")))
    }
}
