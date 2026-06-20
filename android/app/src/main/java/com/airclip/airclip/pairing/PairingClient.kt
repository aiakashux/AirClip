package com.airclip.airclip.pairing

import android.util.Log
import com.google.gson.Gson
import com.google.gson.reflect.TypeToken
import com.airclip.airclip.PairedDevice
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.Response
import okhttp3.WebSocket
import okhttp3.WebSocketListener
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

private const val TAG      = "PairingClient"
private const val LAN_PORT = 7878

/**
 * Sends an outgoing pair_request to a device that was discovered via mDNS.
 *
 * Flow (this device scans an existing AirClip network member's QR):
 *   1. This device knows the target's device_id + airclip_id + code (from QR)
 *   2. Target's device_id == mDNS service name → we need its IP from mDNS
 *   3. We use the mDNS discovery to get the IP (see [resolveAndConnect])
 *   4. We connect and send pair_request
 *   5. On pair_ok → [onSuccess] is called with airclip_id + all paired devices
 *
 * For code-only mode (no QR scan):
 *   [probeAllForCode] connects to every discovered mDNS device in sequence and
 *   checks whose code matches. Then sends pair_request to the matching one.
 */
object PairingClient {

    private val gson    = Gson()
    private val listType = object : TypeToken<List<Map<String, String>>>() {}.type

    /**
     * Send a pair_request to the device at [host]:[port].
     * Call this after resolving the target's IP via mDNS (or directly if IP is known).
     */
    fun sendPairRequestToHost(
        host: String,
        port: Int = LAN_PORT,
        targetDeviceId: String,
        targetAirClipId: String,
        code: String,
        myDeviceId: String,
        myDeviceName: String,
        myPublicKey: String,
        httpClient: OkHttpClient,
        onSuccess: (airClipId: String, allDevices: List<PairedDevice>) -> Unit,
        onError: (reason: String) -> Unit,
    ) {
        val url     = "ws://$host:$port/"
        val request = Request.Builder().url(url).build()

        httpClient.newWebSocket(request, object : WebSocketListener() {

            override fun onOpen(webSocket: WebSocket, response: Response) {
                val msg = gson.toJson(mapOf(
                    "type"        to "pair_request",
                    "code"        to code,
                    "device_id"   to myDeviceId,
                    "device_name" to myDeviceName,
                    "public_key"  to myPublicKey,
                    "airclip_id"     to targetAirClipId,
                    "platform"    to "android",
                ))
                webSocket.send(msg)
                Log.d(TAG, "Sent pair_request to ${targetDeviceId.take(8)}")
            }

            override fun onMessage(webSocket: WebSocket, text: String) {
                try {
                    @Suppress("UNCHECKED_CAST")
                    val msg = gson.fromJson(text, Map::class.java) as? Map<String, Any>
                        ?: return onError("invalid JSON")

                    when (msg["type"]) {
                        "pair_ok" -> {
                            val airClipId = msg["airclip_id"] as? String
                                ?: return onError("missing airclip_id in pair_ok")

                            @Suppress("UNCHECKED_CAST")
                            val rawDevices = msg["all_devices"] as? List<Map<String, String>>
                                ?: emptyList()

                            val devices = rawDevices.map { d ->
                                PairedDevice(
                                    deviceId   = d["device_id"]   ?: "",
                                    deviceName = d["device_name"] ?: "",
                                    publicKey  = d["public_key"]  ?: "",
                                    platform   = d["platform"]    ?: "",
                                )
                            }.filter { it.deviceId.isNotEmpty() && it.publicKey.isNotEmpty() }

                            Log.d(TAG, "pair_ok — airclip_id=${airClipId.take(8)} devices=${devices.size}")
                            webSocket.close(1000, "bye")
                            onSuccess(airClipId, devices)
                        }

                        "pair_reject" -> {
                            val reason = msg["reason"] as? String ?: "rejected"
                            Log.w(TAG, "pair_reject: $reason")
                            webSocket.close(1000, "rejected")
                            onError(reason)
                        }

                        else -> {
                            Log.w(TAG, "Unexpected pair response: ${msg["type"]}")
                            webSocket.close(1002, "unexpected")
                            onError("unexpected response: ${msg["type"]}")
                        }
                    }
                } catch (e: Exception) {
                    Log.w(TAG, "onMessage error: ${e.message}")
                    onError(e.message ?: "parse error")
                }
            }

            override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {
                Log.w(TAG, "WS failure: ${t.message}")
                onError(t.message ?: "connection failed")
            }

            override fun onClosed(webSocket: WebSocket, code: Int, reason: String) {
                Log.d(TAG, "WS closed $code $reason")
            }
        })
    }

    /**
     * High-level entry point: look up [targetDeviceId] in the mDNS-discovered set
     * (from LanBrowser's resolved cache) and connect for pairing.
     *
     * For now, since we don't cache resolved IPs, this is a no-op placeholder.
     * The IP lookup is done externally — see [sendPairRequestToHost].
     */
    fun sendPairRequest(
        targetDeviceId: String,
        targetAirClipId: String,
        code: String,
        myDeviceId: String,
        myDeviceName: String,
        myPublicKey: String,
        httpClient: OkHttpClient,
        onSuccess: (airClipId: String, allDevices: List<PairedDevice>) -> Unit,
        onError: (reason: String) -> Unit,
    ) {
        // Resolved IP cache is populated by LanBrowser; look it up here
        val host = ResolvedHostCache.getHost(targetDeviceId)
        if (host == null) {
            onError("Device not found on LAN. Make sure both devices are on the same WiFi.")
            return
        }
        sendPairRequestToHost(
            host           = host,
            targetDeviceId = targetDeviceId,
            targetAirClipId   = targetAirClipId,
            code           = code,
            myDeviceId     = myDeviceId,
            myDeviceName   = myDeviceName,
            myPublicKey    = myPublicKey,
            httpClient     = httpClient,
            onSuccess      = onSuccess,
            onError        = onError,
        )
    }

    /**
     * Probe a specific host with an 8-digit code (for manual code entry flow).
     * Responds via [onFound] if the code matches, [onError] otherwise.
     */
    fun probeHostForCode(
        host: String,
        port: Int = LAN_PORT,
        code: String,
        httpClient: OkHttpClient,
        onFound: (
            deviceId: String,
            deviceName: String,
            publicKey: String,
            airClipId: String,
        ) -> Unit,
        onError: (String) -> Unit,
    ) {
        val url     = "ws://$host:$port/"
        val request = Request.Builder().url(url).build()

        httpClient.newWebSocket(request, object : WebSocketListener() {
            override fun onOpen(webSocket: WebSocket, response: Response) {
                webSocket.send(gson.toJson(mapOf("type" to "pair_probe", "code" to code)))
            }

            override fun onMessage(webSocket: WebSocket, text: String) {
                try {
                    @Suppress("UNCHECKED_CAST")
                    val msg = gson.fromJson(text, Map::class.java) as? Map<String, String>
                        ?: return onError("invalid JSON")

                    when (msg["type"]) {
                        "pair_info" -> {
                            val deviceId   = msg["device_id"]   ?: return onError("missing device_id")
                            val deviceName = msg["device_name"] ?: return onError("missing device_name")
                            val publicKey  = msg["public_key"]  ?: return onError("missing public_key")
                            val airClipId   = msg["airclip_id"]  ?: return onError("missing airclip_id")
                            webSocket.close(1000, "bye")
                            onFound(deviceId, deviceName, publicKey, airClipId)
                        }
                        "pair_reject" -> {
                            webSocket.close(1000, "rejected")
                            onError(msg["reason"] ?: "rejected")
                        }
                        else -> {
                            webSocket.close(1002, "unexpected")
                            onError("unexpected: ${msg["type"]}")
                        }
                    }
                } catch (e: Exception) { onError(e.message ?: "error") }
            }

            override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {
                onError(t.message ?: "failed")
            }

            override fun onClosed(webSocket: WebSocket, code: Int, reason: String) {}
        })
    }
}

/**
 * Simple cache of resolved device_id → IP address, populated by LanBrowser
 * whenever it resolves an mDNS service. Used by PairingClient to look up
 * the IP of a scanned QR device.
 */
object ResolvedHostCache {
    private val cache = java.util.concurrent.ConcurrentHashMap<String, String>()

    fun put(deviceId: String, host: String) { cache[deviceId] = host }
    fun getHost(deviceId: String): String?  = cache[deviceId]
    fun all(): Map<String, String> = cache.toMap()
    fun clear() = cache.clear()
}
