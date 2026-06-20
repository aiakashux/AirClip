package com.airclip.airclip.lan

import android.util.Log
import com.airclip.airclip.PairedDevice
import com.airclip.airclip.AirClipIdentity
import com.airclip.airclip.crypto.KeyManager
import com.airclip.airclip.device.DeviceRemovalNotice
import com.airclip.airclip.pairing.PairingSession
import com.google.gson.Gson
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import org.java_websocket.WebSocket
import org.java_websocket.handshake.ClientHandshake
import org.java_websocket.server.WebSocketServer
import java.lang.Exception
import java.net.InetSocketAddress
import java.util.concurrent.ConcurrentHashMap

private const val TAG  = "LanServer"
private const val PORT = 7878

/**
 * LAN WebSocket server — listens on port 7878, handles three message types:
 *
 *   1. auth        — airclip_id-based peer authentication for sync
 *   2. pair_request — incoming pairing from an existing AirClip network member
 *   3. pair_probe  — code-only lookup (responds with device info if code matches)
 *
 * Auth wire format (sync):
 *   Client → Server: {"type":"auth","device_id":"...","airclip_id":"...","public_key":"..."}
 *   Server → Client: {"type":"auth_ok","device_id":"...","public_key":"..."}
 *
 * Pair wire format:
 *   Client → Server: {"type":"pair_request","code":"12345678","device_id":"...","device_name":"...",
 *                      "public_key":"...","airclip_id":"..."}
 *   Server → Client: {"type":"pair_ok","airclip_id":"...","all_devices":[...]}
 *   or               {"type":"pair_reject","reason":"..."}
 *
 *   Client → Server: {"type":"pair_probe","code":"12345678"}
 *   Server → Client: {"type":"pair_info","device_id":"...","device_name":"...","public_key":"..."}
 *   or               {"type":"pair_reject","reason":"invalid_code"}
 */
object LanServer {

    private var server: AirClipServer? = null
    private val gson = Gson()

    /** Callback invoked on successful inbound pairing so ViewModel can update state. */
    var onPairSuccess: (() -> Unit)? = null

    @Synchronized
    fun start(keyManager: KeyManager) {
        if (server != null) {
            Log.d(TAG, "LAN server already running on port $PORT")
            return
        }

        runCatching {
            server = AirClipServer(keyManager).also {
                it.setReuseAddr(true)
                it.start()
            }
            LanRuntimeDiagnostics.clear()
            Log.d(TAG, "LAN server started on port $PORT")
        }.onFailure {
            server = null
            LanRuntimeDiagnostics.serverFailed(it.message ?: it.javaClass.simpleName)
            Log.w(TAG, "LAN server start failed: ${it.message}")
        }
    }

    @Synchronized
    fun stop() {
        val running = server ?: return
        server = null
        runCatching { running.stop(1_000) }
            .onFailure { Log.w(TAG, "LAN server stop failed: ${it.message}") }
            .onSuccess { Log.d(TAG, "LAN server stopped") }
    }

    // ──────────────────────────────────────────────────────────────────────────

    private class AirClipServer(private val km: KeyManager) : WebSocketServer(InetSocketAddress(PORT)) {

        private data class ConnectionPeer(val deviceId: String, val connectionId: String)

        private val connToPeer = ConcurrentHashMap<WebSocket, ConnectionPeer>()
        private val scope = CoroutineScope(Dispatchers.IO)

        override fun onStart()  {
            LanRuntimeDiagnostics.clear()
            Log.d(TAG, "WS server listening on :$PORT")
        }

        override fun onOpen(conn: WebSocket, hs: ClientHandshake) {
            Log.d(TAG, "Incoming WS from ${conn.remoteSocketAddress}")
        }

        override fun onMessage(conn: WebSocket, message: String) {
            val authenticated = connToPeer[conn]
            if (authenticated == null) {
                handleInitial(conn, message)
            } else {
                handleMessage(conn, authenticated.deviceId, message)
            }
        }

        private fun handleInitial(conn: WebSocket, message: String) {
            try {
                @Suppress("UNCHECKED_CAST")
                val msg = gson.fromJson(message, Map::class.java) as? Map<String, String>
                    ?: return conn.close()

                when (msg["type"]) {
                    "auth"         -> handleAuth(conn, msg)
                    "pair_request" -> handlePairRequest(conn, msg)
                    "pair_probe"   -> handlePairProbe(conn, msg)
                    else           -> {
                        Log.w(TAG, "Unknown initial message type: ${msg["type"]}")
                        conn.close()
                    }
                }
            } catch (e: Exception) {
                Log.w(TAG, "handleInitial error: ${e.message}")
                runCatching { conn.close() }
            }
        }

        // ── Sync auth ─────────────────────────────────────────────────────────

        private fun handleAuth(conn: WebSocket, msg: Map<String, String>) {
            val peerId     = msg["device_id"]  ?: return reject(conn, "missing device_id")
            val peerAirClipId = msg["airclip_id"]    ?: return reject(conn, "missing airclip_id")
            val peerPubKey = msg["public_key"] ?: return reject(conn, "missing public_key")

            if (!PeerManager.isTrusted(peerAirClipId, peerId)) {
                Log.w(TAG, "Auth rejected: untrusted peer ${peerId.take(8)}")
                conn.close()
                return
            }

            val myId  = AirClipIdentity.deviceId  ?: return conn.close()
            val myKey = km.getPublicKeyBase64()

            conn.send(gson.toJson(mapOf(
                "type"       to "auth_ok",
                "device_id"  to myId,
                "public_key" to myKey,
            )))
            val connectionId = java.util.UUID.randomUUID().toString()
            connToPeer[conn] = ConnectionPeer(peerId, connectionId)

            PeerManager.registerPeer(Peer(
                deviceId   = peerId,
                publicKey  = peerPubKey,
                isIncoming = true,
                connectionId = connectionId,
                sendFn     = { conn.send(it) },
                closeFn    = { conn.close() },
            ))
            Log.d(TAG, "Peer authenticated: ${peerId.take(8)}")
        }

        // ── Pairing: existing device pairs a new device ───────────────────────

        private fun handlePairRequest(conn: WebSocket, msg: Map<String, String>) {
            val code        = msg["code"]        ?: return reject(conn, "missing code")
            val peerId      = msg["device_id"]   ?: return reject(conn, "missing device_id")
            val peerName    = msg["device_name"] ?: return reject(conn, "missing device_name")
            val peerPubKey  = msg["public_key"]  ?: return reject(conn, "missing public_key")
            val peerAirClipId  = msg["airclip_id"]     ?: return reject(conn, "missing airclip_id")

            // Verify the OTP
            if (!PairingSession.verifyCode(code)) {
                Log.w(TAG, "pair_request: invalid code from ${peerId.take(8)}")
                return reject(conn, "invalid_code")
            }

            // Existing device presents its airclip_id; must match ours if we already have one
            val myAirClipId = AirClipIdentity.airClipId
            if (myAirClipId != null && myAirClipId != peerAirClipId) {
                Log.w(TAG, "pair_request: airclip_id mismatch from ${peerId.take(8)}")
                return reject(conn, "airclip_id_mismatch")
            }

            Log.d(TAG, "pair_request accepted from ${peerId.take(8)}")

            // Gather our current trusted device list to hand to the new member
            val allDevices = AirClipIdentity.pairedDevices.values.map { d ->
                mapOf(
                    "device_id"   to d.deviceId,
                    "device_name" to d.deviceName,
                    "public_key"  to d.publicKey,
                    "platform"    to d.platform,
                )
            }.toMutableList()

            val myId = AirClipIdentity.deviceId
            if (myId != null && allDevices.none { it["device_id"] == myId }) {
                allDevices += mapOf(
                    "device_id" to myId,
                    "device_name" to AirClipIdentity.deviceName,
                    "public_key" to km.getPublicKeyBase64(),
                    "platform" to "android",
                )
            }

            conn.send(gson.toJson(mapOf(
                "type"        to "pair_ok",
                "airclip_id"     to peerAirClipId,
                "all_devices" to allDevices,
            )))

            // Notify ViewModel so it can persist the pairing result
            scope.launch {
                dispatchPairAccepted(peerAirClipId, peerId, peerName, peerPubKey)
            }

            conn.close()
        }

        // ── Pairing: probe by code (for manual code entry) ────────────────────

        private fun handlePairProbe(conn: WebSocket, msg: Map<String, String>) {
            val code = msg["code"] ?: return reject(conn, "missing code")

            if (!PairingSession.verifyCode(code)) {
                conn.send(gson.toJson(mapOf("type" to "pair_reject", "reason" to "invalid_code")))
                conn.close()
                return
            }

            // Respond with our identity so the initiator can connect for a full pair_request
            val myId   = AirClipIdentity.deviceId  ?: return conn.close()
            val myName = AirClipIdentity.deviceName
            val myKey  = km.getPublicKeyBase64()
            val myAirClipId = AirClipIdentity.airClipId ?: return conn.close()

            conn.send(gson.toJson(mapOf(
                "type"        to "pair_info",
                "device_id"   to myId,
                "device_name" to myName,
                "public_key"  to myKey,
                "airclip_id"  to myAirClipId,
            )))
            conn.close()
        }

        // ── Clip messages (after auth) ────────────────────────────────────────

        private fun handleMessage(conn: WebSocket, fromId: String, message: String) {
            try {
                @Suppress("UNCHECKED_CAST")
                val msg = gson.fromJson(message, Map::class.java) as? Map<String, String>
                    ?: return
                when (msg["type"]) {
                    "clip" -> {
                        val ciphertext = msg["ciphertext"] ?: return
                        val nonce      = msg["nonce"]      ?: return
                        PeerManager.dispatchInboundClip(ciphertext, nonce, fromId)
                    }
                    "history_clip" -> {
                        val ciphertext   = msg["ciphertext"]         ?: return
                        val nonce        = msg["nonce"]              ?: return
                        val ts           = msg["ts"]?.toLongOrNull() ?: System.currentTimeMillis()
                        val msgId        = msg["msg_id"]             ?: return
                        val fromDeviceId = msg["from_device_id"]     ?: fromId
                        PeerManager.dispatchHistoryClip(ciphertext, nonce, ts, msgId, fromDeviceId)
                    }
                    "heartbeat" -> {
                        PeerManager.markPeerSeen(fromId)
                        conn.send(gson.toJson(mapOf(
                            "type" to "heartbeat_ack",
                            "ts" to System.currentTimeMillis().toString(),
                        )))
                    }
                    "heartbeat_ack" -> {
                        PeerManager.markPeerSeen(fromId)
                    }
                    DeviceRemovalNotice.TYPE -> {
                        if (DeviceRemovalNotice.targetsCurrentDevice(msg, AirClipIdentity.deviceId)) {
                            PeerManager.dispatchRemovedFromNetwork()
                            conn.close(1000, "removed")
                        }
                    }
                }
            } catch (e: Exception) {
                Log.w(TAG, "handleMessage error from ${fromId.take(8)}: ${e.message}")
            }
        }

        // ── Helpers ───────────────────────────────────────────────────────────

        private fun reject(conn: WebSocket, reason: String) {
            conn.send(gson.toJson(mapOf("type" to "pair_reject", "reason" to reason)))
            conn.close()
        }

        override fun onClose(conn: WebSocket, code: Int, reason: String, remote: Boolean) {
            connToPeer.remove(conn)?.let { peer ->
                PeerManager.onPeerDisconnected(peer.deviceId, peer.connectionId)
                Log.d(TAG, "Peer disconnected: ${peer.deviceId.take(8)} code=$code")
            }
        }

        override fun onError(conn: WebSocket?, ex: Exception) {
            if (conn == null) {
                LanRuntimeDiagnostics.serverFailed(ex.message ?: ex.javaClass.simpleName)
            }
            Log.w(TAG, "WS error (conn=${conn?.remoteSocketAddress}): ${ex.message}")
        }
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Pairing result — called from server scope, routes to ViewModel via callback
    // ──────────────────────────────────────────────────────────────────────────

    /** Set by ViewModel to persist pairing result. Called when a pair_request is accepted. */
    var onPairAccepted: (suspend (airClipId: String, deviceId: String, deviceName: String, publicKey: String) -> Unit)? = null

    private suspend fun dispatchPairAccepted(airClipId: String, deviceId: String, deviceName: String, publicKey: String) {
        onPairAccepted?.invoke(airClipId, deviceId, deviceName, publicKey)
        onPairSuccess?.invoke()
    }
}
