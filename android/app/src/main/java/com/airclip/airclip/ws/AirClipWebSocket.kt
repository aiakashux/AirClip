package com.airclip.airclip.ws

import com.airclip.airclip.util.RedactingLogger
import com.google.gson.Gson
import com.google.gson.JsonObject
import com.google.gson.JsonParser
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.Response
import okhttp3.WebSocket
import okhttp3.WebSocketListener
import java.util.concurrent.TimeUnit
import kotlin.math.min

// ---------------------------------------------------------------------------
// Protocol types (per docs/protocol.md §6)
// ---------------------------------------------------------------------------

/** One encrypted payload in a send_clipboard message. */
data class ClipboardPayload(
    val to_device_id: String,
    val ciphertext: String,   // base64
    val nonce: String         // base64 sentinel for sealed-box (no real nonce)
)

/** A deliver_clipboard message received from the server — stored encrypted, never decrypted here. */
data class DeliveredMessage(
    val messageId: String,
    val fromDeviceId: String,
    val ciphertext: String,   // base64 — DO NOT decrypt or log as plaintext
    val nonce: String,
    val seq: Long = 0L,       // MED 8: Long — monotonic per-account seq
    val receivedAtMs: Long = System.currentTimeMillis()
)

// ---------------------------------------------------------------------------
// Listener interface
// ---------------------------------------------------------------------------

interface AirClipWsListener {
    fun onConnected()
    fun onDisconnected(code: Int, reason: String)
    fun onDeliverClipboard(msg: DeliveredMessage)
    fun onLog(text: String)
    /** Called when the server rejects the WS upgrade with 401/403. No reconnect is attempted. */
    fun onAuthFailed() {}
    /** Called when the server sends a hello with the latest_seq. MED 8. */
    fun onHello(latestSeq: Long) {}
}

// ---------------------------------------------------------------------------
// WebSocket client
// ---------------------------------------------------------------------------

/**
 * Persistent WebSocket client for the AirClip relay.
 *
 * Auth rules (docs/protocol.md §5):
 *   - Token sent in Authorization header only — NEVER in query params.
 *   - [deviceToken] must be a device-scoped JWT (token_type="device").
 *   - Account tokens will be rejected by the server with close code 4001.
 *
 * Reconnection: exponential backoff, 1 s → 30 s cap.
 */
class AirClipWebSocket(
    private val wsBaseUrl: String,
    private val deviceToken: String,
    private val listener: AirClipWsListener
) {
    private val gson = Gson()

    private val httpClient = OkHttpClient.Builder()
        .pingInterval(20, TimeUnit.SECONDS)
        .build()

    @Volatile private var ws: WebSocket? = null
    @Volatile private var connected = false
    @Volatile private var shouldReconnect = false
    private var reconnectDelayMs = 1_000L

    // ------------------------------------------------------------------
    // Public API
    // ------------------------------------------------------------------

    fun connect() {
        shouldReconnect = true
        openSocket()
    }

    fun disconnect() {
        shouldReconnect = false
        ws?.close(1000, "Client disconnect")
        ws = null
        connected = false
    }

    fun isConnected(): Boolean = connected

    /**
     * Send a send_clipboard message (docs/protocol.md §6.1).
     * [payloads] must already be encrypted — no plaintext reaches this method.
     */
    fun sendClipboard(payloads: List<ClipboardPayload>) {
        val msg = mapOf("type" to "send_clipboard", "payloads" to payloads)
        sendJson(msg)
        RedactingLogger.info("WS → send_clipboard payloads=${payloads.size}")
    }

    /** Send an ack message (docs/protocol.md §6.1). */
    fun sendAck(messageId: String) {
        sendJson(mapOf("type" to "ack", "message_id" to messageId))
        RedactingLogger.info("WS → ack message_id=$messageId")
    }

    // ------------------------------------------------------------------
    // Internal
    // ------------------------------------------------------------------

    private fun sendJson(obj: Any) {
        val json = gson.toJson(obj)
        ws?.send(json) ?: RedactingLogger.warn("WS: send attempted while not connected")
    }

    private fun openSocket() {
        // Authorization header — device token only; NO token in query params (protocol constraint)
        val request = Request.Builder()
            .url(wsBaseUrl)
            .header("Authorization", "Bearer $deviceToken")
            .build()

        ws = httpClient.newWebSocket(request, object : WebSocketListener() {
            override fun onOpen(webSocket: WebSocket, response: Response) {
                connected = true
                reconnectDelayMs = 1_000L
                RedactingLogger.info("WS: connected")
                listener.onConnected()
                listener.onLog("WebSocket connected")
            }

            override fun onMessage(webSocket: WebSocket, text: String) {
                handleMessage(text)
            }

            override fun onClosing(webSocket: WebSocket, code: Int, reason: String) {
                webSocket.close(1000, null)
            }

            override fun onClosed(webSocket: WebSocket, code: Int, reason: String) {
                connected = false
                RedactingLogger.info("WS: closed code=$code reason=$reason")
                listener.onDisconnected(code, reason)
                listener.onLog("WS closed: $code $reason")
                scheduleReconnect()
            }

            override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {
                connected = false
                val authFailed = response?.code == 401 || response?.code == 403
                RedactingLogger.error("WS: failure code=${response?.code ?: -1}", t)
                if (authFailed) {
                    shouldReconnect = false
                    listener.onAuthFailed()
                    listener.onLog("WS auth rejected by server")
                } else {
                    listener.onDisconnected(-1, t.message ?: "failure")
                    listener.onLog("WS error: ${t.message}")
                    scheduleReconnect()
                }
            }
        })
    }

    private fun handleMessage(text: String) {
        try {
            val obj: JsonObject = JsonParser.parseString(text).asJsonObject
            when (val type = obj.get("type")?.asString) {

                "hello" -> {
                    // latest_seq arrives as a JSON string — asLong handles string primitives via Long.parseLong
                    val latestSeq = obj.get("latest_seq")?.asLong ?: 0L  // MED 8: Long
                    RedactingLogger.info("WS ← hello latest_seq=$latestSeq")
                    listener.onLog("WS hello: latest_seq=$latestSeq")
                    listener.onHello(latestSeq)
                }

                "deliver_clipboard" -> {
                    val msg = DeliveredMessage(
                        messageId    = obj.getStr("message_id"),
                        fromDeviceId = obj.getStr("from_device_id"),
                        ciphertext   = obj.getStr("ciphertext"),
                        nonce        = obj.getStr("nonce"),
                        seq          = obj.get("seq")?.asLong ?: 0L  // MED 8: Long
                    )
                    // Log only hash/length — never ciphertext contents
                    RedactingLogger.logCiphertext("deliver_clipboard ciphertext", msg.ciphertext)
                    RedactingLogger.info("WS ← deliver_clipboard from=${msg.fromDeviceId} msgId=${msg.messageId} seq=${msg.seq}")
                    // ACK is sent by the ViewModel ONLY after successful decrypt — not here.
                    listener.onDeliverClipboard(msg)
                }

                "device_pending" -> {
                    val devId   = obj.get("device_id")?.asString ?: "?"
                    val devName = obj.get("device_name")?.asString ?: "unknown"
                    RedactingLogger.info("WS ← device_pending id=$devId name=$devName")
                    listener.onLog("Pending device: $devName (${devId.take(8)}…)")
                }

                "error" -> {
                    val errMsg = obj.get("message")?.asString ?: "unknown server error"
                    RedactingLogger.warn("WS ← server error: $errMsg")
                    listener.onLog("Server error: $errMsg")
                }

                else -> {
                    RedactingLogger.info("WS ← unknown type=$type")
                    listener.onLog("Unknown message type: $type")
                }
            }
        } catch (e: Exception) {
            RedactingLogger.error("WS: message parse error", e)
        }
    }

    private fun scheduleReconnect() {
        if (!shouldReconnect) return
        val delay = reconnectDelayMs
        reconnectDelayMs = min(reconnectDelayMs * 2, 30_000L)
        RedactingLogger.info("WS: reconnect scheduled in ${delay}ms")
        listener.onLog("Reconnecting in ${delay / 1000}s…")
        Thread {
            Thread.sleep(delay)
            if (shouldReconnect) openSocket()
        }.also { it.isDaemon = true }.start()
    }

    private fun JsonObject.getStr(key: String): String =
        get(key)?.asString ?: error("WS message missing field: $key")
}
