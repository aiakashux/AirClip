package com.airclip.airclip

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.util.Log
import com.airclip.airclip.crypto.KeyManager
import com.airclip.airclip.crypto.SealedBox
import com.airclip.airclip.device.WifiNetworkName
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
import java.io.File
import java.io.RandomAccessFile

data class FileTransferStatus(
    val phase: String,
    val received: Long,
    val total: Long,
    val error: String? = null,
    val temporaryPreview: Boolean = false,
)

const val FILE_PREVIEW_MAX_BYTES = 3L * 1024L * 1024L

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
    private val _fileTransfers = MutableStateFlow<Map<String, FileTransferStatus>>(emptyMap())
    val fileTransfers: StateFlow<Map<String, FileTransferStatus>> = _fileTransfers
    private val _remoteInsertionId = MutableStateFlow<String?>(null)
    val remoteInsertionId: StateFlow<String?> = _remoteInsertionId

    val connectedPeerCount: StateFlow<Int> = PeerManager.connectedCount

    private var appContext: Context?     = null
    private var keyManager: KeyManager?  = null
    private var httpClient: OkHttpClient? = null

    private val recentHashes = RecentHashSet()
    private val lifecycleGate = SyncEngineLifecycleGate()
    private var connectJob: Job? = null
    private var peerCountJob: Job? = null
    private var heartbeatJob: Job? = null
    private var discoveryRefreshJob: Job? = null
    private var localActivityMs: Long = 0L

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
        PeerManager.onHistoryDelete = ::processHistoryDelete
        PeerManager.onHistoryClear = ::processHistoryClear
        PeerManager.onHistoryRequest = { deviceId ->
            PeerManager.connectedPeersSnapshot()
                .firstOrNull { it.deviceId == deviceId }
                ?.let(::pushHistoryToPeer)
        }
        PeerManager.onFileMessage = { deviceId, message ->
            scope.launch { handleFileMessage(deviceId, message) }
        }
        PeerManager.onPeerSeen = { deviceId, wifiNetwork ->
            appContext?.let { ctx ->
                scope.launch { AirclipIdentity.touchDevice(ctx, deviceId, wifiNetwork) }
            }
        }
        PeerManager.onPeerActivity = { deviceId, timestampMs ->
            appContext?.let { ctx ->
                scope.launch { AirclipIdentity.markDeviceActive(ctx, deviceId, timestampMs) }
            }
        }
        PeerManager.onPeerRegistered = { peer ->
            appContext?.let { ctx ->
                scope.launch {
                    val existing = AirclipIdentity.pairedDevices[peer.deviceId]
                    AirclipIdentity.addOrUpdateDevice(
                        ctx,
                        PairedDevice(
                            deviceId = peer.deviceId,
                            deviceName = peer.deviceName.ifBlank { existing?.deviceName ?: peer.deviceId.take(8) },
                            publicKey = peer.publicKey,
                            platform = peer.platform.ifBlank { existing?.platform ?: "" },
                            lastSeenMs = System.currentTimeMillis(),
                            lastActiveMs = existing?.lastActiveMs ?: 0L,
                            wifiNetwork = peer.wifiNetwork ?: existing?.wifiNetwork,
                        )
                    )
                }
            }
            pushHistoryMutationsToPeer(peer)
            pushHistoryToPeer(peer)
            pushLocalActivityToPeer(peer)
        }
    }

    /** Start LAN server + browser. */
    fun connect() {
        if (!SyncRuntimePolicy.shouldRunLanService(AirclipIdentity.isPaired, Prefs.syncMode)) {
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
            if (!lifecycleGate.runIfConnectRequested { LanServer.start(ctx, km) }) {
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
                    if (PeerManager.connectedCount.value == 0) {
                        refreshConnections()
                    } else {
                        PeerManager.sendHeartbeats(WifiNetworkName.current(ctx).name)
                    }
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
        discoveryRefreshJob?.cancel()
        discoveryRefreshJob = null
        appContext?.let { LanBrowser.stop(it) }
        LanServer.stop()
        PeerManager.disconnectAll()
        Log.d(TAG, "SyncEngine disconnected")
    }

    /** Restart discovery without tearing down healthy server or peer sockets. */
    fun refreshConnections() {
        if (!lifecycleGate.isConnectRequested()) return
        val ctx = appContext ?: return
        val client = httpClient ?: return
        val km = keyManager ?: return
        discoveryRefreshJob?.cancel()
        discoveryRefreshJob = scope.launch { LanBrowser.start(ctx, client, km) }
    }

    fun reconnect() {
        disconnect()
        connect()
    }

    suspend fun awaitConnectedPeer(timeoutMs: Long = 2_000L): Boolean {
        if (PeerManager.connectedCount.value > 0) return true
        return withTimeoutOrNull(timeoutMs) {
            PeerManager.connectedCount.first { it > 0 }
            true
        } ?: false
    }

    fun refreshHistorySync() {
        val ctx = appContext ?: return
        loadHistory(ctx)
        PeerManager.requestHistoryFromPeers()
        PeerManager.connectedPeersSnapshot().forEach { peer ->
            pushHistoryToPeer(peer)
        }
    }

    fun markLocalActivity() {
        if (!AirclipIdentity.isPaired) return
        localActivityMs = System.currentTimeMillis()
        PeerManager.broadcastAppActivity(localActivityMs)
    }

    // ── Sending ───────────────────────────────────────────────────────────────

    /**
     * Encrypt [text] and broadcast to all authenticated peers.
     * Always saves to local history, even if no peers are connected.
     */
    fun sendClip(text: String) {
        if (!Prefs.syncMode.allowsManualSend) {
            Log.d(TAG, "Clip send blocked by sync mode")
            return
        }
        markLocalActivity()
        scope.launch {
            if (!Prefs.syncMode.allowsManualSend) return@launch
            try {
                val plain = text.toByteArray(Charsets.UTF_8)
                val hash  = plain.sha256Hex()
                if (recentHashes.isKnown(hash)) return@launch
                recentHashes.record(hash)

                // Always persist locally
                val record = ClipItemRecord(
                    messageId    = UUID.randomUUID().toString(),
                    seq          = 0L,
                    fromDeviceId = AirclipIdentity.deviceId ?: "self",
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
                    PeerManager.broadcast(plain, record.messageId, record.timestampMs, record.fromDeviceId)
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

    fun sendImageClip(label: String, imageDataBase64: String) {
        if (!Prefs.syncMode.allowsManualSend) {
            Log.d(TAG, "Image clip send blocked by sync mode")
            return
        }
        markLocalActivity()
        scope.launch {
            if (!Prefs.syncMode.allowsManualSend) return@launch
            try {
                val displayText = label.ifBlank { "Shared image" }
                val hash = imageDataBase64.toByteArray(Charsets.UTF_8).sha256Hex()
                if (recentHashes.isKnown(hash)) return@launch
                recentHashes.record(hash)

                val record = ClipItemRecord(
                    messageId = UUID.randomUUID().toString(),
                    seq = 0L,
                    fromDeviceId = AirclipIdentity.deviceId ?: "self",
                    timestampMs = System.currentTimeMillis(),
                    cipherHash = hash.take(16),
                    preview = displayText.take(40),
                    contentText = displayText,
                    kind = ClipKind.IMAGE.name,
                    imageDataBase64 = imageDataBase64,
                )
                appContext?.let { ctx ->
                    val updated = ClipHistoryStore.merge(ctx, listOf(record))
                    _clipHistory.value = updated
                }

                val peers = PeerManager.connectedCount.value
                if (peers > 0) {
                    val plain = ClipboardWirePayload.encode(record).toByteArray(Charsets.UTF_8)
                    PeerManager.broadcast(plain, record.messageId, record.timestampMs, record.fromDeviceId)
                    appContext?.let { ctx ->
                        WidgetState.save(ctx, WidgetState.SYNCED)
                        WidgetState.notifyWidgets(ctx)
                    }
                    Log.d(TAG, "Image clip sent hash=${hash.take(12)} peers=$peers")
                } else {
                    Log.d(TAG, "Image clip saved locally (no peers) hash=${hash.take(12)}")
                }
            } catch (e: Exception) {
                Log.w(TAG, "sendImageClip error: ${e.message}")
            }
        }
    }

    fun sendFileClip(file: FileClipMetadata, sourcePath: String) {
        if (!Prefs.syncMode.allowsManualSend) return
        scope.launch {
            val source = File(sourcePath)
            if (!source.isFile || source.length() != file.size) return@launch
            val record = ClipItemRecord(
                messageId = UUID.randomUUID().toString(),
                seq = 0L,
                fromDeviceId = AirclipIdentity.deviceId ?: "self",
                timestampMs = System.currentTimeMillis(),
                cipherHash = file.id.toByteArray().sha256Hex().take(16),
                preview = file.name.take(40),
                contentText = file.name,
                kind = ClipKind.FILE.name,
                file = file,
                sourceFilePath = sourcePath,
            )
            appContext?.let { ctx ->
                _clipHistory.value = ClipHistoryStore.merge(ctx, listOf(record))
            }
            if (PeerManager.connectedCount.value > 0) {
                PeerManager.broadcast(
                    ClipboardWirePayload.encode(record).toByteArray(Charsets.UTF_8),
                    record.messageId, record.timestampMs, record.fromDeviceId,
                    type = "file_clip",
                )
            }
        }
    }

    fun availableFile(record: ClipItemRecord): File? {
        val file = record.file ?: return null
        val source = record.sourceFilePath?.let(::File)
        if (source?.isFile == true) return source
        val destination = downloadedFile(file)
        return destination.takeIf { it.isFile && it.length() == file.size }
    }

    private fun downloadedFile(file: FileClipMetadata): File {
        val directory = File(requireNotNull(appContext).filesDir, "downloaded-files").apply { mkdirs() }
        val extension = file.name.substringAfterLast('.', "")
            .takeIf { it.matches(Regex("[A-Za-z0-9]{1,12}")) }
        return File(directory, file.id + (extension?.let { ".$it" } ?: ""))
    }

    private fun previewFile(file: FileClipMetadata): File {
        val directory = File(requireNotNull(appContext).cacheDir, "file-previews").apply { mkdirs() }
        val extension = file.name.substringAfterLast('.', "")
            .takeIf { it.matches(Regex("[A-Za-z0-9]{1,12}")) }
        return File(directory, file.id + (extension?.let { ".$it" } ?: ""))
    }

    fun availablePreviewFile(record: ClipItemRecord): File? {
        val file = record.file ?: return null
        if (file.size > FILE_PREVIEW_MAX_BYTES) return null
        if (record.sourceFilePath != null) return File(record.sourceFilePath).takeIf { it.isFile }
        return previewFile(file).takeIf { it.isFile && it.length() == file.size }
    }

    fun previewFile(record: ClipItemRecord) {
        val file = record.file ?: return
        if (file.size > FILE_PREVIEW_MAX_BYTES || record.sourceFilePath != null) return
        val peer = PeerManager.connectedPeersSnapshot().firstOrNull { it.deviceId == record.fromDeviceId }
        if (peer == null) {
            _fileTransfers.value += file.id to FileTransferStatus("failed", 0, file.size, "Source device is offline", true)
            return
        }
        val destination = previewFile(file)
        if (destination.isFile && destination.length() == file.size) return
        val partial = File(destination.path + ".part")
        if (partial.length() > file.size) partial.delete()
        val offset = partial.takeIf { it.isFile }?.length() ?: 0L
        _fileTransfers.value += file.id to FileTransferStatus("downloading", offset, file.size, temporaryPreview = true)
        peer.send(PeerManager.gson.toJson(mapOf(
            "type" to "file_request", "file_id" to file.id, "offset" to offset.toString(),
            "preview_limit" to file.size.toString(),
        )))
    }

    fun clearPreviewFile(record: ClipItemRecord) {
        val file = record.file ?: return
        if (record.sourceFilePath == null) {
            val destination = previewFile(file)
            destination.delete()
            File(destination.path + ".part").delete()
        }
        if (_fileTransfers.value[file.id]?.temporaryPreview == true) {
            _fileTransfers.value -= file.id
        }
    }

    fun downloadFile(record: ClipItemRecord) {
        val file = record.file ?: return
        val peer = PeerManager.connectedPeersSnapshot().firstOrNull { it.deviceId == record.fromDeviceId }
        if (peer == null) {
            _fileTransfers.value += file.id to FileTransferStatus("failed", 0, file.size, "Source device is offline")
            return
        }
        val partial = File(downloadedFile(file).path + ".part")
        if (partial.length() > file.size) partial.delete()
        val offset = partial.takeIf { it.isFile }?.length() ?: 0L
        _fileTransfers.value += file.id to FileTransferStatus("downloading", offset, file.size)
        peer.send(PeerManager.gson.toJson(mapOf(
            "type" to "file_request", "file_id" to file.id, "offset" to offset.toString(),
        )))
    }

    private suspend fun handleFileMessage(deviceId: String, message: Map<String, String>) {
        when (message["type"]) {
            "file_request" -> handleFileRequest(deviceId, message)
            "file_chunk" -> handleFileChunk(deviceId, message)
        }
    }

    private suspend fun handleFileRequest(deviceId: String, message: Map<String, String>) {
        val id = message["file_id"] ?: return
        val peer = PeerManager.connectedPeersSnapshot().firstOrNull { it.deviceId == deviceId } ?: return
        val record = _clipHistory.value.firstOrNull { it.file?.id == id && it.sourceFilePath != null }
        val source = record?.sourceFilePath?.let(::File)
        val file = record?.file
        val offset = message["offset"]?.toLongOrNull()
        if (source?.isFile != true || file == null || source.length() != file.size ||
            offset == null || offset < 0 || offset > file.size) {
            peer.send(PeerManager.gson.toJson(mapOf("type" to "file_chunk", "file_id" to id, "error" to "File unavailable")))
            return
        }
        val previewLimitRaw = message["preview_limit"]
        val previewLimit = previewLimitRaw?.toLongOrNull()
        val transferLimit = if (previewLimitRaw != null) {
            previewLimit?.takeIf { it in 0..FILE_PREVIEW_MAX_BYTES && it == file.size }
                ?: run {
                    peer.send(PeerManager.gson.toJson(mapOf("type" to "file_chunk", "file_id" to id, "error" to "Preview unavailable")))
                    return
                }
        } else file.size
        if (offset > transferLimit) {
            peer.send(PeerManager.gson.toJson(mapOf("type" to "file_chunk", "file_id" to id, "error" to "Preview unavailable")))
            return
        }
        runCatching {
            val bytes = ByteArray(minOf(512 * 1024L, transferLimit - offset).toInt())
            RandomAccessFile(source, "r").use { reader ->
                reader.seek(offset)
                reader.readFully(bytes)
            }
            val ciphertext = if (bytes.isEmpty()) "" else SealedBox.encryptForRecipient(bytes, peer.publicKey).ciphertextBase64
            peer.send(PeerManager.gson.toJson(mapOf(
                "type" to "file_chunk", "file_id" to id, "offset" to offset.toString(),
                "ciphertext" to ciphertext,
                "done" to (offset + bytes.size >= transferLimit).toString(),
                "preview_only" to (previewLimit != null).toString(),
            )))
        }.onFailure {
            peer.send(PeerManager.gson.toJson(mapOf("type" to "file_chunk", "file_id" to id, "error" to "File unavailable")))
        }
    }

    private suspend fun handleFileChunk(deviceId: String, message: Map<String, String>) {
        val id = message["file_id"] ?: return
        val state = _fileTransfers.value[id] ?: return
        if (state.phase != "downloading") return
        val record = _clipHistory.value.firstOrNull { it.file?.id == id && it.fromDeviceId == deviceId } ?: return
        val file = record.file ?: return
        val failure = message["error"]
        if (failure != null) {
            _fileTransfers.value += id to state.copy(phase = "failed", error = failure)
            return
        }
        val offset = message["offset"]?.toLongOrNull()
        if (offset != state.received) return
        val km = keyManager ?: return
        val bytes = runCatching {
            val ciphertext = message["ciphertext"].orEmpty()
            if (ciphertext.isEmpty() && file.size == 0L) ByteArray(0) else
                SealedBox.decryptForSelf(ciphertext, km.getPublicKeyBytes(), km.getPrivateKeyBytes())
        }.getOrNull() ?: return
        if (offset + bytes.size > file.size) return
        val previewOnly = message["preview_only"] == "true" || state.temporaryPreview
        if (previewOnly && file.size > FILE_PREVIEW_MAX_BYTES) return
        val destination = if (previewOnly) previewFile(file) else downloadedFile(file)
        val partial = File(destination.path + ".part")
        runCatching {
            RandomAccessFile(partial, "rw").use { writer ->
                writer.seek(offset)
                writer.write(bytes)
            }
            val received = offset + bytes.size
            if (message["done"] == "true") {
                check(received == file.size)
                if (destination.exists()) destination.delete()
                check(partial.renameTo(destination))
                _fileTransfers.value += id to FileTransferStatus(if (previewOnly) "previewed" else "downloaded", received, file.size, temporaryPreview = previewOnly)
            } else {
                _fileTransfers.value += id to FileTransferStatus("downloading", received, file.size, temporaryPreview = previewOnly)
                val peer = PeerManager.connectedPeersSnapshot().firstOrNull { it.deviceId == deviceId } ?: return
                peer.send(PeerManager.gson.toJson(mapOf(
                    "type" to "file_request", "file_id" to id, "offset" to received.toString(),
                    "preview_limit" to if (previewOnly) file.size.toString() else null,
                )))
            }
        }.onFailure {
            _fileTransfers.value += id to state.copy(phase = "failed", error = "Could not save file")
        }
    }

    // ── Receiving ─────────────────────────────────────────────────────────────

    private fun processInboundClip(
        ciphertext: String,
        nonce: String,
        fromDeviceId: String,
        timestampMs: Long,
        messageId: String,
    ) {
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
                    messageId    = messageId,
                    seq          = 0L,
                    fromDeviceId = fromDeviceId,
                    timestampMs  = timestampMs,
                    cipherHash   = hash.take(16),
                    preview      = text.take(40),
                    contentText  = text,
                    kind         = payload.kind.name,
                    imageDataBase64 = payload.imageDataBase64,
                    file = payload.file,
                )
                if (payload.kind == ClipKind.FILE) {
                    // A remote file entry is metadata only until the user downloads it.
                } else if (payload.kind != ClipKind.IMAGE || !ImageClipboard.copy(ctx, record)) {
                    val clip = ClipData.newPlainText("Airclip", text)
                    val cm = ctx.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                    cm.setPrimaryClip(clip)
                }
                val updated = ClipHistoryStore.merge(ctx, listOf(record))
                _remoteInsertionId.value = messageId
                _clipHistory.value = updated
                scope.launch {
                    delay(350)
                    if (_remoteInsertionId.value == messageId) _remoteInsertionId.value = null
                }

                if (payload.kind != ClipKind.FILE) {
                    WidgetState.save(ctx, WidgetState.PENDING, preview = text.take(40), lastText = text)
                    WidgetState.notifyWidgets(ctx)
                }

                Log.d(TAG, "Inbound clip from ${fromDeviceId.take(8)} len=${text.length}")
                PrivacyAnalytics.record(ctx, AnalyticsEvent.FIRST_TRANSFER)
            } catch (e: Exception) {
                PrivacyAnalytics.record(ctx, AnalyticsEvent.TRANSFER_FAILURE)
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
                    file = payload.file,
                )
                val updated = ClipHistoryStore.merge(ctx, listOf(record))
                _clipHistory.value = updated
                Log.d(TAG, "History clip merged from ${fromDeviceId.take(8)}")
            } catch (e: Exception) {
                Log.w(TAG, "processHistoryClip error: ${e.message}")
            }
        }
    }

    private fun processHistoryDelete(messageId: String, fromDeviceId: String, timestampMs: Long) {
        val ctx = appContext ?: return
        scope.launch {
            HistoryMutationStore.recordDelete(ctx, messageId, fromDeviceId, timestampMs)
            val matching = ClipHistoryStore.load(ctx).filter {
                it.messageId == messageId ||
                    (timestampMs > 0L && it.fromDeviceId == fromDeviceId &&
                        kotlin.math.abs(it.timestampMs.toDouble() - timestampMs.toDouble()) <=
                            ClipHistoryStore.RECONCILIATION_WINDOW_MS.toDouble())
            }
            var updated = ClipHistoryStore.load(ctx)
            matching.forEach { updated = ClipHistoryStore.remove(ctx, it.messageId) }
            _clipHistory.value = updated
        }
    }

    private fun processHistoryClear(throughMs: Long) {
        val ctx = appContext ?: return
        scope.launch {
            HistoryMutationStore.recordClear(ctx, throughMs)
            _clipHistory.value = ClipHistoryStore.clearThrough(ctx, throughMs)
        }
    }

    private fun pushHistoryToPeer(peer: com.airclip.airclip.lan.Peer) {
        val ctx = appContext ?: return
        scope.launch {
            try {
                val items = ClipHistoryStore.backfill(ClipHistoryStore.load(ctx))
                for (record in items) {
                    val transferableRecord = ImageClipboard.withInlineData(ctx, record)
                    val plain = ClipboardWirePayload.encode(transferableRecord).toByteArray(Charsets.UTF_8)
                    val enc = SealedBox.encryptForRecipient(plain, peer.publicKey)
                    val json = PeerManager.gson.toJson(
                        mapOf(
                            "type" to if (record.kind == ClipKind.FILE.name) "history_file_clip" else "history_clip",
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

    private fun pushHistoryMutationsToPeer(peer: com.airclip.airclip.lan.Peer) {
        val ctx = appContext ?: return
        val clearThrough = HistoryMutationStore.clearThroughMs(ctx)
        if (clearThrough > 0L) {
            peer.send(PeerManager.gson.toJson(mapOf("type" to "history_clear", "through_ms" to clearThrough.toString())))
        }
        HistoryMutationStore.deletedMessageIds(ctx).forEach { messageId ->
            peer.send(PeerManager.gson.toJson(mapOf("type" to "history_delete", "msg_id" to messageId)))
        }
        HistoryMutationStore.deletedSourceTimes(ctx).forEach { marker ->
            val split = marker.lastIndexOf('|')
            if (split > 0) peer.send(PeerManager.gson.toJson(mapOf(
                "type" to "history_delete",
                "msg_id" to "legacy",
                "from_device_id" to marker.substring(0, split),
                "ts" to marker.substring(split + 1),
            )))
        }
    }

    private fun pushLocalActivityToPeer(peer: com.airclip.airclip.lan.Peer) {
        val timestampMs = localActivityMs.takeIf { it > 0L } ?: return
        runCatching {
            peer.send(
                PeerManager.gson.toJson(
                    mapOf(
                        "type" to "app_activity",
                        "ts" to timestampMs.toString(),
                    )
                )
            )
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

    fun deleteHistoryItem(context: Context, record: ClipItemRecord) {
        scope.launch {
            HistoryMutationStore.recordDelete(context, record.messageId, record.fromDeviceId, record.timestampMs)
            _clipHistory.value = ClipHistoryStore.remove(context, record.messageId)
            PeerManager.broadcastHistoryDelete(record.messageId, record.fromDeviceId, record.timestampMs)
        }
    }

    fun clearHistory(context: Context) {
        val throughMs = System.currentTimeMillis()
        HistoryMutationStore.recordClear(context, throughMs)
        scope.launch {
            _clipHistory.value = ClipHistoryStore.clearThrough(context, throughMs)
            PeerManager.broadcastHistoryClear(throughMs)
        }
    }

    suspend fun clearLocalSession(context: Context) {
        ClipHistoryStore.clear(context)
        HistoryMutationStore.reset(context)
        recentHashes.clear()
        _clipHistory.value = emptyList()
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

    @Synchronized fun clear() {
        hashes.clear()
    }
}
