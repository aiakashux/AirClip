package com.airclip.airclip

import org.junit.Assert.assertEquals
import org.junit.Test

class HistoryRetentionMigrationTest {
    @Test
    fun `new installs default to seven days`() {
        assertEquals(2, migratedHistoryDepth(stored = null, version = 0))
    }

    @Test
    fun `previous forever default migrates to seven days`() {
        assertEquals(2, migratedHistoryDepth(stored = 4, version = 3))
    }

    @Test
    fun `other selected durations remain unchanged`() {
        assertEquals(1, migratedHistoryDepth(stored = 1, version = 3))
    }
}
