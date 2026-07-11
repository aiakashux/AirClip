package com.airclip.airclip.lan

import android.content.Context
import android.net.nsd.NsdManager
import android.net.nsd.NsdServiceInfo
import android.net.wifi.WifiManager
import android.util.Log
import com.airclip.airclip.AirClipIdentity
import com.airclip.airclip.crypto.KeyManager
import com.airclip.airclip.device.DeviceRemovalNotice
import com.airclip.airclip.pairing.ResolvedHostCache
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.Response
import okhttp3.WebSocket
import okhttp3.WebSocketListener
import java.util.ArrayDeque

private const val TAG          = "LanBrowser"
private const val SERVICE_TYPE = "_airclip._tcp"
private const val LAN_PORT     = 7878

/**
 * Discovers AirClip peers on the LAN via mDNS (NsdManager) and connects to them
 * using outgoing OkHttp WebSocket connections.
 *
 * Also registers this device's own service so peers can discover us.
 *
 * Outgoing handshake (client side):
 *   1. On open: send   {"type":"auth","device_id":"<ours>","airclip_id":"<ours>","public_key":"<ours>"}
 *   2. On auth_ok:     register peer with their public_key for E2E encryption
 *   3. Subsequent:     handle clip messages
 */
object LanBrowser {

    private var nsdManager: NsdManager? = null
    private var discoveryListener: NsdManager.DiscoveryListener? = null
    private var registrationListener: NsdManager.RegistrationListener? = null

    // Serialise NsdManager.resolveService calls — it only supports one at a time (pre-API 34)
    private val resolveQueue = ArrayDeque<NsdServiceInfo>()
    private var isResolving  = false

    private var httpClient:  OkHttpClient? = null
    private var keyManager:  KeyManager?   = null
    private var multicastLock: WifiManager.MulticastLock? = null

    fun start(context: Context, client: OkHttpClient, km: KeyManager) {
        stop(context)
        httpClient = client
        keyManager  = km
        nsdManager  = context.getSystemService(Context.NSD_SERVICE) as? NsdManager
        if (nsdManager == null) {
            LanRuntimeDiagnostics.discoveryFailed("NSD unavailable")
            Log.w(TAG, "NSD unavailable")
            return
        }

        // Acquire multicast lock before starting NSD — without this, mDNS packets are
        // filtered by the WiFi driver and discoverServices() silently finds nothing.
        val wifi = context.applicationContext.getSystemService(Context.WIFI_SERVICE) as? WifiManager
        multicastLock = wifi?.createMulticastLock("airclip_lan")?.also {
            it.setReferenceCounted(false)
            it.acquire()
            Log.d(TAG, "Multicast lock acquired")
        }

        registerSelf(context)
        startDiscovery()
    }

    fun stop(context: Context) {
        discoveryListener?.let { runCatching { nsdManager?.stopServiceDiscovery(it) } }
        registrationListener?.let { runCatching { nsdManager?.unregisterService(it) } }
        discoveryListener    = null
        registrationListener = null
        nsdManager           = null
        multicastLock?.let { if (it.isHeld) it.release(); Log.d(TAG, "Multicast lock released") }
        multicastLock = null
        synchronized(resolveQueue) { resolveQueue.clear(); isResolving = false }
    }

    // ── Service registration (so others discover us) ──────────────────────────

    private fun registerSelf(context: Context) {
        val myId = AirClipIdentity.deviceId ?: run {
            Log.w(TAG, "No device ID — skipping NSD registration")
            return
        }
        val info = NsdServiceInfo().also {
            it.serviceName = myId
            it.serviceType = SERVICE_TYPE
            it.port        = LAN_PORT
        }
        val listener = object : NsdManager.RegistrationListener {
            override fun onServiceRegistered(i: NsdServiceInfo) {
                LanRuntimeDiagnostics.clear()
                Log.d(TAG, "NSD registered: ${i.serviceName}")
            }
            override fun onRegistrationFailed(i: NsdServiceInfo, e: Int) {
                LanRuntimeDiagnostics.advertisementFailed("NSD register failed: $e")
                Log.w(TAG, "NSD register failed: $e")
            }
            override fun onServiceUnregistered(i: NsdServiceInfo) { Log.d(TAG, "NSD unregistered") }
            override fun onUnregistrationFailed(i: NsdServiceInfo, e: Int) {
                LanRuntimeDiagnostics.advertisementFailed("NSD unregister failed: $e")
                Log.w(TAG, "NSD unregister failed: $e")
            }
        }
        registrationListener = listener
        nsdManager?.registerService(info, NsdManager.PROTOCOL_DNS_SD, listener)
    }

    // ── Discovery ─────────────────────────────────────────────────────────────

    private fun startDiscovery() {
        val listener = object : NsdManager.DiscoveryListener {
            override fun onDiscoveryStarted(t: String)  {
                LanRuntimeDiagnostics.clear()
                Log.d(TAG, "Discovery started")
            }
            override fun onDiscoveryStopped(t: String)  { Log.d(TAG, "Discovery stopped") }
            override fun onStartDiscoveryFailed(t: String, e: Int) {
                LanRuntimeDiagnostics.discoveryFailed("Start discovery failed: $e")
                Log.w(TAG, "Start discovery failed: $e")
            }
            override fun onStopDiscoveryFailed(t: String, e: Int)  {
                LanRuntimeDiagnostics.discoveryFailed("Stop discovery failed: $e")
                Log.w(TAG, "Stop discovery failed: $e")
            }

            override fun onServiceFound(service: NsdServiceInfo) {
                val peerHint = service.serviceName ?: return
                val myId     = AirClipIdentity.deviceId ?: return
                if (peerHint == myId) return
                if (PeerManager.hasPeer(peerHint) || PeerManager.isPending(peerHint)) return
                if (!PeerManager.addPendingHint(peerHint)) return

                Log.d(TAG, "Service found: ${peerHint.take(8)}")
                synchronized(resolveQueue) { resolveQueue.add(service) }
                processResolveQueue()
            }

            override fun onServiceLost(service: NsdServiceInfo) {
                val peerHint = service.serviceName ?: return
                Log.d(TAG, "Service lost: ${peerHint.take(8)}")
                PeerManager.onPeerDisconnected(peerHint)
            }
        }
        discoveryListener = listener
        nsdManager?.discoverServices(SERVICE_TYPE, NsdManager.PROTOCOL_DNS_SD, listener)
    }

    // ── Serialised resolve queue ───────────────────────────────────────────────

    private fun processResolveQueue() {
        val service: NsdServiceInfo
        synchronized(resolveQueue) {
            if (isResolving || resolveQueue.isEmpty()) return
            isResolving = true
            service = resolveQueue.poll() ?: run { isResolving = false; return }
        }

        nsdManager?.resolveService(service, object : NsdManager.ResolveListener {
            override fun onResolveFailed(info: NsdServiceInfo, errorCode: Int) {
                Log.w(TAG, "Resolve failed for ${info.serviceName?.take(8)}: $errorCode")
                info.serviceName?.let { PeerManager.onPeerDisconnected(it) }
                synchronized(resolveQueue) { isResolving = false }
                processResolveQueue()
            }

            override fun onServiceResolved(info: NsdServiceInfo) {
                synchronized(resolveQueue) { isResolving = false }
                val host     = info.host?.hostAddress ?: return processResolveQueue()
                val port     = info.port
                val peerHint = info.serviceName ?: return processResolveQueue()
                // Cache resolved IP so PairingClient can find devices by device_id
                ResolvedHostCache.put(peerHint, host)
                connectToPeer(host, port, peerHint)
                processResolveQueue()
            }
        })
    }

    // ── Outgoing WebSocket connection ─────────────────────────────────────────

    private fun connectToPeer(host: String, port: Int, peerHint: String) {
        val myDeviceId = AirClipIdentity.deviceId ?: return PeerManager.onPeerDisconnected(peerHint)
        val myAirClipId = AirClipIdentity.airClipId ?: return PeerManager.onPeerDisconnected(peerHint)
        val myPubKey = keyManager?.getPublicKeyBase64() ?: return PeerManager.onPeerDisconnected(peerHint)
        val client = httpClient ?: return PeerManager.onPeerDisconnected(peerHint)

        Log.d(TAG, "Connecting to ${peerHint.take(8)} at $host:$port")
        val request = Request.Builder().url("ws://$host:$port/").build()
        client.newWebSocket(request, OutgoingListener(peerHint, myDeviceId, myAirClipId, myPubKey))
    }

    // ── Outgoing WebSocket listener ────────────────────────────────────────────

    private class OutgoingListener(
        private val peerHint: String,
        private val myDeviceId: String,
        private val myAirClipId: String,
        private val myPubKey: String,
    ) : WebSocketListener() {

        private var authenticated = false
        private var authenticatedPeerId: String? = null
        private var connectionId: String? = null

        override fun onOpen(webSocket: WebSocket, response: Response) {
            webSocket.send(PeerManager.gson.toJson(mapOf(
                "type"       to "auth",
                "device_id"  to myDeviceId,
                "airclip_id"    to myAirClipId,       // was account_id
                "public_key" to myPubKey,       // included so server can encrypt for us
                "device_name" to AirClipIdentity.deviceName,
                "platform" to "android",
            )))
            Log.d(TAG, "Sent auth to ${peerHint.take(8)}")
        }

        override fun onMessage(webSocket: WebSocket, text: String) {
            if (authenticated) handleMessage(webSocket, text)
            else               handleAuthOk(webSocket, text)
        }

        private fun handleAuthOk(ws: WebSocket, text: String) {
            try {
                @Suppress("UNCHECKED_CAST")
                val msg = PeerManager.gson.fromJson(text, Map::class.java) as? Map<String, String>
                    ?: return closeWith(ws, "bad auth_ok JSON")

                if (msg["type"] != "auth_ok") return closeWith(ws, "expected auth_ok, got ${msg["type"]}")

                val peerId  = msg["device_id"]  ?: return closeWith(ws, "missing device_id")
                val peerKey = msg["public_key"] ?: return closeWith(ws, "missing public_key")

                if (!AirClipIdentity.pairedDevices.containsKey(peerId)) {
                    return closeWith(ws, "unpaired device")
                }

                // Trust is implicit: server already validated our airclip_id in handleAuth.
                // We accept auth_ok at face value.
                authenticated = true
                authenticatedPeerId = peerId
                connectionId = java.util.UUID.randomUUID().toString()

                PeerManager.registerPeer(Peer(
                    deviceId   = peerId,
                    deviceName = msg["device_name"] ?: "",
                    publicKey  = peerKey,
                    platform   = msg["platform"] ?: "",
                    wifiNetwork = msg["ssid"],
                    isIncoming = false,
                    connectionId = connectionId ?: return closeWith(ws, "missing connection id"),
                    sendFn     = { ws.send(it) },
                    closeFn    = { ws.close(1000, "bye") },
                ))
                Log.d(TAG, "Outgoing auth complete: ${peerId.take(8)}")

            } catch (e: Exception) {
                Log.w(TAG, "handleAuthOk error: ${e.message}")
                ws.close(1011, "internal error")
                PeerManager.onPeerDisconnected(authenticatedPeerId ?: peerHint, connectionId)
            }
        }

        private fun handleMessage(ws: WebSocket, text: String) {
            try {
                @Suppress("UNCHECKED_CAST")
                val msg = PeerManager.gson.fromJson(text, Map::class.java) as? Map<String, String>
                    ?: return
                when (msg["type"]) {
                    "clip" -> {
                        val ciphertext = msg["ciphertext"] ?: return
                        val nonce      = msg["nonce"]      ?: return
                        PeerManager.dispatchInboundClip(ciphertext, nonce, peerHint)
                    }
                    "history_clip" -> {
                        val ciphertext   = msg["ciphertext"]         ?: return
                        val nonce        = msg["nonce"]              ?: return
                        val ts           = msg["ts"]?.toLongOrNull() ?: System.currentTimeMillis()
                        val msgId        = msg["msg_id"]             ?: return
                        val fromDeviceId = msg["from_device_id"]     ?: peerHint
                        PeerManager.dispatchHistoryClip(ciphertext, nonce, ts, msgId, fromDeviceId)
                    }
                    "heartbeat" -> {
                        val fromId = authenticatedPeerId ?: peerHint
                        PeerManager.markPeerSeen(fromId)
                        ws.send(PeerManager.gson.toJson(mapOf(
                            "type" to "heartbeat_ack",
                            "ts" to System.currentTimeMillis().toString(),
                        )))
                    }
                    "heartbeat_ack" -> {
                        PeerManager.markPeerSeen(authenticatedPeerId ?: peerHint)
                    }
                    "app_activity" -> {
                        val ts = msg["ts"]?.toLongOrNull() ?: System.currentTimeMillis()
                        PeerManager.markPeerActivity(authenticatedPeerId ?: peerHint, ts)
                    }
                    DeviceRemovalNotice.TYPE -> {
                        if (DeviceRemovalNotice.targetsCurrentDevice(msg, AirClipIdentity.deviceId)) {
                            PeerManager.dispatchRemovedFromNetwork()
                            ws.close(1000, "removed")
                        }
                    }
                }
            } catch (e: Exception) {
                Log.w(TAG, "handleMessage error: ${e.message}")
            }
        }

        override fun onClosed(webSocket: WebSocket, code: Int, reason: String) {
            PeerManager.onPeerDisconnected(authenticatedPeerId ?: peerHint, connectionId)
            Log.d(TAG, "Outgoing closed ${peerHint.take(8)}: $code $reason")
        }

        override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {
            PeerManager.onPeerDisconnected(authenticatedPeerId ?: peerHint, connectionId)
            Log.w(TAG, "Outgoing failure ${peerHint.take(8)}: ${t.message}")
        }

        private fun closeWith(ws: WebSocket, reason: String) {
            Log.w(TAG, "Closing outgoing to ${peerHint.take(8)}: $reason")
            ws.close(1002, reason)
            PeerManager.onPeerDisconnected(authenticatedPeerId ?: peerHint, connectionId)
        }
    }
}
