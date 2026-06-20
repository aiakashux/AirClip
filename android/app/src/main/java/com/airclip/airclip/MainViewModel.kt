package com.airclip.airclip

import android.app.Application
import android.content.ClipboardManager
import android.content.Context
import android.graphics.Bitmap
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.airclip.airclip.crypto.KeyManager
import com.airclip.airclip.device.PairingState
import com.airclip.airclip.lan.LanServer
import com.airclip.airclip.lan.LanRuntimeDiagnostic
import com.airclip.airclip.lan.LanRuntimeDiagnostics
import com.airclip.airclip.lan.PeerManager
import com.airclip.airclip.pairing.PairingSession
import com.airclip.airclip.pairing.PairingCode
import com.airclip.airclip.pairing.PairingClient
import com.airclip.airclip.pairing.ResolvedHostCache
import kotlinx.coroutines.Dispatchers
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

    private val keyManager = KeyManager(app)

    private val httpClient = OkHttpClient.Builder()
        .connectTimeout(10, TimeUnit.SECONDS)
        .readTimeout(15, TimeUnit.SECONDS)
        .build()

    private val _uiState = MutableStateFlow(UiState())
    val uiState: StateFlow<UiState> = _uiState

    init {
        Prefs.init(app)
        _uiState.update {
            it.copy(
                syncMode = Prefs.syncMode,
                sensitiveRules = Prefs.sensitiveRules(),
            )
        }

        // Load identity from disk on startup
        viewModelScope.launch(Dispatchers.IO) {
            AirClipIdentity.loadFromDisk(app)
            keyManager.loadFromDisk()

            if (AirClipIdentity.isPaired) {
                _uiState.update {
                    it.copy(
                        pairingState = PairingState.Paired,
                        deviceName   = AirClipIdentity.deviceName,
                        pairedDevices = AirClipIdentity.pairedDevices.values.toList(),
                        myDeviceId   = AirClipIdentity.deviceId,
                    )
                }
                initSync(app)
                autoConnect()
            } else {
                // Ensure we have a device_id for the QR even before pairing completes
                AirClipIdentity.ensureDeviceId()
                if (!keyManager.isInitialized) keyManager.generateKeypair()
                _uiState.update { it.copy(deviceName = AirClipIdentity.deviceName) }
            }
        }

        // Forward SyncEngine clip history into UiState
        viewModelScope.launch {
            SyncEngine.clipHistory.collect { history ->
                _uiState.update { it.copy(clipHistory = history) }
            }
        }

        // Forward peer count into UiState
        viewModelScope.launch {
            SyncEngine.connectedPeerCount.collect { count ->
                _uiState.update { it.copy(connectedPeerCount = count) }
            }
        }

        viewModelScope.launch {
            LanRuntimeDiagnostics.state.collect { diagnostic ->
                _uiState.update { it.copy(lanRuntimeDiagnostic = diagnostic) }
            }
        }

        // Wire LanServer pairing callbacks to ViewModel
        LanServer.onPairAccepted = { airClipId, deviceId, deviceName, publicKey ->
            val app2 = getApplication<Application>()
            val device = PairedDevice(
                deviceId   = deviceId,
                deviceName = deviceName,
                publicKey  = publicKey,
                platform   = "unknown",
                lastSeenMs = System.currentTimeMillis(),
            )
            AirClipIdentity.joinAirClip(app2, airClipId, AirClipIdentity.deviceName, listOf(device))
            PairingSession.stop()
            _uiState.update {
                it.copy(
                    pairingState  = PairingState.Paired,
                    pairedDevices = AirClipIdentity.pairedDevices.values.toList(),
                    myDeviceId    = AirClipIdentity.deviceId,
                    pairingQr     = null,
                    pairingCode   = null,
                )
            }
            initSync(app2)
            autoConnect()
        }

        LanServer.onPairSuccess = {
            log("Pairing complete")
        }

        PeerManager.onRemovedFromNetwork = {
            viewModelScope.launch(Dispatchers.IO) {
                handleRemovedFromNetwork()
            }
        }
    }

    // ── UI State ──────────────────────────────────────────────────────────────

    data class UiState(
        val pairingState: PairingState      = PairingState.NotPaired,
        val deviceName: String              = "",
        val myDeviceId: String?             = null,
        val pairedDevices: List<PairedDevice> = emptyList(),
        val connectedPeerCount: Int         = 0,
        val clipHistory: List<ClipItemRecord> = emptyList(),
        val statusLog: List<String>         = emptyList(),
        val lastError: String?              = null,
        val isConnected: Boolean            = false,
        val syncMode: SyncMode              = SyncMode.MANUAL_ONLY,
        val lanRuntimeDiagnostic: LanRuntimeDiagnostic = LanRuntimeDiagnostic(),
        val sensitiveRules: Map<SensitiveCategory, SensitiveRuleAction> =
            SensitiveCategory.entries.associateWith { SensitiveRuleAction.ASK },
        val pendingSensitiveFinding: SensitiveFinding? = null,
        val sensitiveBlockedNotice: SensitiveFinding? = null,
        // Pairing UI state (shown on onboarding screen)
        val pairingQr: Bitmap?              = null,
        val pairingCode: String?            = null,
        val isPairingWaiting: Boolean       = false,
    )

    // ── Onboarding: device name ───────────────────────────────────────────────

    fun onDeviceNameChange(v: String) {
        AirClipIdentity.setDeviceName(v)
        _uiState.update { it.copy(deviceName = v) }
    }

    fun onRenameDevice(name: String) = runAsync("renameDevice") {
        val app = getApplication<Application>()
        val trimmed = name.trim()
        if (trimmed.isEmpty()) return@runAsync
        AirClipIdentity.renameDevice(app, trimmed)
        _uiState.update { it.copy(deviceName = trimmed) }
    }

    // ── Onboarding: Create an AirClip network ────────────────────────────────────

    fun onCreateAirClip() = runAsync("createAirClip") {
        val app  = getApplication<Application>()
        val name = _uiState.value.deviceName.ifBlank { android.os.Build.MODEL }

        if (!keyManager.isInitialized) keyManager.generateKeypair()
        AirClipIdentity.createAirClip(app, name)

        _uiState.update {
            it.copy(
                pairingState  = PairingState.Paired,
                deviceName    = name,
                myDeviceId    = AirClipIdentity.deviceId,
                pairedDevices = emptyList(),
                lastError     = null,
            )
        }
        initSync(app)
        autoConnect()
        log("AirClip created — device_id=${AirClipIdentity.deviceId?.take(8)}")
    }

    // ── Onboarding: Join an AirClip network — show pairing QR for scanning ───────

    fun onStartPairingSession() = runAsync("startPairing") {
        val name = _uiState.value.deviceName.ifBlank { android.os.Build.MODEL }
        AirClipIdentity.setDeviceName(name)
        AirClipIdentity.ensureDeviceId()
        if (!keyManager.isInitialized) keyManager.generateKeypair()

        // Start pairing session (QR + code, refreshes every 60s)
        PairingSession.start(
            airClipId     = AirClipIdentity.airClipId,     // null for new device
            deviceId   = AirClipIdentity.deviceId!!,
            deviceName = name,
            publicKey  = keyManager.getPublicKeyBase64(),
        )

        // Start LAN server so existing device can send pair_request to us
        val app = getApplication<Application>()
        SyncEngine.init(app, keyManager, httpClient)
        LanServer.start(keyManager)

        // Generate QR bitmap on IO thread
        val qrBitmap = PairingSession.generateQrBitmap()

        _uiState.update {
            it.copy(
                isPairingWaiting = true,
                pairingQr        = qrBitmap,
                pairingCode      = PairingSession.currentCode,
                lastError        = null,
            )
        }
        log("Pairing session started — code=${PairingSession.currentCode}")
    }

    /** Refresh the displayed QR/code (called when code expires after 60s). */
    fun onRefreshPairingCode() = viewModelScope.launch(Dispatchers.IO) {
        val qrBitmap = PairingSession.generateQrBitmap()
        _uiState.update { it.copy(pairingQr = qrBitmap, pairingCode = PairingSession.currentCode) }
    }

    /** Cancel the pairing wait and return to the Create/Join choice. */
    fun onCancelPairing() {
        PairingSession.stop()
        LanServer.stop()
        _uiState.update { it.copy(isPairingWaiting = false, pairingQr = null, pairingCode = null, lastError = null) }
    }

    // ── Join via QR scan (existing device shows QR, this device scans) ────────

    /**
     * Called after this device scans an existing AirClip member's QR.
     * The QR contains {airclip_id, device_id, device_name, public_key, code, host?, ssid?}.
     *
     * Priority:
     *   1. If [host] is in the payload → connect directly (no mDNS, instant).
     *   2. Otherwise start LanBrowser and wait up to 5s for mDNS to resolve the host.
     *   3. If still unresolved → surface a helpful error with network name if available.
    */
    fun onQrScanned(qrContent: String) = runAsync("qrScanned") {
        val payload = com.google.gson.Gson().fromJson(
            qrContent,
            com.airclip.airclip.pairing.PairingPayload::class.java,
        )

        val myName = _uiState.value.deviceName.ifBlank { android.os.Build.MODEL }
        AirClipIdentity.setDeviceName(myName)
        AirClipIdentity.ensureDeviceId()
        if (!keyManager.isInitialized) keyManager.generateKeypair()

        val onSuccess: (String, List<PairedDevice>) -> Unit = ::completeOutgoingPairing
        val showPairingError: (String) -> Unit = { reason ->
            val hint = if (payload.ssid != null)
                "Make sure you're connected to \"${payload.ssid}\" Wi-Fi."
            else
                "Make sure both devices are on the same Wi-Fi."
            _uiState.update { it.copy(lastError = "Pairing failed: $reason\n$hint") }
        }

        // 1. Direct IP from QR payload — fastest path, no mDNS needed.
        val directHost = payload.host
        if (!directHost.isNullOrBlank()) {
            log("QR has host=$directHost — connecting directly")
            com.airclip.airclip.pairing.PairingClient.sendPairRequestToHost(
                host           = directHost,
                targetDeviceId = payload.device_id,
                targetAirClipId   = payload.airclip_id ?: "",
                code           = payload.code,
                myDeviceId     = AirClipIdentity.deviceId!!,
                myDeviceName   = myName,
                myPublicKey    = keyManager.getPublicKeyBase64(),
                httpClient     = httpClient,
                onSuccess      = onSuccess,
                onError        = {
                    viewModelScope.launch(Dispatchers.IO) {
                        connectToScannedDeviceThroughDiscovery(
                            payload = payload,
                            myName = myName,
                            onSuccess = onSuccess,
                            onError = showPairingError,
                        )
                    }
                },
            )
            return@runAsync
        }

        connectToScannedDeviceThroughDiscovery(
            payload = payload,
            myName = myName,
            onSuccess = onSuccess,
            onError = showPairingError,
        )
    }

    private suspend fun connectToScannedDeviceThroughDiscovery(
        payload: com.airclip.airclip.pairing.PairingPayload,
        myName: String,
        onSuccess: (String, List<PairedDevice>) -> Unit,
        onError: (String) -> Unit,
    ) {
        val app = getApplication<Application>()
        log("Starting LanBrowser and waiting for mDNS")
        SyncEngine.init(app, keyManager, httpClient)
        com.airclip.airclip.lan.LanBrowser.start(app, httpClient, keyManager)

        var elapsed = 0
        while (elapsed < 5000) {
            val cached = com.airclip.airclip.pairing.ResolvedHostCache.getHost(payload.device_id)
            if (!cached.isNullOrBlank()) {
                log("mDNS resolved ${payload.device_id.take(8)} → $cached after ${elapsed}ms")
                com.airclip.airclip.pairing.PairingClient.sendPairRequestToHost(
                    host           = cached,
                    targetDeviceId = payload.device_id,
                    targetAirClipId   = payload.airclip_id ?: "",
                    code           = payload.code,
                    myDeviceId     = AirClipIdentity.deviceId!!,
                    myDeviceName   = myName,
                    myPublicKey    = keyManager.getPublicKeyBase64(),
                    httpClient     = httpClient,
                    onSuccess      = onSuccess,
                    onError        = onError,
                )
                return
            }
            delay(200)
            elapsed += 200
        }

        onError("Device not found on LAN.")
    }

    fun onPairingCodeEntered(value: String) = runAsync("pairingCode") {
        val code = PairingCode.normalize(value)
        if (!PairingCode.isValid(code)) {
            _uiState.update { it.copy(lastError = "Enter the complete 8-digit pairing code.") }
            return@runAsync
        }

        val app = getApplication<Application>()
        val myName = _uiState.value.deviceName.ifBlank { android.os.Build.MODEL }
        AirClipIdentity.setDeviceName(myName)
        AirClipIdentity.ensureDeviceId()
        if (!keyManager.isInitialized) keyManager.generateKeypair()

        SyncEngine.init(app, keyManager, httpClient)
        com.airclip.airclip.lan.LanBrowser.start(app, httpClient, keyManager)

        var elapsed = 0
        while (ResolvedHostCache.all().isEmpty() && elapsed < 5_000) {
            delay(200)
            elapsed += 200
        }

        val hosts = ResolvedHostCache.all().entries.toList()
        if (hosts.isEmpty()) {
            _uiState.update {
                it.copy(lastError = "No AirClip device found. Make sure both devices are on the same Wi-Fi.")
            }
            return@runAsync
        }

        probeNextHostForCode(hosts, code, myName, 0)
    }

    private fun probeNextHostForCode(
        hosts: List<Map.Entry<String, String>>,
        code: String,
        myName: String,
        index: Int,
    ) {
        if (index >= hosts.size) {
            _uiState.update { it.copy(lastError = "No device accepted that code. Refresh the code and try again.") }
            return
        }

        val (targetHint, host) = hosts[index]
        PairingClient.probeHostForCode(
            host = host,
            code = code,
            httpClient = httpClient,
            onFound = { deviceId, _, _, airClipId ->
                PairingClient.sendPairRequestToHost(
                    host = host,
                    targetDeviceId = deviceId.ifBlank { targetHint },
                    targetAirClipId = airClipId,
                    code = code,
                    myDeviceId = AirClipIdentity.deviceId!!,
                    myDeviceName = myName,
                    myPublicKey = keyManager.getPublicKeyBase64(),
                    httpClient = httpClient,
                    onSuccess = ::completeOutgoingPairing,
                    onError = { reason ->
                        _uiState.update { it.copy(lastError = "Pairing failed: $reason") }
                    },
                )
            },
            onError = {
                probeNextHostForCode(hosts, code, myName, index + 1)
            },
        )
    }

    private fun completeOutgoingPairing(airClipId: String, allDevices: List<PairedDevice>) {
        val app = getApplication<Application>()
        val myName = _uiState.value.deviceName.ifBlank { android.os.Build.MODEL }
        viewModelScope.launch(Dispatchers.IO) {
            AirClipIdentity.joinAirClip(app, airClipId, myName, allDevices)
            PairingSession.stop()
            com.airclip.airclip.lan.LanBrowser.stop(app)
            _uiState.update {
                it.copy(
                    pairingState = PairingState.Paired,
                    pairedDevices = AirClipIdentity.pairedDevices.values.toList(),
                    myDeviceId = AirClipIdentity.deviceId,
                    isPairingWaiting = false,
                    pairingQr = null,
                    pairingCode = null,
                    lastError = null,
                )
            }
            initSync(app)
            autoConnect()
            log("Joined AirClip")
        }
    }

    // ── Main app: clipboard ───────────────────────────────────────────────────

    fun onAppForegrounded() {
        if (!_uiState.value.syncMode.allowsAutomaticCapture) return
        captureCurrentClipboard()
    }

    fun onCaptureClipboard() {
        if (!_uiState.value.syncMode.allowsManualSend) return
        captureCurrentClipboard(SensitiveSendIntent.MANUAL)
    }

    private fun captureCurrentClipboard(
        intent: SensitiveSendIntent = SensitiveSendIntent.AUTOMATIC,
    ) {
        if (AirClipIdentity.deviceId == null) return
        val app = getApplication<Application>()
        val cm  = app.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        val text = try {
            cm.primaryClip
                ?.takeIf { it.itemCount > 0 }
                ?.getItemAt(0)
                ?.coerceToText(app)
                ?.toString()
                ?.trim()
                ?.takeIf { it.isNotEmpty() }
        } catch (_: Exception) { null }

        if (text == null) return

        requestSend(text, intent)
    }

    fun onClipboardChanged(text: String) {
        if (!_uiState.value.syncMode.allowsAutomaticCapture) return
        if (AirClipIdentity.deviceId == null) return
        requestSend(text, SensitiveSendIntent.AUTOMATIC)
    }

    private var pendingSensitiveText: String? = null

    private fun requestSend(text: String, intent: SensitiveSendIntent) {
        val assessment = SensitiveClipboardClassifier.classify(text)
        val action = assessment.primaryFinding
            ?.let { _uiState.value.sensitiveRules[it.category] }
            ?: SensitiveRuleAction.ASK
        when (SensitiveClipboardPolicy.decide(assessment, intent, action)) {
            SensitiveSendDecision.ALLOW -> {
                viewModelScope.launch(Dispatchers.IO) {
                    SyncEngine.sendClip(text)
                }
            }
            SensitiveSendDecision.BLOCK -> {
                pendingSensitiveText = null
                _uiState.update {
                    it.copy(sensitiveBlockedNotice = assessment.primaryFinding)
                }
            }
            SensitiveSendDecision.REQUIRE_CONFIRMATION -> {
                pendingSensitiveText = text
                _uiState.update {
                    it.copy(pendingSensitiveFinding = assessment.primaryFinding)
                }
            }
        }
    }

    fun onConfirmSensitiveSend() {
        val text = pendingSensitiveText ?: return
        pendingSensitiveText = null
        _uiState.update { it.copy(pendingSensitiveFinding = null) }
        viewModelScope.launch(Dispatchers.IO) {
            SyncEngine.sendClip(text, sensitiveOverride = true)
        }
    }

    fun onCancelSensitiveSend() {
        pendingSensitiveText = null
        _uiState.update { it.copy(pendingSensitiveFinding = null) }
    }

    fun onSensitiveBlockedNoticeShown() {
        _uiState.update { it.copy(sensitiveBlockedNotice = null) }
    }

    fun onSensitiveRuleChanged(
        category: SensitiveCategory,
        action: SensitiveRuleAction,
    ) {
        Prefs.setSensitiveRule(category, action)
        _uiState.update { state ->
            state.copy(sensitiveRules = state.sensitiveRules + (category to action))
        }
    }

    fun onHistoryItemCopyStarted(item: ClipItemRecord) {
        SyncEngine.suppressHistoryItem(item)
    }

    fun onToggleSaved(item: ClipItemRecord) = runAsync("toggleSaved") {
        val app = getApplication<Application>()
        val updated = ClipHistoryStore.setSaved(app, item.messageId, !item.isSaved)
        _uiState.update { it.copy(clipHistory = updated) }
    }

    fun onDeleteClip(item: ClipItemRecord) = runAsync("deleteClip") {
        val updated = ClipHistoryStore.remove(getApplication(), item.messageId)
        _uiState.update { it.copy(clipHistory = updated) }
    }

    // ── Devices tab ───────────────────────────────────────────────────────────

    fun onRefreshDevices() {
        _uiState.update {
            it.copy(pairedDevices = AirClipIdentity.pairedDevices.values.toList())
        }
    }

    fun onRemoveDevice(deviceId: String) = runAsync("removeDevice") {
        val app = getApplication<Application>()
        AirClipIdentity.removeDevice(app, deviceId)
        _uiState.update { it.copy(pairedDevices = AirClipIdentity.pairedDevices.values.toList()) }
    }

    private suspend fun handleRemovedFromNetwork() {
        val app = getApplication<Application>()
        SyncService.stop(app)
        SyncEngine.disconnect()
        PairingSession.stop()
        keyManager.clearKeypair()
        AirClipIdentity.clearAll(app)
        _uiState.update {
            UiState(
                deviceName = android.os.Build.MODEL,
                syncMode = Prefs.syncMode,
                sensitiveRules = Prefs.sensitiveRules(),
            )
        }
        log("This device was removed from the AirClip network")
    }

    // ── Settings ──────────────────────────────────────────────────────────────

    fun onSyncModeChanged(mode: SyncMode) {
        val app = getApplication<Application>()
        Prefs.syncMode = mode
        _uiState.update {
            it.copy(
                syncMode = mode,
                isConnected = mode.keepsLanServiceRunning && AirClipIdentity.isPaired,
            )
        }

        if (!AirClipIdentity.isPaired) return

        if (mode.keepsLanServiceRunning) {
            SyncService.start(app)
        } else {
            SyncService.stop(app)
        }
    }

    fun onResetAirClip() = runAsync("resetAirClip") {
        val app = getApplication<Application>()
        SyncService.stop(app)
        SyncEngine.disconnect()
        PairingSession.stop()
        keyManager.clearKeypair()
        AirClipIdentity.clearAll(app)
        ClipHistoryStore.clear(app)
        Prefs.clearAll()
        _uiState.update {
            UiState(deviceName = android.os.Build.MODEL)
        }
        log("AirClip reset — all data cleared")
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    private fun initSync(app: Application) {
        SyncEngine.init(app, keyManager, httpClient)
        SyncEngine.loadHistory(app)
    }

    private fun autoConnect() {
        val app = getApplication<Application>()
        val mode = _uiState.value.syncMode
        if (mode.keepsLanServiceRunning) {
            SyncService.start(app)
            _uiState.update { it.copy(isConnected = true) }
            log("LAN sync started")
        } else {
            SyncService.stop(app)
            _uiState.update { it.copy(isConnected = false) }
            log("Sync paused")
        }
    }

    private fun log(msg: String) {
        val line = "[${ts()}] $msg"
        _uiState.update { s -> s.copy(statusLog = (s.statusLog + line).takeLast(50)) }
    }

    private fun ts() = SimpleDateFormat("HH:mm:ss", Locale.US).format(Date())

    private fun runAsync(label: String, block: suspend () -> Unit) {
        viewModelScope.launch(Dispatchers.IO) {
            try {
                block()
            } catch (e: Exception) {
                val msg = "[$label] ${e.message ?: e.javaClass.simpleName}"
                _uiState.update { it.copy(lastError = msg) }
                log(msg)
            }
        }
    }
}
