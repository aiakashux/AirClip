package com.airclip.airclip.share

import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Test

class ShareBatchDispatcherTest {
    @Test
    fun `waits for every item in a multi-share batch`() = runBlocking {
        val completed = mutableListOf<Int>()

        val successCount = dispatchShareBatch(listOf(1, 2, 3, 4)) { item ->
            completed += item
            true
        }

        assertEquals(listOf(1, 2, 3, 4), completed)
        assertEquals(4, successCount)
    }

    @Test
    fun `counts only items that finish successfully`() = runBlocking {
        val successCount = dispatchShareBatch(listOf(1, 2, 3)) { item -> item != 2 }

        assertEquals(2, successCount)
    }
}
