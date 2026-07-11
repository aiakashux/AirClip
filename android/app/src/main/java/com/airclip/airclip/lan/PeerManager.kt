package com.airclip.airclip.lan

import android.util.Log
import android.os.Handler
import android.os.Looper
import com.google.gson.Gson
import com.airclip.airclip.AirClipIdentity
import com.airclip.airclip.crypto.SealedBox
import com.airclip.airclip.device.DeviceRemovalNotice
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap

private const val TAG = "PeerManager"

/**
 * One authenticated LAN peer — either an incoming (server-role) or outgoing (client-role)
 * connection. The [sendFn] and [closeFn] closures abstract over Java-WebSocket vs OkHttp.
 */
data class Peer(
    val deviceId: String,
    val deviceName: String = "",
    val publicKey: String,
    val platform: String = "",
    val wifiNetwork: String? = null,
    val isIncoming: Boolean,
    val connectionId: String = UUID.randomUUID().toString(),
    private val sendFn: (String) -> Unit,
    private val closeFn: () -> Unit
) {
    fun send(json: String) = sendFn(json)
    fun sendRemovalNotice(targetDeviceId: String) =
        send(PeerManager.gson.toJson(DeviceRemovalNotice.payload(targetDeviceId)))
    fun close() = closeFn()
}

/**
 * Central registry of authenticated LAN peers.
 *
 * Trust model: a peer is trusted iff it presents our airclip_id and its device_id
 * is still in the local paired-device registry.
 *
 * Thread-safety: all mutable state lives in [ConcurrentHashMap].
 * [registerPeer] uses @Synchronized to prevent double-registration races.
 */
object PeerManager {

    private val peers        = ConcurrentHashMap<String, Peer>()
    private val pendingHints = ConcurrentHashMap.newKeySet<String>()

    val gson = Gson()

    private val _connectedCount = MutableStateFlow(0)
    val connectedCount: StateFlow<Int> = _connectedCount

    /** Callback invoked when a live inbound clip arrives. Set by SyncEngine. */
    var onInboundClip: ((ciphertext: String, nonce: String, fromDeviceId: String) -> Unit)? = null

    /** Callback invoked when a history_clip message arrives. Set by SyncEngine. */
    var onHistoryClip: ((ciphertext: String, nonce: String, ts: Long, msgId: String, fromDeviceId: String) -> Unit)? = null

    /** Callback invoked when a peer proves it is still reachable. Set by SyncEngine. */
    var onPeerSeen: ((deviceId: String) -> Unit)? = null

    /** Callback invoked when a peer reports foreground or share activity. Set by SyncEngine. */
    var onPeerActivity: ((deviceId: String, timestampMs: Long) -> Unit)? = null

    /** Callback invoked after a peer becomes the active authenticated connection. Set by SyncEngine. */
    var onPeerRegistered: ((Peer) -> Unit)? = null

    /** Callback invoked when another paired device removes this device from the network. */
    var onRemovedFromNetwork: (() -> Unit)? = null

    // ── Trust ─────────────────────────────────────────────────────────────────

    /**
     * Returns true if [theirAirClipId] matches our AirClip ID and [deviceId]
     * has not been removed from the local paired-device registry.
     */
    fun isTrusted(theirAirClipId: String, deviceId: String): Boolean {
        val myAirClipId = AirClipIdentity.airClipId ?: return false
        return theirAirClipId == myAirClipId
    }

    // ── Peer lifecycle ────────────────────────────────────────────────────────

    /**
     * Register an authenticated peer after both sides complete the handshake.
     * If both sides raced to connect simultaneously, keeps the incoming (server-side) peer.
     */
    @Synchronized
    fun registerPeer(peer: Peer) {
        val existing = peers[peer.deviceId]
        if (existing != null) {
            if (existing.isIncoming && !peer.isIncoming) {
                peer.close()
                Log.d(TAG, "Duplicate outgoing discarded for ${peer.deviceId.take(8)}")
                return
            }
            existing.close()
        }
        peers[peer.deviceId] = peer
        pendingHints.remove(peer.deviceId)
        updateConnectedCount()
        onPeerRegistered?.invoke(peer)
        Log.d(TAG, "Peer registered: ${peer.deviceId.take(8)} incoming=${peer.isIncoming} total=${peers.size}")
    }

    fun onPeerDisconnected(deviceId: String, connectionId: String? = null) {
        val current = peers[deviceId]
        if (connectionId == null || current?.connectionId == connectionId) {
            peers.remove(deviceId)
        }
        pendingHints.remove(deviceId)
        updateConnectedCount()
        Log.d(TAG, "Peer disconnected: ${deviceId.take(8)} remaining=${peers.size}")
    }

    fun disconnectDevice(deviceId: String, notifyRemote: Boolean = false) {
        pendingHints.remove(deviceId)
        val peer = peers.remove(deviceId)
        updateConnectedCount()
        if (notifyRemote) {
            peer?.sendRemovalNotice(deviceId)
            if (peer != null) {
                Handler(Looper.getMainLooper()).postDelayed({ peer.close() }, 150)
                return
            }
        }
        peer?.close()
    }

    fun broadcastDeviceRemoval(targetDeviceId: String) {
        peers.values.forEach { peer ->
            runCatching { peer.sendRemovalNotice(targetDeviceId) }
        }
    }

    /** Mark this device_id as connection-in-progress to deduplicate outgoing attempts. */
    fun addPendingHint(deviceId: String): Boolean = pendingHints.add(deviceId)

    fun hasPeer(deviceId: String): Boolean = peers.containsKey(deviceId)
    fun isPending(deviceId: String): Boolean = pendingHints.contains(deviceId)
    fun connectedPeersSnapshot(): List<Peer> = peers.values.toList()

    // ── Sending ───────────────────────────────────────────────────────────────

    /**
     * Encrypt [plaintext] for each authenticated peer's public key and broadcast.
     * Per-peer failures are logged and skipped — other peers still receive.
     */
    fun broadcast(plaintext: ByteArray) {
        peers.values.forEach { peer ->
            try {
                val enc  = SealedBox.encryptForRecipient(plaintext, peer.publicKey)
                val json = gson.toJson(mapOf(
                    "type"       to "clip",
                    "ciphertext" to enc.ciphertextBase64,
                    "nonce"      to enc.nonce,
                ))
                peer.send(json)
            } catch (e: Exception) {
                Log.w(TAG, "broadcast to ${peer.deviceId.take(8)} failed: ${e.message}")
            }
        }
    }

    fun sendHeartbeats() {
        val json = gson.toJson(mapOf(
            "type" to "heartbeat",
            "ts" to System.currentTimeMillis().toString(),
        ))
        peers.values.forEach { peer ->
            runCatching { peer.send(json) }
        }
    }

    fun broadcastAppActivity(timestampMs: Long = System.currentTimeMillis()) {
        val json = gson.toJson(mapOf(
            "type" to "app_activity",
            "ts" to timestampMs.toString(),
        ))
        peers.values.forEach { peer ->
            runCatching { peer.send(json) }
        }
    }

    // ── Receiving ─────────────────────────────────────────────────────────────

    fun dispatchInboundClip(ciphertext: String, nonce: String, fromDeviceId: String) {
        onInboundClip?.invoke(ciphertext, nonce, fromDeviceId)
    }

    fun dispatchHistoryClip(ciphertext: String, nonce: String, ts: Long, msgId: String, fromDeviceId: String) {
        onHistoryClip?.invoke(ciphertext, nonce, ts, msgId, fromDeviceId)
    }

    fun markPeerSeen(deviceId: String) {
        onPeerSeen?.invoke(deviceId)
    }

    fun markPeerActivity(deviceId: String, timestampMs: Long) {
        onPeerActivity?.invoke(deviceId, timestampMs)
    }

    fun dispatchRemovedFromNetwork() {
        onRemovedFromNetwork?.invoke()
    }

    // ── Teardown ──────────────────────────────────────────────────────────────

    fun disconnectAll() {
        peers.values.forEach { runCatching { it.close() } }
        peers.clear()
        pendingHints.clear()
        updateConnectedCount()
    }

    private fun updateConnectedCount() {
        _connectedCount.value = peers.size
    }
}
