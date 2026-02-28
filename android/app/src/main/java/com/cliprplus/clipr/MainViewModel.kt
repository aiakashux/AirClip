package com.cliprplus.clipr

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.cliprplus.clipr.auth.AuthApi
import com.cliprplus.clipr.auth.TokenStore
import com.cliprplus.clipr.crypto.KeyManager
import com.cliprplus.clipr.crypto.SealedBox
import com.cliprplus.clipr.device.AuthState
import com.cliprplus.clipr.device.DeviceApi
import com.cliprplus.clipr.device.DeviceApprovalState
import com.cliprplus.clipr.device.TokenState
import com.cliprplus.clipr.device.WsState
import com.cliprplus.clipr.util.Hash
import com.cliprplus.clipr.util.RedactingLogger
import com.cliprplus.clipr.ws.CliprWebSocket
import com.cliprplus.clipr.ws.CliprWsListener
import com.cliprplus.clipr.ws.ClipboardPayload
import com.cliprplus.clipr.ws.DeliveredMessage
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
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

    // Shared HTTP client — reused across all REST API calls.
    private val httpClient = OkHttpClient.Builder()
        .connectTimeout(10, TimeUnit.SECONDS)
        .readTimeout(15, TimeUnit.SECONDS)
        .build()

    // API clients are created on-demand using the current baseUrl so that
    // a URL change in the debug field takes effect on the next call.
    private fun authApi()   = AuthApi(_uiState.value.baseUrl, httpClient)
    private fun deviceApi() = DeviceApi(_uiState.value.baseUrl, httpClient)

    // Derive WS URL from the current HTTP base URL.
    private val wsUrl get() = _uiState.value.baseUrl
        .replace("http://", "ws://")
        .replace("https://", "wss://") + "/ws"

    private val keyManager = KeyManager()

    private var wsClient: CliprWebSocket? = null
    private var approvalPollJob: Job? = null

    // ------------------------------------------------------------------
    // UI state
    // ------------------------------------------------------------------

    /** Immutable snapshot of everything the DebugScreen needs. */
    data class ReceivedMessageUi(
        val messageId: String,
        val fromDeviceId: String,
        val ciphertextHash: String,  // hash only — never plaintext
        val timestamp: String,
        val direction: String = "IN"
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
        val lastRefreshError: String? = null
    )

    private val _uiState = MutableStateFlow(UiState())
    val uiState: StateFlow<UiState> = _uiState

    // ------------------------------------------------------------------
    // UI event handlers
    // ------------------------------------------------------------------

    fun onEmailChange(v: String)   = _uiState.update { it.copy(email = v) }
    fun onPasswordChange(v: String) = _uiState.update { it.copy(password = v) }
    fun onBaseUrlChange(v: String) = _uiState.update { it.copy(baseUrl = v) }

    fun onRegister() = runAsync("register") {
        resetDeviceSessionState()
        val s = _uiState.value
        val resp = authApi().register(s.email, s.password)
        TokenStore.setAccountAuth(resp.token, resp.account_id)
        log("Registered — account_id=${resp.account_id}")
        _uiState.update { it.copy(authState = AuthState.AccountTokenReady, lastError = null) }
    }

    fun onLogin() = runAsync("login") {
        resetDeviceSessionState()
        val s = _uiState.value
        val resp = authApi().login(s.email, s.password)
        TokenStore.setAccountAuth(resp.token, resp.account_id)
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
        TokenStore.setDeviceAuth(resp.token, resp.device_id)
        log("Device registered id=${resp.device_id} trust=${resp.trust_status}")

        val approvalState = when (resp.trust_status) {
            "trusted" -> DeviceApprovalState.Approved
            "pending" -> DeviceApprovalState.PendingApproval
            else      -> DeviceApprovalState.Revoked
        }
        _uiState.update {
            it.copy(
                tokenState          = TokenState.DeviceTokenReady,
                deviceApprovalState = approvalState,
                lastError           = null
            )
        }
        if (approvalState == DeviceApprovalState.PendingApproval) {
            startApprovalPolling()
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
                val devices  = deviceApi().listDevices(accountToken)
                val myDevice = devices.find { it.device_id == myDeviceId }
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
                _uiState.update {
                    it.copy(
                        deviceApprovalState = approvalState,
                        lastRefreshTime     = ts(),
                        lastRefreshError    = null
                    )
                }
                log("Refresh: trust=$newStatus")
                if (approvalState == DeviceApprovalState.Approved) {
                    log("Device trusted — Connect WS available")
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
        _uiState.update { it.copy(wsState = WsState.Connecting, lastError = null) }
        wsClient = CliprWebSocket(
            wsBaseUrl   = wsUrl,
            deviceToken = deviceToken,
            listener    = wsListener
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

    // ------------------------------------------------------------------
    // WebSocket listener (runs on OkHttp dispatch thread)
    // ------------------------------------------------------------------

    private val wsListener = object : CliprWsListener {
        override fun onConnected() {
            _uiState.update { it.copy(wsState = WsState.Connected, lastError = null) }
            log("WS connected")
        }

        override fun onDisconnected(code: Int, reason: String) {
            _uiState.update { it.copy(wsState = WsState.Disconnected) }
            log("WS disconnected $code")
        }

        /**
         * Server rejected the WS upgrade (401/403) — device token is invalid.
         * Block reconnect until the user re-registers the device.
         */
        override fun onAuthFailed() {
            wsClient?.disconnect()  // sets shouldReconnect = false; prevents auto-reconnect
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
            // Store encrypted — DO NOT write to Android clipboard
            val ui = ReceivedMessageUi(
                messageId      = msg.messageId,
                fromDeviceId   = msg.fromDeviceId,
                ciphertextHash = Hash.sha256Short(msg.ciphertext),  // hash only
                timestamp      = ts()
            )
            _uiState.update {
                it.copy(receivedMessages = (it.receivedMessages + ui).takeLast(50))
            }
            log("← msg from ${msg.fromDeviceId.take(8)}… hash=${ui.ciphertextHash}")
        }

        override fun onLog(text: String) = log(text)
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
                            log("Device approved — WS connect now available")
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
        TokenStore.clearDeviceAuth()
        _uiState.update {
            it.copy(
                tokenState              = TokenState.NoDeviceToken,
                deviceApprovalState     = DeviceApprovalState.NotRegistered,
                wsState                 = WsState.Disconnected,
                approvalPollWaitSeconds = null,
                lastError               = null,
                lastRefreshTime         = null,
                lastRefreshError        = null
            )
        }
        log("Device session reset")
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
    }
}
