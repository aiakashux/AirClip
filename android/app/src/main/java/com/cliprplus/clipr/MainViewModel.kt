package com.cliprplus.clipr

import android.app.Application
import android.content.ClipboardManager
import android.content.Context
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.cliprplus.clipr.auth.AuthApi
import com.cliprplus.clipr.auth.TokenStore
import com.cliprplus.clipr.clipboard.ClipboardMonitor
import com.cliprplus.clipr.ClipHistoryStore
import com.cliprplus.clipr.ClipItemRecord
import com.cliprplus.clipr.crypto.KeyManager
import com.cliprplus.clipr.crypto.SealedBox
import com.cliprplus.clipr.device.AuthState
import com.cliprplus.clipr.device.ClipsApi
import com.cliprplus.clipr.device.DeviceApi
import com.cliprplus.clipr.device.DeviceApprovalState
import com.cliprplus.clipr.device.TokenState
import com.cliprplus.clipr.device.WsState
import com.cliprplus.clipr.util.Hash
import com.cliprplus.clipr.util.RecentHashCache
import com.cliprplus.clipr.util.RedactingLogger
import com.cliprplus.clipr.ws.CliprWebSocket
import com.cliprplus.clipr.ws.CliprWsListener
import com.cliprplus.clipr.ws.ClipboardPayload
import com.cliprplus.clipr.ws.DeliveredMessage
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import okhttp3.OkHttpClient
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.TimeUnit

class MainViewModel(app: Application) : AndroidViewModel(app) {

    // Step 1: initialise Prefs before _uiState reads from it.
    init { Prefs.init(app) }

    // _uiState is declared here — AFTER Prefs.init() so serverUrl/email are readable,
    // and BEFORE the restore coroutine is launched so the IO thread can never observe
    // a null _uiState (JVM zero-initialises fields; the coroutine must see the real value).
    private val _uiState = MutableStateFlow(UiState(baseUrl = Prefs.serverUrl, email = Prefs.email))
    val uiState: StateFlow<UiState> = _uiState

    // Step 2: _uiState is now non-null; safe to launch coroutines that write to it.
    init {
        viewModelScope.launch(Dispatchers.IO) {
            val savedApproval = TokenStore.loadFromDisk(app)
            // Load persisted keypair so tryDecryptPreview works on first cold-start reconnect.
            keyManager.loadFromDisk()
            val hasAccount    = TokenStore.accountToken != null
            val hasDevice     = TokenStore.deviceToken  != null
            val approvalState = when (savedApproval) {
                "Approved"        -> DeviceApprovalState.Approved
                "PendingApproval" -> DeviceApprovalState.PendingApproval
                "Revoked"         -> DeviceApprovalState.Revoked
                else              -> DeviceApprovalState.NotRegistered
            }
            // Load persisted clipboard history so the list is visible immediately,
            // before WS connects and catch-up runs.
            val history = ClipHistoryStore.load(app)
            _uiState.update {
                it.copy(
                    authState           = if (hasAccount) AuthState.AccountTokenReady else AuthState.LoggedOut,
                    tokenState          = if (hasDevice)  TokenState.DeviceTokenReady  else TokenState.NoDeviceToken,
                    deviceApprovalState = approvalState,
                    clipHistory         = history
                )
            }
            log(
                "[RESTORE] account=${if (hasAccount) "YES" else "NO"} " +
                "device=${if (hasDevice) "YES" else "NO"} " +
                "approval=$approvalState " +
                "lastSeenSeq=${TokenStore.lastSeenSeq} " +
                "historySize=${history.size}"
            )
            if (hasDevice && approvalState == DeviceApprovalState.Approved) {
                maybeAutoConnect()
            }
        }
    }

    // Shared HTTP client — reused across all REST API calls.
    private val httpClient = OkHttpClient.Builder()
        .connectTimeout(10, TimeUnit.SECONDS)
        .readTimeout(15, TimeUnit.SECONDS)
        .build()

    // API clients are created on-demand using the current baseUrl so that
    // a URL change in the debug field takes effect on the next call.
    private fun authApi()   = AuthApi(_uiState.value.baseUrl, httpClient)
    private fun deviceApi() = DeviceApi(_uiState.value.baseUrl, httpClient)
    private fun clipsApi()  = ClipsApi(_uiState.value.baseUrl, httpClient)

    // Derive WS URL from the current HTTP base URL.
    private val wsUrl get() = _uiState.value.baseUrl
        .replace("http://", "ws://")
        .replace("https://", "wss://") + "/ws"

    private val keyManager      = KeyManager(app)
    private val recentHashCache = RecentHashCache()

    private var wsClient: CliprWebSocket? = null
    /** Incremented on every new WsClient creation — used to invalidate stale listeners. */
    private var wsGeneration = 0

    // ------------------------------------------------------------------
    // Serial WS event processor (Item 9: catch-up vs live-delivery race fix)
    // ------------------------------------------------------------------

    /** Sealed event types for the serial WS event queue. */
    private sealed class WsEvent {
        data class Delivery(val msg: DeliveredMessage) : WsEvent()
        data class Hello(val latestSeq: Long) : WsEvent()
    }

    /**
     * Unbounded channel for WS events. All deliver_clipboard and hello messages
     * are enqueued here and consumed by a single serial coroutine, eliminating
     * the race between catch-up REST fetches and live WS deliveries.
     *
     * Natural ordering: pending deliveries → hello → (catch-up runs inline) → live deliveries queue.
     */
    private val wsEventChannel = Channel<WsEvent>(Channel.UNLIMITED)
    private var wsEventProcessorJob: Job? = null

    /**
     * Message-IDs seen in this WS session (pending + live + catch-up).
     * Prevents duplicate display when a pending WS delivery and the REST catch-up
     * both carry the same clip. ConcurrentHashMap-backed for safe cross-thread access.
     */
    private val seenMessageIds: MutableSet<String> = ConcurrentHashMap.newKeySet()

    /**
     * Snapshot of [TokenStore.lastSeenSeq] taken at the moment the WS connection opens,
     * BEFORE the server sends any pending deliveries or hello.
     *
     * The server protocol sends pending deliver_clipboard frames first, then hello(latest_seq).
     * If any pending delivery is processed before hello, [TokenStore.lastSeenSeq] advances.
     * Using the advanced value as the catch-up cursor would make [handleHello] conclude
     * "already caught up" and skip [fetchMissedClips], silently dropping older offline items.
     *
     * This field pins the catch-up baseline to the seq we knew about at connect time so
     * pending deliveries can never inflate it.  Reset to -1L after hello is handled (or on
     * session teardown).  @Volatile: written on the OkHttp network thread (onConnected),
     * read on the serial WS event processor coroutine (handleHello).
     */
    @Volatile private var reconnectBaselineSeq: Long = -1L

    private var approvalPollJob:  Job? = null
    private var clipboardMonitorJob: Job? = null

    /** Epoch-ms of the last successful clipboard send (for rate limiting). */
    @Volatile private var lastClipSentAtMs = 0L

    companion object {
        /** Minimum ms between successive clipboard sends. */
        private const val RATE_LIMIT_MS = 500L
    }

    // ------------------------------------------------------------------
    // UI state
    // ------------------------------------------------------------------

    data class ReceivedMessageUi(
        val messageId: String,
        val fromDeviceId: String,
        val ciphertextHash: String,  // hash only — never plaintext in logs
        val timestamp: String,
        val direction: String = "IN",
        /**
         * First 40 chars of decrypted plaintext — for UI display only.
         * MUST NOT be passed to log() or RedactingLogger.
         */
        val preview: String? = null
    )

    data class LocalClipItemUi(
        /** First 12 hex chars of SHA-256 — safe to display and log. */
        val hashPrefix: String,
        val length: Int,
        /**
         * First 40 chars of plaintext clipboard content.
         * DISPLAY ONLY — rendered in SentClipItemCard UI.
         * MUST NOT be passed to log(), RedactingLogger, or statusLog.
         */
        val preview: String,
        val timestamp: String,
        val timestampMs: Long
    )

    data class UiState(
        val email: String = "",
        val password: String = "",
        /** Editable server base URL. Default = emulator loopback. Physical device: set to LAN IP. */
        val baseUrl: String = "http://10.0.2.2:8000",
        val statusLog: List<String> = emptyList(),
        val receivedMessages: List<ReceivedMessageUi> = emptyList(),
        // --- explicit state machine ---
        val authState: AuthState = AuthState.LoggedOut,
        val deviceApprovalState: DeviceApprovalState = DeviceApprovalState.NotRegistered,
        val tokenState: TokenState = TokenState.NoDeviceToken,
        val wsState: WsState = WsState.Disconnected,
        val lastError: String? = null,
        /** Seconds until next background approval poll attempt; null when not polling. */
        val approvalPollWaitSeconds: Int? = null,
        /** Timestamp of the last manual device refresh, or null if never refreshed. */
        val lastRefreshTime: String? = null,
        /** Error from the last manual device refresh, or null if succeeded. */
        val lastRefreshError: String? = null,
        val isClipboardMonitorActive: Boolean = false,
        /** Up to 10 most recently sent clipboard items (local history). */
        val localClipItems: List<LocalClipItemUi> = emptyList(),
        /**
         * Received clipboard history — persisted across process kills.
         * Sorted newest-first; capped to [ClipHistoryStore.MAX_ITEMS].
         */
        val clipHistory: List<ClipItemRecord> = emptyList()
    )

    // ------------------------------------------------------------------
    // UI event handlers
    // ------------------------------------------------------------------

    fun onEmailChange(v: String) {
        Prefs.email = v
        _uiState.update { it.copy(email = v) }
    }
    fun onPasswordChange(v: String) = _uiState.update { it.copy(password = v) }
    fun onBaseUrlChange(v: String) {
        Prefs.serverUrl = v
        _uiState.update { it.copy(baseUrl = v) }
    }

    fun onRegister() = runAsync("register") {
        resetDeviceSessionState()
        val s   = _uiState.value
        val app = getApplication<Application>()
        val resp = authApi().register(s.email, s.password)
        TokenStore.saveAccount(app, resp.account_id, resp.token)
        log("Registered — account_id=${resp.account_id}")
        _uiState.update { it.copy(authState = AuthState.AccountTokenReady, lastError = null) }
    }

    fun onLogin() = runAsync("login") {
        resetDeviceSessionState()
        val s   = _uiState.value
        val app = getApplication<Application>()
        val resp = authApi().login(s.email, s.password)
        TokenStore.saveAccount(app, resp.account_id, resp.token)
        log("Logged in — account_id=${resp.account_id}")
        _uiState.update { it.copy(authState = AuthState.AccountTokenReady, lastError = null) }
    }

    fun onRegisterDevice() = runAsync("registerDevice") {
        val accountToken = TokenStore.accountToken ?: error("No account token — log in first")
        if (!keyManager.isInitialized) {
            keyManager.generateKeypair()
            log("Keypair generated pubkey_hash=${Hash.sha256Short(keyManager.getPublicKeyBase64())}")
        }
        val resp = deviceApi().registerDevice(
            accountToken    = accountToken,
            deviceName      = "Android-Debug",
            platform        = "android",
            publicKeyBase64 = keyManager.getPublicKeyBase64()
        )
        val app = getApplication<Application>()
        TokenStore.saveDevice(app, resp.device_id, resp.token)
        log("Device registered id=${resp.device_id} trust=${resp.trust_status}")

        val approvalState = when (resp.trust_status) {
            "trusted" -> DeviceApprovalState.Approved
            "pending" -> DeviceApprovalState.PendingApproval
            else      -> DeviceApprovalState.Revoked
        }
        TokenStore.saveApprovalState(app, approvalState::class.simpleName!!)
        _uiState.update {
            it.copy(
                tokenState          = TokenState.DeviceTokenReady,
                deviceApprovalState = approvalState,
                lastError           = null
            )
        }
        when (approvalState) {
            DeviceApprovalState.PendingApproval -> startApprovalPolling()
            DeviceApprovalState.Approved        -> maybeAutoConnect()
            else                                -> Unit
        }
    }

    /**
     * Manual refresh: call GET /devices, find this device, update approval state.
     * Shows last refresh time and any error separately from the general error field.
     */
    fun onRefreshDevices() {
        viewModelScope.launch(Dispatchers.IO) {
            val accountToken = TokenStore.accountToken ?: run {
                _uiState.update { it.copy(lastRefreshTime = ts(), lastRefreshError = "No account token") }
                return@launch
            }
            val myDeviceId = TokenStore.deviceId ?: run {
                _uiState.update { it.copy(lastRefreshTime = ts(), lastRefreshError = "No device registered") }
                return@launch
            }
            try {
                val devices   = deviceApi().listDevices(accountToken)
                val myDevice  = devices.find { it.device_id == myDeviceId }
                val newStatus = myDevice?.trust_status
                if (newStatus == null) {
                    _uiState.update { it.copy(lastRefreshTime = ts(), lastRefreshError = "Device not found") }
                    log("Refresh: own device not found in list")
                    return@launch
                }
                val approvalState = when (newStatus) {
                    "trusted" -> DeviceApprovalState.Approved
                    "pending" -> DeviceApprovalState.PendingApproval
                    else      -> DeviceApprovalState.Revoked
                }
                TokenStore.saveApprovalState(getApplication(), approvalState::class.simpleName!!)
                _uiState.update {
                    it.copy(
                        deviceApprovalState = approvalState,
                        lastRefreshTime     = ts(),
                        lastRefreshError    = null
                    )
                }
                log("Refresh: trust=$newStatus")
                if (approvalState == DeviceApprovalState.Approved) {
                    maybeAutoConnect()
                }
            } catch (e: Exception) {
                RedactingLogger.error("refreshDevices", e)
                _uiState.update { it.copy(lastRefreshTime = ts(), lastRefreshError = "Refresh failed") }
                log("Refresh failed")
            }
        }
    }

    /**
     * Connect WS only if device is Approved and token is valid (docs/protocol.md §4, §5).
     * Any other state blocks the connection and surfaces a safe error message.
     */
    fun onConnectWs() {
        val st = _uiState.value
        if (st.deviceApprovalState != DeviceApprovalState.Approved) {
            val reason = when (st.deviceApprovalState) {
                DeviceApprovalState.PendingApproval -> "device not yet approved"
                DeviceApprovalState.Revoked         -> "device access revoked"
                DeviceApprovalState.NotRegistered   -> "device not registered"
                else                                -> "device not approved"
            }
            _uiState.update { it.copy(lastError = "Cannot connect WS: $reason") }
            log("WS connect blocked: $reason")
            return
        }
        if (st.tokenState != TokenState.DeviceTokenReady) {
            _uiState.update { it.copy(lastError = "Cannot connect WS: no valid device token") }
            log("WS connect blocked: token not ready")
            return
        }
        val deviceToken = TokenStore.deviceToken ?: run {
            _uiState.update { it.copy(tokenState = TokenState.NoDeviceToken, lastError = "Device token missing from store") }
            return
        }
        wsClient?.disconnect()
        val gen = ++wsGeneration
        _uiState.update { it.copy(wsState = WsState.Connecting, lastError = null) }
        wsClient = CliprWebSocket(
            wsBaseUrl   = wsUrl,
            deviceToken = deviceToken,
            listener    = makeWsListener(gen)
        )
        wsClient!!.connect()
        log("WS connecting…")
    }

    /**
     * Fetch trusted peer devices via REST, encrypt a test payload for each,
     * and send via WebSocket. Falls back to a self-loopback if no remote peers exist.
     *
     * No clipboard access — plaintext is a timestamped test string only.
     */
    fun onSendTestMessage() = runAsync("sendTestMessage") {
        val ws           = wsClient?.takeIf { it.isConnected() } ?: error("WS not connected")
        val accountToken = TokenStore.accountToken ?: error("No account token")
        val myDeviceId   = TokenStore.deviceId     ?: error("No device id")

        val devices    = deviceApi().listDevices(accountToken)
        val recipients = devices.filter { it.trust_status == "trusted" && it.device_id != myDeviceId }

        // Test plaintext — a timestamped probe, not clipboard content
        val testPlain = "clipr-test-${System.currentTimeMillis()}".toByteArray(Charsets.UTF_8)

        if (recipients.isEmpty()) {
            // Loopback: encrypt for self so we can verify the full round-trip
            val self = devices.find { it.device_id == myDeviceId }
                ?: error("Own device not found in device list")
            val enc = SealedBox.encryptForRecipient(testPlain, self.public_key)
            ws.sendClipboard(listOf(ClipboardPayload(myDeviceId, enc.ciphertextBase64, enc.nonce)))
            log("No remote peers — sent loopback test hash=${Hash.sha256Short(testPlain)}")
            return@runAsync
        }

        val payloads = recipients.map { device ->
            val enc = SealedBox.encryptForRecipient(testPlain, device.public_key)
            ClipboardPayload(device.device_id, enc.ciphertextBase64, enc.nonce)
        }
        ws.sendClipboard(payloads)
        log("Sent test to ${payloads.size} peer(s) hash=${Hash.sha256Short(testPlain)}")
    }

    /**
     * Called when the app returns to the foreground (ON_START lifecycle event)
     * and also from the "Sync Clipboard Now" debug button.
     *
     * Reads the current system clipboard on the calling thread (must be Main),
     * then dispatches encryption + send to IO.
     *
     * No-ops when WS is not connected or device is not approved.
     * DO NOT log plaintext — only hash prefix and length.
     */
    fun onAppForegrounded() {
        val st = _uiState.value
        if (st.wsState != WsState.Connected || st.deviceApprovalState != DeviceApprovalState.Approved) {
            log("[SYNC-BTN] onAppForegrounded skipped — wsState=${st.wsState} approval=${st.deviceApprovalState}")
            return
        }
        log("[SYNC-BTN] onAppForegrounded — reading clipboard")

        val cm = getApplication<Application>().getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        val text = try {
            cm.primaryClip
                ?.takeIf { it.itemCount > 0 }
                ?.getItemAt(0)
                ?.coerceToText(getApplication())
                ?.toString()
                ?.trim()
                ?.takeIf { it.isNotEmpty() }
        } catch (_: Exception) { null }

        if (text == null) {
            RedactingLogger.info("Foreground: clipboard empty or non-text — nothing to send")
            return
        }

        log("Foreground: read hash=${Hash.sha256Hex(text).take(12)} len=${text.length}")

        // sendClipboardText handles dedupe and exception logging internally.
        // text is captured in the closure but never passed to any log inside the launch.
        viewModelScope.launch(Dispatchers.IO) {
            sendClipboardText(text)  // try/catch inside — no plaintext can escape to logcat
        }
    }

    // ------------------------------------------------------------------
    // WebSocket listener factory
    // ------------------------------------------------------------------

    /**
     * Create a per-connection listener tagged with [gen].
     *
     * [onDisconnected] guards on [wsGeneration] == [gen] to prevent a stale
     * listener from a replaced client stopping the new connection's clipboard monitor.
     */
    private fun makeWsListener(gen: Int): CliprWsListener = object : CliprWsListener {
        override fun onConnected() {
            _uiState.update { it.copy(wsState = WsState.Connected, lastError = null) }
            log("[WS] onConnected")
            // Snapshot lastSeenSeq NOW, before the server sends any pending deliveries.
            // handleHello uses this baseline so a pending delivery processed before hello
            // cannot inflate the cursor and cause missed offline items to be skipped.
            reconnectBaselineSeq = TokenStore.lastSeenSeq
            RedactingLogger.info("[BASELINE] captured seq=$reconnectBaselineSeq at connect")
            log("[BASELINE] captured seq=$reconnectBaselineSeq")
            // Drain stale events from a previous connection before starting the processor.
            while (wsEventChannel.tryReceive().isSuccess) { /* discard */ }
            startWsEventProcessor()
            startClipboardMonitor()
        }

        override fun onDisconnected(code: Int, reason: String) {
            if (wsGeneration != gen) return  // stale listener — new connection already active
            wsEventProcessorJob?.cancel()
            wsEventProcessorJob = null
            _uiState.update { it.copy(wsState = WsState.Disconnected) }
            stopClipboardMonitor()
            log("[WS] onDisconnected code=$code reason=${reason.take(80)}")
        }

        /**
         * Server rejected the WS upgrade (401/403) — device token is invalid.
         * Block reconnect until the user re-registers the device.
         */
        override fun onAuthFailed() {
            wsClient?.disconnect()
            wsEventProcessorJob?.cancel()
            wsEventProcessorJob = null
            stopClipboardMonitor()
            _uiState.update {
                it.copy(
                    wsState             = WsState.Disconnected,
                    tokenState          = TokenState.DeviceTokenInvalid,
                    deviceApprovalState = DeviceApprovalState.Revoked,
                    lastError           = "WS auth rejected — re-register device"
                )
            }
            log("[WS] onAuthFailed — device token invalid; re-register device to recover")
        }

        /** Enqueue for serial processing — no concurrent coroutine spawned here. */
        override fun onDeliverClipboard(msg: DeliveredMessage) {
            wsEventChannel.trySend(WsEvent.Delivery(msg))
        }

        /** Enqueue for serial processing — catch-up runs inline inside the processor. */
        override fun onHello(latestSeq: Long) {
            wsEventChannel.trySend(WsEvent.Hello(latestSeq))
        }

        override fun onLog(text: String) = log(text)
    }

    // ------------------------------------------------------------------
    // Serial WS event processor helpers
    // ------------------------------------------------------------------

    /**
     * Start a single serial coroutine that processes WS events in order.
     * Natural ordering: pending deliveries → hello → catch-up (inline HTTP) → live deliveries queue.
     * Cancels any previous processor before starting.
     */
    private fun startWsEventProcessor() {
        wsEventProcessorJob?.cancel()
        wsEventProcessorJob = viewModelScope.launch(Dispatchers.IO) {
            for (event in wsEventChannel) {
                when (event) {
                    is WsEvent.Delivery -> handleDelivery(event.msg)
                    is WsEvent.Hello    -> handleHello(event.latestSeq)
                }
            }
        }
    }

    /**
     * Process a single deliver_clipboard event.
     *
     * [seenMessageIds] is populated ONLY on decrypt success — failed decrypts are NOT
     * added, so the same message can be retried on reconnect.  This also ensures the
     * catch-up duplicate branch in [fetchMissedClips] advances seq only for items that
     * were provably accepted, fixing the lastSeenSeq over-advance bug.
     *
     * Plaintext goes only to UI — never to log() or RedactingLogger.
     */
    private suspend fun handleDelivery(msg: DeliveredMessage) {
        val ciphertextHash = Hash.sha256Short(msg.ciphertext)
        val preview = tryDecryptPreview(msg.ciphertext, msg.nonce)
        val ui = ReceivedMessageUi(
            messageId      = msg.messageId,
            fromDeviceId   = msg.fromDeviceId,
            ciphertextHash = ciphertextHash,
            timestamp      = ts(),
            preview        = preview
        )
        _uiState.update {
            it.copy(receivedMessages = (it.receivedMessages + ui).takeLast(50))
        }
        log("← msg from ${msg.fromDeviceId.take(8)}… hash=$ciphertextHash")
        if (preview != null) {
            // Dedup gated on decrypt success: only successfully-accepted IDs enter seenMessageIds.
            // A duplicate here means a prior delivery already ACKed it — skip silently.
            if (!seenMessageIds.add(msg.messageId)) {
                log("Dup msg=${msg.messageId.take(8)} already accepted — skipped")
                return
            }
            // ACK only after successful decrypt — server deletes the pending message
            wsClient?.sendAck(msg.messageId)
            // HIGH 2: only advance seq when decrypt succeeded; HIGH 3: monotonic
            if (msg.seq > 0L) {
                TokenStore.saveLastSeenSeq(getApplication(), msg.seq)
            }
            // Persist to local history so the item survives process kills.
            val record = ClipItemRecord(
                messageId    = msg.messageId,
                seq          = msg.seq,
                fromDeviceId = msg.fromDeviceId,
                timestampMs  = System.currentTimeMillis(),
                cipherHash   = ciphertextHash,
                preview      = preview
            )
            val updated = ClipHistoryStore.merge(getApplication(), listOf(record))
            _uiState.update { it.copy(clipHistory = updated) }
        }
        // Decrypt failed: no ACK, no seq advance, NOT added to seenMessageIds → retryable on reconnect
    }

    /**
     * Process a hello event: paginated catch-up if server has clips we haven't seen (MED 7).
     * Runs inline in the serial processor, so live deliveries queue behind it naturally.
     *
     * Uses [reconnectBaselineSeq] — the seq captured at connect time — rather than the
     * current [TokenStore.lastSeenSeq].  The server sends pending deliver_clipboard frames
     * before hello; those deliveries advance [TokenStore.lastSeenSeq].  Without the baseline,
     * if the last pending delivery has seq == latestSeq the comparison would incorrectly
     * conclude "already caught up" and skip [fetchMissedClips] entirely, dropping every
     * offline item except the one that happened to survive in the pending queue.
     */
    private suspend fun handleHello(latestSeq: Long) {
        // Consume the baseline exactly once per reconnect, then clear it.
        val baseline = reconnectBaselineSeq.also { reconnectBaselineSeq = -1L }
        val current  = TokenStore.lastSeenSeq
        // Defensive fallback: if baseline was never set (-1) use the current watermark.
        val afterSeq = if (baseline >= 0L) baseline else current
        val decision = if (latestSeq > afterSeq) "fetch" else "skip"
        log("[BASELINE] cleared (consumed by handleHello) was=$baseline")
        RedactingLogger.info(
            "[WS] hello: latestSeq=$latestSeq baseline=$baseline currentLastSeen=$current decision=$decision"
        )
        log("[WS] hello: latestSeq=$latestSeq baseline=$baseline currentLastSeen=$current decision=$decision")
        if (latestSeq <= afterSeq) return
        fetchMissedClips(afterSeq, latestSeq)
    }

    /**
     * Paginated catch-up: fetch clips with seq > [afterSeq] up to [latestSeq].
     * MED 7: loops in pages of 20 until caught up or server returns empty.
     * HIGH 3: final write uses TokenStore.saveLastSeenSeq which is monotonic.
     *
     * maxAdvancedSeq advances in exactly three permitted branches:
     *   1. decrypt success + accept (preview != null)
     *   2. duplicate of a message already accepted in this session (seenMessageIds.contains)
     *   3. self-sent message (from_device_id == myDeviceId) — accepted locally at send time
     * In all other cases (decrypt failure) seq does NOT advance and the ID is NOT marked seen,
     * keeping the message retryable on the next catch-up pass.
     */
    private suspend fun fetchMissedClips(afterSeq: Long, latestSeq: Long) {
        RedactingLogger.info("[CATCH-UP] START afterSeq=$afterSeq latestSeq=$latestSeq gap=${latestSeq - afterSeq}")
        log("[CATCH-UP] START afterSeq=$afterSeq latestSeq=$latestSeq gap=${latestSeq - afterSeq}")
        val deviceToken = TokenStore.deviceToken ?: return
        val myDeviceId  = TokenStore.deviceId    ?: return
        try {
            val api = clipsApi()
            var currentAfterSeq = afterSeq
            // HIGH 2: only advance for clips that decrypted (or are self-sent)
            var maxAdvancedSeq = afterSeq
            // Collect new records for bulk persistence after the loop.
            val newRecords = mutableListOf<ClipItemRecord>()
            var pageIdx = 0

            while (currentAfterSeq < latestSeq) {
                val clips = api.fetchHistory(deviceToken, currentAfterSeq)
                log("[CATCH-UP] page=$pageIdx afterSeq=$currentAfterSeq count=${clips.size}")
                if (clips.isEmpty()) break

                var pageOk = 0; var pageFail = 0; var pageDup = 0; var pageSelf = 0

                for (clip in clips) {
                    // Branch 2: duplicate of an already-accepted message.
                    // seenMessageIds holds only decrypt-success + ACK'd IDs, so advance is safe.
                    if (seenMessageIds.contains(clip.message_id)) {
                        maxAdvancedSeq = maxOf(maxAdvancedSeq, clip.seq)
                        pageDup++; continue
                    }
                    // Branch 3: self-sent clip.
                    // Plaintext was accepted locally when the user copied it to clipboard.
                    // Advance seq so the watermark moves forward; skip decrypt and UI insert.
                    if (clip.from_device_id == myDeviceId) {
                        maxAdvancedSeq = maxOf(maxAdvancedSeq, clip.seq)
                        pageSelf++; continue
                    }
                    // Branch 1: decrypt attempt for a new inbound clip.
                    val clipHash = Hash.sha256Short(clip.ciphertext)
                    val preview  = tryDecryptPreview(clip.ciphertext, clip.nonce)
                    if (preview != null) {
                        // Mark accepted only on decrypt success — failed decrypts remain absent
                        // from seenMessageIds so the item is retryable on the next catch-up pass.
                        seenMessageIds.add(clip.message_id)
                        maxAdvancedSeq = maxOf(maxAdvancedSeq, clip.seq)
                        pageOk++
                        val ui = ReceivedMessageUi(
                            messageId      = clip.message_id,
                            fromDeviceId   = clip.from_device_id,
                            ciphertextHash = clipHash,
                            timestamp      = ts(),
                            direction      = "IN (catch-up)",
                            preview        = preview
                        )
                        _uiState.update {
                            it.copy(receivedMessages = (it.receivedMessages + ui).takeLast(50))
                        }
                        newRecords += ClipItemRecord(
                            messageId    = clip.message_id,
                            seq          = clip.seq,
                            fromDeviceId = clip.from_device_id,
                            timestampMs  = System.currentTimeMillis(),
                            cipherHash   = clipHash,
                            preview      = preview
                        )
                    } else {
                        pageFail++
                        // Decrypt failure: seq does NOT advance; ID not added to seenMessageIds → retryable.
                    }
                }

                log("[CATCH-UP] page=$pageIdx seqRange=${clips.first().seq}–${clips.last().seq} ok=$pageOk fail=$pageFail dup=$pageDup self=$pageSelf")
                pageIdx++
                currentAfterSeq = clips.last().seq
            }

            // Persist all successfully-decrypted catch-up items in one merge.
            if (newRecords.isNotEmpty()) {
                val updated = ClipHistoryStore.merge(getApplication(), newRecords)
                _uiState.update { it.copy(clipHistory = updated) }
            }

            // HIGH 3: saveLastSeenSeq is monotonic — concurrent live-delivery updates are safe
            if (maxAdvancedSeq > afterSeq) {
                TokenStore.saveLastSeenSeq(getApplication(), maxAdvancedSeq)
                log("Catch-up: last_seen_seq advanced to $maxAdvancedSeq")
            }
            RedactingLogger.info(
                "[CATCH-UP] END pages=$pageIdx fetched=${newRecords.size} maxAdvancedSeq=$maxAdvancedSeq historySize=${_uiState.value.clipHistory.size}"
            )
            log("[CATCH-UP] END pages=$pageIdx fetched=${newRecords.size} maxAdvancedSeq=$maxAdvancedSeq historySize=${_uiState.value.clipHistory.size}")
        } catch (e: Exception) {
            RedactingLogger.error("fetchMissedClips", e)
            log("Catch-up fetch failed: ${e.javaClass.simpleName}")
        }
    }

    /**
     * Decrypt [ciphertextBase64] using this device's keypair and return the first 40 chars
     * of the plaintext as a UI preview, or null if decryption fails or keypair is not ready.
     * The full plaintext is never stored or logged.
     */
    private fun tryDecryptPreview(ciphertextBase64: String, @Suppress("UNUSED_PARAMETER") nonce: String): String? {
        if (!keyManager.isInitialized) return null
        return try {
            val plain = SealedBox.decryptForSelf(
                ciphertextBase64,
                keyManager.getPublicKeyBytes(),
                keyManager.getPrivateKeyBytes()
            )
            String(plain, Charsets.UTF_8).take(40)
        } catch (_: Exception) {
            null
        }
    }

    // ------------------------------------------------------------------
    // Clipboard monitor
    // ------------------------------------------------------------------

    /**
     * Start watching the system clipboard. Runs a [Channel.CONFLATED] pipeline:
     *  - Collector coroutine on Main (required by ClipboardManager)
     *  - Rate-limited sender on IO (≥500ms between sends, coalesces during sleep)
     *
     * Safe to call multiple times — cancels any previous monitor first.
     * Called automatically from [makeWsListener]'s onConnected.
     */
    private fun startClipboardMonitor() {
        clipboardMonitorJob?.cancel()
        val app = getApplication<Application>()

        clipboardMonitorJob = viewModelScope.launch {
            // CONFLATED: only the latest clipboard value is kept between sends.
            val sendChannel = Channel<String>(Channel.CONFLATED)

            // Collector — must run on Main; ClipboardManager requires main-thread listener.
            launch(Dispatchers.Main) {
                ClipboardMonitor.clipboardFlow(app).collect { text ->
                    sendChannel.trySend(text)
                }
            }

            // Rate-limited sender — enforces ≥RATE_LIMIT_MS between successive network sends.
            launch(Dispatchers.IO) {
                for (text in sendChannel) {
                    val elapsed = System.currentTimeMillis() - lastClipSentAtMs
                    if (elapsed < RATE_LIMIT_MS) delay(RATE_LIMIT_MS - elapsed)
                    // Coalesce: prefer any newer value that arrived during the sleep.
                    val latest = sendChannel.tryReceive().getOrNull() ?: text
                    sendClipboardText(latest)
                }
            }
        }

        _uiState.update { it.copy(isClipboardMonitorActive = true) }
        log("Clipboard monitor started")
    }

    private fun stopClipboardMonitor() {
        clipboardMonitorJob?.cancel()
        clipboardMonitorJob = null
        _uiState.update { it.copy(isClipboardMonitorActive = false) }
        log("Clipboard monitor stopped")
    }

    /**
     * Encrypt [text] for all trusted peer devices and send via WebSocket.
     *
     * Skip if [recentHashCache] already knows this hash (loop prevention).
     * DO NOT log plaintext content at any point.
     */
    private suspend fun sendClipboardText(text: String) {
        // Compute hash first — used in both the happy path and the error path.
        // hash is the ONLY derivative of text that may appear in any log line.
        val hash = Hash.sha256Hex(text)
        try {
            if (recentHashCache.isKnown(hash)) {
                RedactingLogger.info("ClipMonitor: skip known hash=${hash.take(12)}")
                return
            }

            val ws           = wsClient?.takeIf { it.isConnected() } ?: return
            val accountToken = TokenStore.accountToken ?: return
            val myDeviceId   = TokenStore.deviceId     ?: return

            val devices    = deviceApi().listDevices(accountToken)
            val recipients = devices.filter { it.trust_status == "trusted" && it.device_id != myDeviceId }
            if (recipients.isEmpty()) {
                RedactingLogger.info("ClipMonitor: no trusted peers — skip hash=${hash.take(12)}")
                return
            }

            val plainBytes = text.toByteArray(Charsets.UTF_8)
            val payloads = recipients.map { device ->
                val enc = SealedBox.encryptForRecipient(plainBytes, device.public_key)
                ClipboardPayload(device.device_id, enc.ciphertextBase64, enc.nonce)
            }
            ws.sendClipboard(payloads)

            recentHashCache.record(hash)
            lastClipSentAtMs = System.currentTimeMillis()

            // preview is stored for UI display only — it is never passed to log() or RedactingLogger.
            val ui = LocalClipItemUi(
                hashPrefix  = hash.take(12),
                length      = text.length,
                preview     = text.take(40),  // UI display only — see LocalClipItemUi.preview doc
                timestamp   = ts(),
                timestampMs = System.currentTimeMillis()
            )
            _uiState.update {
                it.copy(localClipItems = (it.localClipItems + ui).takeLast(10))
            }

            // Insert a self-sent record into Clipboard History so Android shows its own
            // clips consistently with Mac. seq=0 because the server seq is not known at
            // send time; the catch-up self-sent branch (from_device_id == myDeviceId)
            // skips these on catch-up, so there is no duplication risk from the server.
            // preview goes to UI only — it is never passed to log() or RedactingLogger.
            val selfRecord = ClipItemRecord(
                messageId    = "local-${UUID.randomUUID()}",
                seq          = 0L,
                fromDeviceId = myDeviceId,
                timestampMs  = System.currentTimeMillis(),
                cipherHash   = hash.take(16),   // plaintext hash prefix — safe to log
                preview      = text.take(40)     // UI display only — never logged
            )
            val updatedHistory = ClipHistoryStore.merge(getApplication(), listOf(selfRecord))
            _uiState.update { it.copy(clipHistory = updatedHistory) }

            log("→ clip sent hash=${hash.take(12)} len=${text.length} peers=${payloads.size}")

        } catch (e: Exception) {
            // Log hash and length only — never 'text', 'plainBytes', or 'preview'.
            RedactingLogger.error("sendClipboardText: error hash=${hash.take(12)}", e)
            log("→ clip send failed hash=${hash.take(12)} (${e.javaClass.simpleName})")
        }
    }

    // ------------------------------------------------------------------
    // Auto-connect
    // ------------------------------------------------------------------

    /**
     * Connect WS automatically when the device becomes Approved and has a
     * valid token — called after registration, approval polling, and manual refresh.
     */
    private fun maybeAutoConnect() {
        val st = _uiState.value
        if (st.deviceApprovalState == DeviceApprovalState.Approved &&
            st.tokenState == TokenState.DeviceTokenReady &&
            st.wsState == WsState.Disconnected
        ) {
            log("[AUTO-CONNECT] connecting — approval=${st.deviceApprovalState} token=${st.tokenState} ws=${st.wsState}")
            onConnectWs()
        } else {
            log("[AUTO-CONNECT] skipped — approval=${st.deviceApprovalState} token=${st.tokenState} ws=${st.wsState}")
        }
    }

    // ------------------------------------------------------------------
    // Approval polling
    // ------------------------------------------------------------------

    /**
     * Poll GET /devices/ with exponential backoff until this device's trust_status
     * transitions from "pending" to "trusted" (docs/protocol.md §4, §2.2).
     *
     * Backoff schedule: 1s → 2s → 4s → 8s → 15s (capped).
     * Stops automatically when: Approved, Revoked, or ViewModel cleared.
     * A manual Refresh also transitions the state, which stops this loop on next iteration.
     */
    private fun startApprovalPolling() {
        approvalPollJob?.cancel()
        approvalPollJob = viewModelScope.launch(Dispatchers.IO) {
            var delayMs    = 1_000L
            val delayCapMs = 15_000L

            while (true) {
                val waitSec = (delayMs / 1000).toInt()
                _uiState.update { it.copy(approvalPollWaitSeconds = waitSec) }
                delay(delayMs)

                // Re-check state after delay — may have changed via manual Refresh
                if (_uiState.value.deviceApprovalState != DeviceApprovalState.PendingApproval) break

                val accountToken = TokenStore.accountToken ?: break
                val myDeviceId   = TokenStore.deviceId     ?: break

                try {
                    val devices  = deviceApi().listDevices(accountToken)
                    val myDevice = devices.find { it.device_id == myDeviceId }
                    when (myDevice?.trust_status) {
                        "trusted" -> {
                            _uiState.update {
                                it.copy(
                                    deviceApprovalState     = DeviceApprovalState.Approved,
                                    approvalPollWaitSeconds = null,
                                    lastError               = null
                                )
                            }
                            TokenStore.saveApprovalState(getApplication(), "Approved")
                            log("Device approved — auto-connecting WS")
                            maybeAutoConnect()
                            break
                        }
                        "pending" -> {
                            delayMs = minOf(delayMs * 2, delayCapMs)
                        }
                        null -> {
                            log("Own device not found in device list — stopping poll")
                            _uiState.update { it.copy(approvalPollWaitSeconds = null) }
                            break
                        }
                        else -> {
                            _uiState.update {
                                it.copy(
                                    deviceApprovalState     = DeviceApprovalState.Revoked,
                                    approvalPollWaitSeconds = null,
                                    lastError               = "Unexpected device status from server"
                                )
                            }
                            log("Approval polling: unrecognised trust_status — stopping")
                            break
                        }
                    }
                } catch (e: Exception) {
                    RedactingLogger.error("approvalPoll", e)
                    log("Approval poll failed — will retry")
                    delayMs = minOf(delayMs * 2, delayCapMs)
                }
            }

            _uiState.update { it.copy(approvalPollWaitSeconds = null) }
        }
    }

    // ------------------------------------------------------------------
    // Helpers
    // ------------------------------------------------------------------

    /**
     * Tear down all device-scoped session state before a new auth flow begins.
     * Prevents stale device_token/device_id from a previous account leaking into
     * the new session (docs/protocol.md §3.4 — strict token separation).
     */
    private fun resetDeviceSessionState() {
        wsClient?.disconnect()
        wsClient = null
        wsEventProcessorJob?.cancel()
        wsEventProcessorJob = null
        seenMessageIds.clear()
        reconnectBaselineSeq = -1L
        while (wsEventChannel.tryReceive().isSuccess) { /* discard stale events */ }
        approvalPollJob?.cancel()
        approvalPollJob = null
        stopClipboardMonitor()
        recentHashCache.clear()
        TokenStore.clearDeviceAuth()
        // Clear device creds, clip history, and keypair asynchronously (all touch I/O).
        viewModelScope.launch(Dispatchers.IO) {
            TokenStore.clearDeviceAuth(getApplication())
            ClipHistoryStore.clear(getApplication())
            keyManager.clearKeypair()
        }
        _uiState.update {
            it.copy(
                tokenState               = TokenState.NoDeviceToken,
                deviceApprovalState      = DeviceApprovalState.NotRegistered,
                wsState                  = WsState.Disconnected,
                approvalPollWaitSeconds  = null,
                lastError                = null,
                lastRefreshTime          = null,
                lastRefreshError         = null,
                isClipboardMonitorActive = false,
                localClipItems           = emptyList(),
                clipHistory              = emptyList()
            )
        }
        log("Device session reset")
    }

    /**
     * Manually fetch missed clipboard items from the server REST history endpoint.
     *
     * Does NOT require an active WS connection — only a valid device token.
     * Passes [Long.MAX_VALUE] as sentinelLatestSeq so [fetchMissedClips] self-terminates
     * when the server returns an empty page (no items beyond current watermark).
     *
     * Safe to call concurrently with an ongoing WS-driven catch-up; seenMessageIds dedup
     * and ClipHistoryStore.merge's distinctBy guard prevent double-inserts.
     *
     * This is the action wired to "Sync Now" in the UI.  Auto-catch-up on WS connect
     * (handleHello → fetchMissedClips) still runs automatically on reopen; this function
     * provides an explicit manual trigger when the user wants to pull without reconnecting.
     */
    fun onFetchHistory() = runAsync("fetchHistory") {
        val seq = TokenStore.lastSeenSeq
        if (TokenStore.deviceToken == null) {
            log("[SYNC-BTN] fetch skipped — no device token lastSeenSeq=$seq")
            return@runAsync
        }
        log("[SYNC-BTN] onFetchHistory — lastSeenSeq=$seq sentinel=MAX_VALUE")
        fetchMissedClips(seq, Long.MAX_VALUE)
    }

    /**
     * Called when the user taps a history item to copy it back to the Android clipboard.
     * Records the preview hash in [recentHashCache] so the clipboard monitor does not
     * immediately re-send what was just pasted.
     *
     * NOTE: [item.preview] is capped at 40 chars; the full original text is not stored.
     */
    fun onHistoryItemCopied(item: ClipItemRecord) {
        recentHashCache.record(Hash.sha256Hex(item.preview))
        log("History item copied to clipboard seq=${item.seq}")
    }

    /** Clear all session data and reset UI to the logged-out state. */
    fun onLogout() = runAsync("logout") {
        resetDeviceSessionState()
        val app = getApplication<Application>()
        TokenStore.clearAll(app)
        Prefs.clearAll()   // removes serverUrl + email; both revert to defaults on next read
        _uiState.update {
            it.copy(
                authState = AuthState.LoggedOut,
                baseUrl   = Prefs.serverUrl,   // returns DEFAULT_URL after clearAll
                email     = Prefs.email,        // returns "" after clearAll
                password  = ""
            )
        }
        log("Logged out — all session data cleared")
    }

    private fun log(msg: String) {
        RedactingLogger.info(msg)
        val line = "[${ts()}] $msg"
        _uiState.update {
            it.copy(statusLog = (it.statusLog + line).takeLast(50))
        }
    }

    private fun ts() = SimpleDateFormat("HH:mm:ss", Locale.US).format(Date())

    /** Run [block] on IO dispatcher; catch and surface any exception to the UI log. */
    private fun runAsync(label: String, block: suspend () -> Unit) {
        viewModelScope.launch(Dispatchers.IO) {
            try {
                block()
            } catch (e: Exception) {
                val msg = "[$label] ${e.message ?: e.javaClass.simpleName}"
                RedactingLogger.error(msg, e)
                log(msg)
            }
        }
    }

    override fun onCleared() {
        super.onCleared()
        wsClient?.disconnect()
        wsEventProcessorJob?.cancel()
        approvalPollJob?.cancel()
        clipboardMonitorJob?.cancel()
    }
}