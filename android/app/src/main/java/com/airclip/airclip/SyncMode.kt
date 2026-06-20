package com.airclip.airclip

enum class SyncMode(
    val allowsAutomaticCapture: Boolean,
    val allowsManualSend: Boolean,
    val keepsLanServiceRunning: Boolean,
) {
    AUTO(
        allowsAutomaticCapture = true,
        allowsManualSend = true,
        keepsLanServiceRunning = true,
    ),
    MANUAL_ONLY(
        allowsAutomaticCapture = false,
        allowsManualSend = true,
        keepsLanServiceRunning = true,
    ),
    PAUSED(
        allowsAutomaticCapture = false,
        allowsManualSend = false,
        keepsLanServiceRunning = false,
    );

    companion object {
        fun fromStoredValue(value: String?): SyncMode =
            entries.firstOrNull { it.name == value } ?: MANUAL_ONLY
    }
}

object SyncRuntimePolicy {
    fun shouldRunLanService(isPaired: Boolean, mode: SyncMode): Boolean =
        isPaired && mode.keepsLanServiceRunning
}

internal class SyncEngineLifecycleGate {
    private var requested = false

    @Synchronized
    fun requestConnect(): Boolean {
        if (requested) return false
        requested = true
        return true
    }

    @Synchronized
    fun requestDisconnect(): Boolean {
        val wasRequested = requested
        requested = false
        return wasRequested
    }

    @Synchronized
    fun isConnectRequested(): Boolean = requested

    @Synchronized
    fun runIfConnectRequested(block: () -> Unit): Boolean {
        if (!requested) return false
        block()
        return true
    }
}

internal object ManualSendBootstrap {
    suspend fun prepare(
        mode: SyncMode,
        loadIdentity: suspend () -> Boolean,
        loadKeys: suspend () -> Boolean,
        initialize: () -> Unit,
        startRuntime: () -> Unit,
        awaitPeer: suspend () -> Boolean,
    ): Boolean {
        if (!mode.allowsManualSend) return false
        if (!loadIdentity()) return false
        if (!loadKeys()) return false

        initialize()
        startRuntime()
        return awaitPeer()
    }
}
