package com.cliprplus.clipr

import android.app.Application
import android.content.ClipboardManager
import android.content.Context
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.cliprplus.clipr.auth.AuthApi
import com.cliprplus.clipr.auth.TokenStore
import com.cliprplus.clipr.clipboard.ClipboardMonitor
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
            val hasAccount    = TokenStore.accountToken != null
            val hasDevice     = TokenStore.deviceToken  != null
            val approvalState = when (savedApproval) {
                "Approved"        -> DeviceApprovalState.Approved
                "PendingApproval" -> DeviceApprovalState.PendingApproval
                "Revoked"         -> DeviceApprovalState.Revoked
                else              -> DeviceApprovalState.NotRegistered
            }
            _uiState.update {
                it.copy(
                    authState           = if (hasAccount) AuthState.AccountTokenReady else AuthState.LoggedOut,
                    tokenState          = if (hasDevice)  TokenState.DeviceTokenReady  else TokenState.NoDeviceToken,
                    deviceApprovalState = approvalState
                )
            }
            if (hasAccount) log("Session restored — account_id=${TokenStore.accountId?.take(8)}…")
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

    private val keyManager      = KeyManager()
    private val recentHashCache = RecentHashCache()

    private var wsClient: CliprWebSocket? = null
    /** Incremented on every new WsClient creation — used to invalidate stale listeners. */
    private var wsGeneration = 0

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
        val localClipItems: List<LocalClipItemUi> = emptyList()
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
        if (st.wsState != WsState.Connected || st.deviceApprovalState != DeviceApprovalState.Approved) return

        log("Foreground: clipboard check…")

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
            log("WS connected")
            startClipboardMonitor()
        }

        override fun onDisconnected(code: Int, reason: String) {
            if (wsGeneration != gen) return  // stale listener — new connection already active
            _uiState.update { it.copy(wsState = WsState.Disconnected) }
            stopClipboardMonitor()
            log("WS disconnected $code")
        }

        /**
         * Server rejected the WS upgrade (401/403) — device token is invalid.
         * Block reconnect until the user re-registers the device.
         */
        override fun onAuthFailed() {
            wsClient?.disconnect()
            stopClipboardMonitor()
            _uiState.update {
                it.copy(
                    wsState             = WsState.Disconnected,
                    tokenState          = TokenState.DeviceTokenInvalid,
                    deviceApprovalState = DeviceApprovalState.Revoked,
                    lastError           = "WS auth rejected — re-register device"
                )
            }
            log("WS auth failed — device token invalid; re-register device to recover")
        }

        override fun onDeliverClipboard(msg: DeliveredMessage) {
            val ciphertextHash = Hash.sha256Short(msg.ciphertext)
            // Decrypt on IO so we can show a preview in the UI.
            // Plaintext goes only to the UI — never to log() or RedactingLogger.
            viewModelScope.launch(Dispatchers.IO) {
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
                // Advance last_seen_seq
                if (msg.seq > 0 && msg.seq > TokenStore.lastSeenSeq) {
                    TokenStore.saveLastSeenSeq(getApplication(), msg.seq)
                }
            }
        }

        override fun onHello(latestSeq: Int) {
            val lastSeen = TokenStore.lastSeenSeq
            log("Hello: latest_seq=$latestSeq last_seen=$lastSeen")
            if (latestSeq <= lastSeen) return
            viewModelScope.launch(Dispatchers.IO) {
                fetchMissedClips(lastSeen)
            }
        }

        override fun onLog(text: String) = log(text)
    }

    /**
     * Fetch clips with seq > [afterSeq] from the server and add them to the received list.
     * Called after WS hello when the server has newer clips than we last saw.
     */
    private suspend fun fetchMissedClips(afterSeq: Int) {
        val deviceToken = TokenStore.deviceToken ?: return
        val myDeviceId  = TokenStore.deviceId    ?: return
        try {
            val clips = clipsApi().fetchHistory(deviceToken, afterSeq)
            log("Catch-up: ${clips.size} missed clip(s) after seq=$afterSeq")
            var maxSeq = afterSeq
            for (clip in clips) {
                if (clip.from_device_id == myDeviceId) continue
                val preview = tryDecryptPreview(clip.ciphertext, clip.nonce)
                val ui = ReceivedMessageUi(
                    messageId      = clip.message_id,
                    fromDeviceId   = clip.from_device_id,
                    ciphertextHash = Hash.sha256Short(clip.ciphertext),
                    timestamp      = ts(),
                    direction      = "IN (catch-up)",
                    preview        = preview
                )
                _uiState.update {
                    it.copy(receivedMessages = (it.receivedMessages + ui).takeLast(50))
                }
                if (clip.seq > maxSeq) maxSeq = clip.seq
            }
            if (maxSeq > afterSeq) {
                TokenStore.saveLastSeenSeq(getApplication(), maxSeq)
                log("Catch-up: last_seen_seq advanced to $maxSeq")
            }
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
            log("Auto-connecting WS…")
            onConnectWs()
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
        approvalPollJob?.cancel()
        approvalPollJob = null
        stopClipboardMonitor()
        recentHashCache.clear()
        TokenStore.clearDeviceAuth()
        // Clear device creds from DataStore asynchronously (in-memory already cleared above).
        viewModelScope.launch(Dispatchers.IO) {
            TokenStore.clearDeviceAuth(getApplication())
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
                localClipItems           = emptyList()
            )
        }
        log("Device session reset")
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
        approvalPollJob?.cancel()
        clipboardMonitorJob?.cancel()
    }
}