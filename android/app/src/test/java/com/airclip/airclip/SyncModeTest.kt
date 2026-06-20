package com.airclip.airclip

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlinx.coroutines.runBlocking

class SyncModeTest {

    @Test
    fun `auto allows automatic capture manual send and LAN service`() {
        assertTrue(SyncMode.AUTO.allowsAutomaticCapture)
        assertTrue(SyncMode.AUTO.allowsManualSend)
        assertTrue(SyncMode.AUTO.keepsLanServiceRunning)
    }

    @Test
    fun `manual only blocks automatic capture but allows explicit send and receive`() {
        assertFalse(SyncMode.MANUAL_ONLY.allowsAutomaticCapture)
        assertTrue(SyncMode.MANUAL_ONLY.allowsManualSend)
        assertTrue(SyncMode.MANUAL_ONLY.keepsLanServiceRunning)
    }

    @Test
    fun `paused blocks all clipboard sending and stops LAN service`() {
        assertFalse(SyncMode.PAUSED.allowsAutomaticCapture)
        assertFalse(SyncMode.PAUSED.allowsManualSend)
        assertFalse(SyncMode.PAUSED.keepsLanServiceRunning)
    }

    @Test
    fun `missing or invalid stored value defaults to manual only`() {
        assertEquals(SyncMode.MANUAL_ONLY, SyncMode.fromStoredValue(null))
        assertEquals(SyncMode.MANUAL_ONLY, SyncMode.fromStoredValue(""))
        assertEquals(SyncMode.MANUAL_ONLY, SyncMode.fromStoredValue("legacy"))
    }

    @Test
    fun `stored enum values round trip`() {
        SyncMode.entries.forEach { mode ->
            assertEquals(mode, SyncMode.fromStoredValue(mode.name))
        }
    }

    @Test
    fun `LAN service only runs while paired and not paused`() {
        assertFalse(SyncRuntimePolicy.shouldRunLanService(false, SyncMode.AUTO))
        assertFalse(SyncRuntimePolicy.shouldRunLanService(false, SyncMode.MANUAL_ONLY))
        assertFalse(SyncRuntimePolicy.shouldRunLanService(true, SyncMode.PAUSED))
        assertTrue(SyncRuntimePolicy.shouldRunLanService(true, SyncMode.AUTO))
        assertTrue(SyncRuntimePolicy.shouldRunLanService(true, SyncMode.MANUAL_ONLY))
    }

    @Test
    fun `lifecycle gate ignores duplicate connects and supports repeated resume`() {
        val gate = SyncEngineLifecycleGate()

        assertTrue(gate.requestConnect())
        assertFalse(gate.requestConnect())
        assertTrue(gate.isConnectRequested())
        assertTrue(gate.requestDisconnect())
        assertFalse(gate.requestDisconnect())
        assertFalse(gate.isConnectRequested())
        assertTrue(gate.requestConnect())
    }

    @Test
    fun `manual send bootstrap initializes in deterministic order`() = runBlocking {
        val events = mutableListOf<String>()

        val ready = ManualSendBootstrap.prepare(
            mode = SyncMode.MANUAL_ONLY,
            loadIdentity = {
                events += "identity"
                true
            },
            loadKeys = {
                events += "keys"
                true
            },
            initialize = { events += "initialize" },
            startRuntime = { events += "start" },
            awaitPeer = {
                events += "peer"
                true
            },
        )

        assertTrue(ready)
        assertEquals(
            listOf("identity", "keys", "initialize", "start", "peer"),
            events,
        )
    }

    @Test
    fun `paused manual send bootstrap performs no work`() = runBlocking {
        val events = mutableListOf<String>()

        val ready = ManualSendBootstrap.prepare(
            mode = SyncMode.PAUSED,
            loadIdentity = {
                events += "identity"
                true
            },
            loadKeys = {
                events += "keys"
                true
            },
            initialize = { events += "initialize" },
            startRuntime = { events += "start" },
            awaitPeer = {
                events += "peer"
                true
            },
        )

        assertFalse(ready)
        assertTrue(events.isEmpty())
    }

    @Test
    fun `manual send bootstrap reports unavailable peer`() = runBlocking {
        val ready = ManualSendBootstrap.prepare(
            mode = SyncMode.MANUAL_ONLY,
            loadIdentity = { true },
            loadKeys = { true },
            initialize = {},
            startRuntime = {},
            awaitPeer = { false },
        )

        assertFalse(ready)
    }
}
