package com.airclip.airclip

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.util.Log
import com.airclip.airclip.crypto.KeyManager
import com.airclip.airclip.crypto.SealedBox
import com.airclip.airclip.lan.LanBrowser
import com.airclip.airclip.lan.LanServer
import com.airclip.airclip.lan.PeerManager
import com.airclip.airclip.widget.WidgetState
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.withTimeoutOrNull
import okhttp3.OkHttpClient
import java.util.UUID

private const val TAG = "SyncEngine"

/**
 * Orchestrates LAN sync: starts/stops [LanServer] + [LanBrowser], handles inbound clips,
 * and exposes clip history as a [StateFlow] for the ViewModel to collect.
 *
 * Trust model: airclip_id-based (no server). Any device that shares our airclip_id
 * and survives the LAN handshake is a trusted peer.
 */
object SyncEngine {

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    private val _clipHistory = MutableStateFlow<List<ClipItemRecord>>(emptyList())
    val clipHistory: StateFlow<List<ClipItemRecord>> = _clipHistory

    val connectedPeerCount: StateFlow<Int> = PeerManager.connectedCount

    private var appContext: Context?     = null
    private var keyManager: KeyManager?  = null
    private var httpClient: OkHttpClient? = null

    private val recentHashes = RecentHashSet()
    private val lifecycleGate = SyncEngineLifecycleGate()
    private var connectJob: Job? = null
    private var peerCountJob: Job? = null
    private var heartbeatJob: Job? = null

    // ── Lifecycle ─────────────────────────────────────────────────────────────

    /**
     * Call once after pairing completes (airclip_id + device_id + keypair are ready).
     * Safe to call again after a reset.
     */
    fun init(context: Context, keyManager: KeyManager, client: OkHttpClient) {
        appContext       = context.applicationContext
        this.keyManager  = keyManager
        this.httpClient  = client

        PeerManager.onInboundClip  = ::processInboundClip
        PeerManager.onHistoryClip  = ::processHistoryClip
        PeerManager.onPeerSeen = { deviceId ->
            appContext?.let { ctx ->
                scope.launch { AirClipIdentity.touchDevice(ctx, deviceId) }
            }
        }
        PeerManager.onPeerRegistered = { peer ->
            pushHistoryToPeer(peer)
        }
    }

    /** Start LAN server + browser. */
    fun connect() {
        if (!SyncRuntimePolicy.shouldRunLanService(AirClipIdentity.isPaired, Prefs.syncMode)) {
            disconnect()
            return
        }
        if (!lifecycleGate.requestConnect()) return

        val km = keyManager
        val client = httpClient
        val ctx = appContext
        if (km == null || client == null || ctx == null) {
            lifecycleGate.requestDisconnect()
            Log.w(TAG, "SyncEngine connect skipped — runtime not initialized")
            return
        }

        connectJob = scope.launch {
            if (!lifecycleGate.runIfConnectRequested { LanServer.start(km) }) {
                return@launch
            }

            if (!lifecycleGate.runIfConnectRequested { LanBrowser.start(ctx, client, km) }) {
                return@launch
            }

            peerCountJob?.cancel()
            peerCountJob = scope.launch {
                PeerManager.connectedCount.collect { count ->
                    val cur = WidgetState.getState(ctx)
                    when {
                        count == 0 && cur != WidgetState.NO_DEVICES -> {
                            WidgetState.save(ctx, WidgetState.NO_DEVICES)
                            WidgetState.notifyWidgets(ctx)
                        }
                        count > 0 && cur == WidgetState.NO_DEVICES -> {
                            WidgetState.save(ctx, WidgetState.SYNCED)
                            WidgetState.notifyWidgets(ctx)
                        }
                    }
                }
            }

            heartbeatJob?.cancel()
            heartbeatJob = scope.launch {
                while (isActive && Prefs.syncMode.keepsLanServiceRunning) {
                    delay(15_000)
                    PeerManager.sendHeartbeats()
                }
            }
            Log.d(TAG, "SyncEngine connected — server+browser started")
        }
    }

    /** Stop all LAN components and disconnect peers. */
    fun disconnect() {
        lifecycleGate.requestDisconnect()
        connectJob?.cancel()
        connectJob = null
        peerCountJob?.cancel()
        peerCountJob = null
        heartbeatJob?.cancel()
        heartbeatJob = null
        appContext?.let { LanBrowser.stop(it) }
        LanServer.stop()
        PeerManager.disconnectAll()
        Log.d(TAG, "SyncEngine disconnected")
    }

    suspend fun awaitConnectedPeer(timeoutMs: Long = 2_000L): Boolean {
        if (PeerManager.connectedCount.value > 0) return true
        return withTimeoutOrNull(timeoutMs) {
            PeerManager.connectedCount.first { it > 0 }
            true
        } ?: false
    }

    // ── Sending ───────────────────────────────────────────────────────────────

    /**
     * Encrypt [text] and broadcast to all authenticated peers.
     * Always saves to local history, even if no peers are connected.
     */
    fun sendClip(text: String, sensitiveOverride: Boolean = false) {
        if (!Prefs.syncMode.allowsManualSend) {
            Log.d(TAG, "Clip send blocked by sync mode")
            return
        }
        if (!sensitiveOverride) {
            val assessment = SensitiveClipboardClassifier.classify(text)
            val action = assessment.primaryFinding
                ?.let { Prefs.sensitiveRule(it.category) }
                ?: SensitiveRuleAction.ASK
            if (SensitiveClipboardPolicy.decide(
                    assessment,
                    SensitiveSendIntent.MANUAL,
                    action,
                ) != SensitiveSendDecision.ALLOW
            ) {
                Log.d(TAG, "Clip send blocked by sensitive-content policy")
                return
            }
        }
        scope.launch {
            if (!Prefs.syncMode.allowsManualSend) return@launch
            try {
                val plain = text.toByteArray(Charsets.UTF_8)
                val hash  = plain.sha256Hex()
                if (recentHashes.isKnown(hash)) return@launch
                recentHashes.record(hash)

                // Always persist locally
                val record = ClipItemRecord(
                    messageId    = "local-${UUID.randomUUID()}",
                    seq          = 0L,
                    fromDeviceId = AirClipIdentity.deviceId ?: "self",
                    timestampMs  = System.currentTimeMillis(),
                    cipherHash   = hash.take(16),
                    preview      = text.take(40),
                    contentText  = text,
                    kind         = detectClipKind(text).name,
                )
                appContext?.let { ctx ->
                    val updated = ClipHistoryStore.merge(ctx, listOf(record))
                    _clipHistory.value = updated
                }

                // Broadcast to peers if any connected
                val peers = PeerManager.connectedCount.value
                if (peers > 0) {
                    PeerManager.broadcast(plain)
                    appContext?.let { ctx ->
                        WidgetState.save(ctx, WidgetState.SYNCED)
                        WidgetState.notifyWidgets(ctx)
                    }
                    Log.d(TAG, "Clip sent hash=${hash.take(12)} len=${text.length} peers=$peers")
                } else {
                    Log.d(TAG, "Clip saved locally (no peers) hash=${hash.take(12)}")
                }
            } catch (e: Exception) {
                Log.w(TAG, "sendClip error: ${e.message}")
            }
        }
    }

    // ── Receiving ─────────────────────────────────────────────────────────────

    private fun processInboundClip(ciphertext: String, nonce: String, fromDeviceId: String) {
        if (!Prefs.syncMode.keepsLanServiceRunning) {
            Log.d(TAG, "Inbound clip ignored while paused")
            return
        }
        val km  = keyManager ?: return
        val ctx = appContext  ?: return

        scope.launch {
            if (!Prefs.syncMode.keepsLanServiceRunning) return@launch
            try {
                val plain = SealedBox.decryptForSelf(
                    ciphertext,
                    km.getPublicKeyBytes(),
                    km.getPrivateKeyBytes(),
                )
                val payload = ClipboardWirePayload.decode(String(plain, Charsets.UTF_8))
                val text = payload.text
                val hashSource = payload.imageDataBase64 ?: text
                val hash = hashSource.toByteArray(Charsets.UTF_8).sha256Hex()

                if (recentHashes.isKnown(hash)) {
                    Log.d(TAG, "Echo suppressed from ${fromDeviceId.take(8)}")
                    return@launch
                }
                recentHashes.record(hash)

                val record = ClipItemRecord(
                    messageId    = "lan-${UUID.randomUUID()}",
                    seq          = 0L,
                    fromDeviceId = fromDeviceId,
                    timestampMs  = System.currentTimeMillis(),
                    cipherHash   = hash.take(16),
                    preview      = text.take(40),
                    contentText  = text,
                    kind         = payload.kind.name,
                    imageDataBase64 = payload.imageDataBase64,
                )
                if (payload.kind != ClipKind.IMAGE || !ImageClipboard.copy(ctx, record)) {
                    val clip = ClipData.newPlainText("AirClip", text)
                    val cm = ctx.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                    cm.setPrimaryClip(clip)
                }
                val updated = ClipHistoryStore.merge(ctx, listOf(record))
                _clipHistory.value = updated

                WidgetState.save(ctx, WidgetState.PENDING, preview = text.take(40), lastText = text)
                WidgetState.notifyWidgets(ctx)

                Log.d(TAG, "Inbound clip from ${fromDeviceId.take(8)} len=${text.length}")
            } catch (e: Exception) {
                Log.w(TAG, "processInboundClip error: ${e.message}")
            }
        }
    }

    // ── History from peer (no clipboard write) ────────────────────────────────

    /**
     * Process a history_clip pushed by a peer after auth.
     * Decrypts and merges into local history only — does NOT write to system clipboard.
     */
    private fun processHistoryClip(
        ciphertext: String, nonce: String,
        ts: Long, msgId: String, fromDeviceId: String
    ) {
        val km  = keyManager ?: return
        val ctx = appContext  ?: return
        scope.launch {
            try {
                val plain = SealedBox.decryptForSelf(
                    ciphertext, km.getPublicKeyBytes(), km.getPrivateKeyBytes()
                )
                val payload = ClipboardWirePayload.decode(String(plain, Charsets.UTF_8))
                val text = payload.text
                val hashSource = payload.imageDataBase64 ?: text
                val hash = hashSource.toByteArray(Charsets.UTF_8).sha256Hex()
                val record = ClipItemRecord(
                    messageId    = msgId,
                    seq          = 0L,
                    fromDeviceId = fromDeviceId,
                    timestampMs  = ts,
                    cipherHash   = hash.take(16),
                    preview      = text.take(40),
                    contentText  = text,
                    kind         = payload.kind.name,
                    imageDataBase64 = payload.imageDataBase64,
                )
                val updated = ClipHistoryStore.merge(ctx, listOf(record))
                _clipHistory.value = updated
                Log.d(TAG, "History clip merged from ${fromDeviceId.take(8)}")
            } catch (e: Exception) {
                Log.w(TAG, "processHistoryClip error: ${e.message}")
            }
        }
    }

    private fun pushHistoryToPeer(peer: com.airclip.airclip.lan.Peer) {
        val ctx = appContext ?: return
        scope.launch {
            try {
                val items = ClipHistoryStore.load(ctx).take(20)
                for (record in items) {
                    val plain = ClipboardWirePayload.encode(record).toByteArray(Charsets.UTF_8)
                    val enc = SealedBox.encryptForRecipient(plain, peer.publicKey)
                    val json = PeerManager.gson.toJson(
                        mapOf(
                            "type" to "history_clip",
                            "ciphertext" to enc.ciphertextBase64,
                            "nonce" to enc.nonce,
                            "ts" to record.timestampMs.toString(),
                            "msg_id" to record.messageId,
                            "from_device_id" to record.fromDeviceId,
                        )
                    )
                    peer.send(json)
                }
                Log.d(TAG, "History backfill pushed to ${peer.deviceId.take(8)} count=${items.size}")
            } catch (e: Exception) {
                Log.w(TAG, "pushHistoryToPeer error for ${peer.deviceId.take(8)}: ${e.message}")
            }
        }
    }

    // ── Suppress echo on tap-to-copy ─────────────────────────────────────────

    /**
     * Pre-record [text]'s hash to suppress the upcoming clipboard listener event.
     * Call BEFORE writing [text] to the system clipboard from a tap-to-copy action.
     */
    fun suppressHistoryItem(record: ClipItemRecord) {
        val hashSource = record.imageDataBase64 ?: record.displayText
        val hash = hashSource.toByteArray(Charsets.UTF_8).sha256Hex()
        recentHashes.record(hash)
    }

    // ── History ───────────────────────────────────────────────────────────────

    fun loadHistory(context: Context) {
        scope.launch {
            _clipHistory.value = ClipHistoryStore.load(context)
        }
    }

    fun clearHistory(context: Context) {
        scope.launch {
            ClipHistoryStore.clear(context)
            _clipHistory.value = emptyList()
        }
    }
}

// ── SHA-256 utility ───────────────────────────────────────────────────────────

private fun ByteArray.sha256Hex(): String {
    val md = java.security.MessageDigest.getInstance("SHA-256")
    return md.digest(this).joinToString("") { "%02x".format(it) }
}

/** Bounded recent-hash set to suppress duplicate or echoed clipboard items. */
private class RecentHashSet(private val maxSize: Int = 50) {
    private val hashes = ArrayDeque<String>(maxSize + 1)

    @Synchronized fun isKnown(hash: String): Boolean = hashes.contains(hash)

    @Synchronized fun record(hash: String) {
        if (hashes.contains(hash)) return
        hashes.addLast(hash)
        if (hashes.size > maxSize) hashes.removeFirst()
    }
}
