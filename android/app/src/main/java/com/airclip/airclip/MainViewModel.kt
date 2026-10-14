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
import com.airclip.airclip.pairing.PairingCompletionPolicy
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
    private val updateManager = AppUpdateManager(app, httpClient)

    private val _uiState = MutableStateFlow(UiState())
    val uiState: StateFlow<UiState> = _uiState
    private val seenSpaceNames = mutableSetOf<String>()

    init {
        Prefs.init(app)
        _uiState.update {
            it.copy(
                syncMode = Prefs.syncMode,
                appearanceSetting = Prefs.appearanceSetting,
                historyDepth = Prefs.historyDepth,
                analyticsEnabled = Prefs.analyticsEnabled,
            )
        }

        viewModelScope.launch(Dispatchers.IO) {
            _uiState.update { it.copy(updateInfo = updateManager.check().update) }
            PrivacyAnalytics.flushIfDue(app, httpClient)
        }

        // Load identity from disk on startup
        viewModelScope.launch(Dispatchers.IO) {
            AirclipIdentity.loadFromDisk(app)
            keyManager.loadFromDisk()

            if (AirclipIdentity.isPaired) {
                _uiState.update {
                    it.copy(
                        pairingState = PairingState.Paired,
                        deviceName   = AirclipIdentity.deviceName,
                        spaceName    = AirclipIdentity.spaceName,
                        pairedDevices = AirclipIdentity.pairedDevices.values.toList(),
                        myDeviceId   = AirclipIdentity.deviceId,
                    )
                }
                initSync(app)
                autoConnect()
            } else {
                // Ensure we have a device_id for the QR even before pairing completes
                AirclipIdentity.ensureDeviceId()
                if (!keyManager.isInitialized) keyManager.generateKeypair()
                _uiState.update { it.copy(deviceName = AirclipIdentity.deviceName) }
            }
        }

        // Forward SyncEngine clip history into UiState
        viewModelScope.launch {
            SyncEngine.clipHistory.collect { history ->
                _uiState.update { it.copy(clipHistory = history) }
            }
        }
        viewModelScope.launch {
            SyncEngine.remoteInsertionId.collect { id ->
                _uiState.update { it.copy(remoteInsertionId = id) }
            }
        }

        // Forward peer count into UiState
        viewModelScope.launch {
            SyncEngine.connectedPeerCount.collect { count ->
                _uiState.update { it.copy(connectedPeerCount = count) }
            }
        }

        viewModelScope.launch {
            AirclipIdentity.pairedDevicesFlow.collect { devices ->
                _uiState.update { it.copy(pairedDevices = devices) }
            }
        }

        viewModelScope.launch {
            LanRuntimeDiagnostics.state.collect { diagnostic ->
                _uiState.update { it.copy(lanRuntimeDiagnostic = diagnostic) }
            }
        }

        // Wire LanServer pairing callbacks to ViewModel
        LanServer.onPairAccepted = { airClipId, spaceName, deviceId, deviceName, publicKey ->
            val app2 = getApplication<Application>()
            val wasPaired = AirclipIdentity.isPaired
            val device = PairedDevice(
                deviceId   = deviceId,
                deviceName = deviceName,
                publicKey  = publicKey,
                platform   = "unknown",
                lastSeenMs = System.currentTimeMillis(),
            )
            if (wasPaired) {
                AirclipIdentity.addOrUpdateDevice(app2, device)
            } else {
                AirclipIdentity.joinAirclip(app2, airClipId, AirclipIdentity.deviceName, spaceName, listOf(device))
            }
            PairingSession.stop()
            _uiState.update {
                it.copy(
                    pairingState  = PairingState.Paired,
                    deviceName    = AirclipIdentity.deviceName,
                    spaceName     = AirclipIdentity.spaceName,
                    pairedDevices = AirclipIdentity.pairedDevices.values.toList(),
                    myDeviceId    = AirclipIdentity.deviceId,
                    isPairingWaiting = false,
                    pairingQr     = null,
                    pairingCode   = null,
                    pairingCodeExpiresAtMs = 0L,
                    lastError     = null,
                    openDevicesOnFirstLaunch = true,
                )
            }
            initSync(app2)
            autoConnect()
            PrivacyAnalytics.record(app2, AnalyticsEvent.PAIRING_SUCCESS)
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
        val spaceName: String               = "",
        val myDeviceId: String?             = null,
        val pairedDevices: List<PairedDevice> = emptyList(),
        val connectedPeerCount: Int         = 0,
        val clipHistory: List<ClipItemRecord> = emptyList(),
        val remoteInsertionId: String?        = null,
        val statusLog: List<String>         = emptyList(),
        val lastError: String?              = null,
        val isConnected: Boolean            = false,
        val syncMode: SyncMode              = SyncMode.AUTO,
        val appearanceSetting: AppAppearanceSetting = AppAppearanceSetting.SYSTEM,
        val historyDepth: Int               = 4,
        val lanRuntimeDiagnostic: LanRuntimeDiagnostic = LanRuntimeDiagnostic(),
        val lastManualRefreshAtMs: Long     = System.currentTimeMillis(),
        val openDevicesOnFirstLaunch: Boolean = false,
        val showNetworkSwitchConfirmation: Boolean = false,
        val updateInfo: UpdateInfo?                 = null,
        val updateStatus: String?                   = null,
        val analyticsEnabled: Boolean               = false,
        // Pairing UI state (shown on onboarding screen)
        val pairingQr: Bitmap?              = null,
        val pairingCode: String?            = null,
        val pairingCodeExpiresAtMs: Long    = 0L,
        val isPairingWaiting: Boolean       = false,
    )

    private sealed interface PendingNetworkSwitch {
        data class Qr(val content: String) : PendingNetworkSwitch
        data class Code(
            val host: String,
            val targetDeviceId: String,
            val targetAirclipId: String,
            val code: String,
            val myName: String,
        ) : PendingNetworkSwitch
    }

    private var pendingNetworkSwitch: PendingNetworkSwitch? = null

    // ── Onboarding: device name ───────────────────────────────────────────────

    fun onDeviceNameChange(v: String) {
        AirclipIdentity.setDeviceName(v)
        _uiState.update { it.copy(deviceName = v, lastError = null) }
    }

    fun onSpaceNameChange(v: String) {
        _uiState.update { it.copy(spaceName = v, lastError = null) }
    }

    fun suggestSpaceName(force: Boolean = false): String? {
        if (!force && _uiState.value.spaceName.isNotBlank()) return null
        val name = SpaceNameSuggestions.next(seenSpaceNames) ?: return null
        seenSpaceNames += name
        _uiState.update { it.copy(spaceName = name, lastError = null) }
        return name
    }

    fun onRenameDevice(name: String) = runAsync("renameDevice") {
        val app = getApplication<Application>()
        val trimmed = name.trim()
        if (trimmed.isEmpty()) return@runAsync
        AirclipIdentity.renameDevice(app, trimmed)
        _uiState.update { it.copy(deviceName = trimmed) }
    }

    // ── Onboarding: Create an Airclip space ──────────────────────────────────────

    fun onCreateAirclip() = runAsync("createAirclip") {
        val app  = getApplication<Application>()
        val name = _uiState.value.deviceName.ifBlank { android.os.Build.MODEL }
        val spaceName = _uiState.value.spaceName.trim()
        _uiState.update { it.copy(lastError = null) }

        if (!keyManager.isInitialized) keyManager.generateKeypair()
        AirclipIdentity.createAirclip(app, name, spaceName)

        _uiState.update {
            it.copy(
                pairingState  = PairingState.Paired,
                deviceName    = name,
                spaceName     = spaceName,
                myDeviceId    = AirclipIdentity.deviceId,
                pairedDevices = emptyList(),
                lastError     = null,
                openDevicesOnFirstLaunch = true,
            )
        }
        initSync(app)
        autoConnect()
        log("Airclip created — device_id=${AirclipIdentity.deviceId?.take(8)}")
    }

    // ── Onboarding: Join an Airclip space — show pairing QR for scanning ─────────

    fun onStartPairingSession() = runAsync("startPairing") {
        val name = _uiState.value.deviceName.ifBlank { android.os.Build.MODEL }
        AirclipIdentity.setDeviceName(name)
        AirclipIdentity.ensureDeviceId()
        if (!keyManager.isInitialized) keyManager.generateKeypair()

        // Start pairing session (QR + code, refreshes every 30s)
        PairingSession.start(
            airClipId     = AirclipIdentity.airClipId,     // null for new device
            deviceId   = AirclipIdentity.deviceId!!,
            deviceName = name,
            spaceName = AirclipIdentity.spaceName,
            publicKey  = keyManager.getPublicKeyBase64(),
            onPayloadChanged = { payload ->
                _uiState.update {
                    it.copy(
                        isPairingWaiting = true,
                        pairingQr = PairingSession.generateQrBitmap(),
                        pairingCode = payload.code,
                        pairingCodeExpiresAtMs = System.currentTimeMillis() + PairingSession.CODE_LIFETIME_MS,
                        lastError = null,
                    )
                }
            },
        )

        // Start LAN server so existing device can send pair_request to us
        val app = getApplication<Application>()
        SyncEngine.init(app, keyManager, httpClient)
        LanServer.start(app, keyManager)
        com.airclip.airclip.lan.LanBrowser.start(app, httpClient, keyManager)

        log("Pairing session started — code=${PairingSession.currentCode}")
    }

    /** Refresh the displayed QR/code (called when code expires after 30s). */
    fun onRefreshPairingCode() = viewModelScope.launch(Dispatchers.IO) {
        PairingSession.refreshNow()
    }

    /** Cancel the pairing wait and return to the Create/Join choice. */
    fun onCancelPairing() {
        val app = getApplication<Application>()
        PairingSession.stop()
        LanServer.stop()
        com.airclip.airclip.lan.LanBrowser.stop(app)
        _uiState.update {
            it.copy(
                isPairingWaiting = false,
                pairingQr = null,
                pairingCode = null,
                pairingCodeExpiresAtMs = 0L,
                lastError = null,
            )
        }
    }

    // ── Join via QR scan (existing device shows QR, this device scans) ────────

    /**
     * Called after this device scans an existing Airclip member's QR.
     * The QR contains {airclip_id, device_id, device_name, public_key, code, host?, ssid?}.
     *
     * Priority:
     *   1. If [host] is in the payload → connect directly (no mDNS, instant).
     *   2. Otherwise start LanBrowser and wait up to 5s for mDNS to resolve the host.
     *   3. If still unresolved → surface a helpful error with network name if available.
    */
    fun onQrScanned(qrContent: String) = runAsync("qrScanned") {
        handleQrScanned(qrContent)
    }

    private suspend fun handleQrScanned(
        qrContent: String,
        allowNetworkSwitch: Boolean = false,
    ) {
        val payload = com.google.gson.Gson().fromJson(
            qrContent,
            com.airclip.airclip.pairing.PairingPayload::class.java,
        )
        val networkIdForPairRequest = payload.airclip_id ?: AirclipIdentity.airClipId.orEmpty()
        if (shouldConfirmNetworkSwitch(networkIdForPairRequest, allowNetworkSwitch)) {
            pendingNetworkSwitch = PendingNetworkSwitch.Qr(qrContent)
            _uiState.update { it.copy(showNetworkSwitchConfirmation = true, lastError = null) }
            return
        }

        val myName = _uiState.value.deviceName.ifBlank { android.os.Build.MODEL }
        AirclipIdentity.setDeviceName(myName)
        AirclipIdentity.ensureDeviceId()
        if (!keyManager.isInitialized) keyManager.generateKeypair()

        val onSuccess: (String, String?, List<PairedDevice>) -> Unit = ::completeOutgoingPairing
        val showPairingError: (String) -> Unit = { reason ->
            val hint = if (payload.ssid != null)
                "Make sure you're connected to \"${payload.ssid}\" Wi-Fi."
            else
                "Make sure both devices are on the same Wi-Fi."
            _uiState.update { it.copy(lastError = "Pairing failed: $reason\n$hint") }
        }
        val onPairingUnavailable: (String) -> Unit = { reason ->
            showPairingError(reason)
        }

        // 1. Direct IP from QR payload — fastest path, no mDNS needed.
        val directHost = payload.host
        if (!directHost.isNullOrBlank()) {
            log("QR has host=$directHost — connecting directly")
            com.airclip.airclip.pairing.PairingClient.sendPairRequestToHost(
                host           = directHost,
                targetDeviceId = payload.device_id,
                targetAirclipId   = networkIdForPairRequest,
                code           = payload.code,
                myDeviceId     = AirclipIdentity.deviceId!!,
                myDeviceName   = myName,
                myPublicKey    = keyManager.getPublicKeyBase64(),
                httpClient     = httpClient,
                onSuccess      = onSuccess,
                onError        = {
                    viewModelScope.launch(Dispatchers.IO) {
                        connectToScannedDeviceThroughDiscovery(
                            payload = payload,
                            myName = myName,
                            targetAirclipId = networkIdForPairRequest,
                            onSuccess = onSuccess,
                            onError = onPairingUnavailable,
                        )
                    }
                },
            )
            return
        }

        connectToScannedDeviceThroughDiscovery(
            payload = payload,
            myName = myName,
            targetAirclipId = networkIdForPairRequest,
            onSuccess = onSuccess,
            onError = onPairingUnavailable,
        )
    }

    private suspend fun connectToScannedDeviceThroughDiscovery(
        payload: com.airclip.airclip.pairing.PairingPayload,
        myName: String,
        targetAirclipId: String,
        onSuccess: (String, String?, List<PairedDevice>) -> Unit,
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
                    targetAirclipId   = targetAirclipId,
                    code           = payload.code,
                    myDeviceId     = AirclipIdentity.deviceId!!,
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
            _uiState.update { it.copy(lastError = "Enter the complete 6-digit pairing code.") }
            return@runAsync
        }
        _uiState.update { it.copy(lastError = null) }

        val app = getApplication<Application>()
        val myName = _uiState.value.deviceName.ifBlank { android.os.Build.MODEL }
        AirclipIdentity.setDeviceName(myName)
        AirclipIdentity.ensureDeviceId()
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
                it.copy(lastError = "No Airclip device found. Make sure both devices are on the same Wi-Fi.")
            }
            return@runAsync
        }

        probeNextHostForCode(hosts, code, myName, 0)
    }

    fun onPairingCodeEntryOpened() {
        _uiState.update { it.copy(lastError = null) }
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
                val targetDeviceId = deviceId.ifBlank { targetHint }
                val pairingAirclipId = PairingCompletionPolicy.pairingAirclipId(
                    targetAirclipId = airClipId,
                    currentAirclipId = AirclipIdentity.airClipId,
                )
                if (pairingAirclipId == null) {
                    _uiState.update { it.copy(lastError = "Create or join a space before adding another new device.") }
                    return@probeHostForCode
                }
                if (shouldConfirmNetworkSwitch(pairingAirclipId, allowNetworkSwitch = false)) {
                    pendingNetworkSwitch = PendingNetworkSwitch.Code(
                        host = host,
                        targetDeviceId = targetDeviceId,
                        targetAirclipId = pairingAirclipId,
                        code = code,
                        myName = myName,
                    )
                    _uiState.update { it.copy(showNetworkSwitchConfirmation = true, lastError = null) }
                    return@probeHostForCode
                }
                sendPairRequestToFoundHost(
                    host = host,
                    targetDeviceId = targetDeviceId,
                    targetAirclipId = pairingAirclipId,
                    code = code,
                    myName = myName,
                )
            },
            onError = {
                probeNextHostForCode(hosts, code, myName, index + 1)
            },
        )
    }

    private fun sendPairRequestToFoundHost(
        host: String,
        targetDeviceId: String,
        targetAirclipId: String,
        code: String,
        myName: String,
    ) {
        PairingClient.sendPairRequestToHost(
            host = host,
            targetDeviceId = targetDeviceId,
            targetAirclipId = targetAirclipId,
            code = code,
            myDeviceId = AirclipIdentity.deviceId!!,
            myDeviceName = myName,
            myPublicKey = keyManager.getPublicKeyBase64(),
            httpClient = httpClient,
            onSuccess = ::completeOutgoingPairing,
            onError = { reason ->
                _uiState.update { it.copy(lastError = "Pairing failed: $reason") }
            },
        )
    }

    private fun shouldConfirmNetworkSwitch(
        targetAirclipId: String,
        allowNetworkSwitch: Boolean,
    ): Boolean {
        if (allowNetworkSwitch || targetAirclipId.isBlank()) return false
        val currentAirclipId = AirclipIdentity.airClipId ?: return false
        return AirclipIdentity.isPaired && currentAirclipId != targetAirclipId
    }

    fun onCancelNetworkSwitch() {
        pendingNetworkSwitch = null
        _uiState.update { it.copy(showNetworkSwitchConfirmation = false) }
    }

    fun onConfirmNetworkSwitch() = runAsync("confirmNetworkSwitch") {
        val pending = pendingNetworkSwitch ?: return@runAsync
        pendingNetworkSwitch = null
        _uiState.update { it.copy(showNetworkSwitchConfirmation = false, lastError = null) }

        val app = getApplication<Application>()
        val myName = when (pending) {
            is PendingNetworkSwitch.Code -> pending.myName
            is PendingNetworkSwitch.Qr -> _uiState.value.deviceName.ifBlank { android.os.Build.MODEL }
        }
        resetLocalAirclipForNetworkSwitch(app, myName)

        when (pending) {
            is PendingNetworkSwitch.Qr -> handleQrScanned(
                qrContent = pending.content,
                allowNetworkSwitch = true,
            )
            is PendingNetworkSwitch.Code -> {
                prepareOutgoingPairingIdentity(myName)
                sendPairRequestToFoundHost(
                    host = pending.host,
                    targetDeviceId = pending.targetDeviceId,
                    targetAirclipId = pending.targetAirclipId,
                    code = pending.code,
                    myName = myName,
                )
            }
        }
    }

    private suspend fun resetLocalAirclipForNetworkSwitch(app: Application, myName: String) {
        SyncService.stop(app)
        SyncEngine.disconnect()
        PairingSession.stop()
        keyManager.clearKeypair()
        AirclipIdentity.clearAll(app)
        SyncEngine.clearLocalSession(app)
        ResolvedHostCache.clear()
        AirclipIdentity.setDeviceName(myName)
        _uiState.update {
            it.copy(
                pairingState = PairingState.NotPaired,
                deviceName = myName,
                myDeviceId = null,
                pairedDevices = emptyList(),
                connectedPeerCount = 0,
                clipHistory = emptyList(),
                isConnected = false,
                isPairingWaiting = false,
                pairingQr = null,
                pairingCode = null,
                pairingCodeExpiresAtMs = 0L,
            )
        }
    }

    private fun prepareOutgoingPairingIdentity(myName: String) {
        AirclipIdentity.setDeviceName(myName)
        AirclipIdentity.ensureDeviceId()
        if (!keyManager.isInitialized) keyManager.generateKeypair()
    }

    private fun completeOutgoingPairing(airClipId: String, spaceName: String?, allDevices: List<PairedDevice>) {
        val app = getApplication<Application>()
        val myName = _uiState.value.deviceName.ifBlank { android.os.Build.MODEL }
        viewModelScope.launch(Dispatchers.IO) {
            if (PairingCompletionPolicy.shouldMergeIntoExistingNetwork(
                    isAlreadyPaired = AirclipIdentity.isPaired,
                    currentAirclipId = AirclipIdentity.airClipId,
                    incomingAirclipId = airClipId,
                )
            ) {
                allDevices
                    .filter { it.deviceId != AirclipIdentity.deviceId }
                    .forEach { AirclipIdentity.addOrUpdateDevice(app, it) }
            } else {
                AirclipIdentity.joinAirclip(app, airClipId, myName, spaceName, allDevices)
            }
            PairingSession.stop()
            com.airclip.airclip.lan.LanBrowser.stop(app)
            _uiState.update {
                it.copy(
                    pairingState = PairingState.Paired,
                    pairedDevices = AirclipIdentity.pairedDevices.values.toList(),
                    myDeviceId = AirclipIdentity.deviceId,
                    spaceName = AirclipIdentity.spaceName,
                    isPairingWaiting = false,
                    pairingQr = null,
                    pairingCode = null,
                    pairingCodeExpiresAtMs = 0L,
                    lastError = null,
                    openDevicesOnFirstLaunch = true,
                )
            }
            initSync(app)
            autoConnect()
            PrivacyAnalytics.record(app, AnalyticsEvent.PAIRING_SUCCESS)
            log("Joined Airclip")
        }
    }

    fun onCheckForUpdates() {
        _uiState.update { it.copy(updateStatus = "Checking for updates…") }
        viewModelScope.launch(Dispatchers.IO) {
            val result = updateManager.check(force = true)
            val info = result.update
            _uiState.update {
                it.copy(
                    updateInfo = info,
                    updateStatus = when {
                        result.failed -> "Couldn’t check for updates"
                        info == null -> "Airclip is up to date"
                        else -> "Version ${info.versionName} available"
                    },
                )
            }
        }
    }

    fun onUpdateLater() {
        _uiState.update { it.copy(updateInfo = null, updateStatus = null) }
    }

    fun onUpdateOpened() {
        PrivacyAnalytics.record(getApplication(), AnalyticsEvent.UPDATE_OPENED)
        _uiState.update { it.copy(updateInfo = null, updateStatus = null) }
    }

    fun onUpdateOpenFailed() {
        PrivacyAnalytics.record(getApplication(), AnalyticsEvent.UPDATE_FAILURE)
        _uiState.update { it.copy(updateStatus = "Couldn’t open the download page") }
    }

    fun onAnalyticsEnabledChanged(enabled: Boolean) {
        val app = getApplication<Application>()
        PrivacyAnalytics.setEnabled(app, enabled)
        _uiState.update { it.copy(analyticsEnabled = enabled) }
        if (enabled) viewModelScope.launch(Dispatchers.IO) { PrivacyAnalytics.flushIfDue(app, httpClient) }
    }

    // ── Main app: clipboard ───────────────────────────────────────────────────

    fun onAppForegrounded() {
        if (AirclipIdentity.isPaired) {
            initSync(getApplication())
            if (_uiState.value.syncMode.keepsLanServiceRunning) {
                autoConnect()
                SyncEngine.refreshConnections()
                SyncEngine.markLocalActivity()
                SyncEngine.refreshHistorySync()
            }
        }
        if (!_uiState.value.syncMode.allowsAutomaticCapture) return
        captureCurrentClipboard()
    }

    fun onRefreshClipboard(onComplete: () -> Unit) {
        if (_uiState.value.syncMode.allowsAutomaticCapture) {
            onAppForegrounded()
        } else {
            onCaptureClipboard()
        }
        viewModelScope.launch {
            delay(700)
            onComplete()
        }
    }

    fun onInitialDevicesTabShown() {
        _uiState.update { it.copy(openDevicesOnFirstLaunch = false) }
    }

    fun onCaptureClipboard() {
        if (!_uiState.value.syncMode.allowsManualSend) return
        captureCurrentClipboard()
    }

    private fun captureCurrentClipboard() {
        if (AirclipIdentity.deviceId == null) return
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

        sendClipboardText(text)
    }

    fun onClipboardChanged(text: String) {
        if (!_uiState.value.syncMode.allowsAutomaticCapture) return
        if (AirclipIdentity.deviceId == null) return
        sendClipboardText(text)
    }

    private fun sendClipboardText(text: String) {
        viewModelScope.launch(Dispatchers.IO) {
            SyncEngine.sendClip(text)
        }
    }

    fun onAppearanceSettingChanged(setting: AppAppearanceSetting) {
        Prefs.appearanceSetting = setting
        _uiState.update { it.copy(appearanceSetting = setting) }
    }

    fun onHistoryDepthChanged(index: Int) = runAsync("historyDepth") {
        val safeIndex = index.coerceIn(0, Prefs.historyRetentionDays.lastIndex)
        Prefs.historyDepth = safeIndex
        val days = Prefs.historyRetentionDays[safeIndex]
        val history = ClipHistoryStore.pruneToRetention(getApplication(), days)
        _uiState.update {
            it.copy(historyDepth = safeIndex, clipHistory = history)
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

    fun onDeleteClip(item: ClipItemRecord, onComplete: () -> Unit = {}) = runAsync("deleteClip") {
        SyncEngine.deleteHistoryItem(getApplication(), item)
        _uiState.update { it.copy(clipHistory = it.clipHistory.filterNot { clip -> clip.messageId == item.messageId }) }
        onComplete()
    }

    fun onClearHistory() {
        SyncEngine.clearHistory(getApplication())
        _uiState.update { it.copy(clipHistory = emptyList()) }
    }

    // ── Devices tab ───────────────────────────────────────────────────────────

    fun onRefreshDevices() {
        _uiState.update {
            it.copy(
                pairedDevices = AirclipIdentity.pairedDevices.values.toList(),
                lastManualRefreshAtMs = System.currentTimeMillis(),
            )
        }
        if (AirclipIdentity.isPaired) {
            SyncEngine.reconnect()
            SyncEngine.refreshHistorySync()
        }
    }

    fun onReconnectDevice() {
        if (!AirclipIdentity.isPaired) return
        SyncEngine.reconnect()
    }

    fun onRemoveDevice(deviceId: String) = runAsync("removeDevice") {
        val app = getApplication<Application>()
        AirclipIdentity.removeDevice(app, deviceId)
        _uiState.update { it.copy(pairedDevices = AirclipIdentity.pairedDevices.values.toList()) }
    }

    private suspend fun handleRemovedFromNetwork() {
        val app = getApplication<Application>()
        SyncService.stop(app)
        SyncEngine.disconnect()
        PairingSession.stop()
        keyManager.clearKeypair()
        AirclipIdentity.clearAll(app)
        _uiState.update {
            UiState(
                deviceName = android.os.Build.MODEL,
                syncMode = Prefs.syncMode,
            )
        }
        log("This device was removed from the Airclip space")
    }

    // ── Settings ──────────────────────────────────────────────────────────────

    fun onSyncModeChanged(mode: SyncMode) {
        val app = getApplication<Application>()
        Prefs.syncMode = mode
        _uiState.update {
            it.copy(
                syncMode = mode,
                isConnected = mode.keepsLanServiceRunning && AirclipIdentity.isPaired,
            )
        }

        if (!AirclipIdentity.isPaired) return

        if (mode.keepsLanServiceRunning) {
            SyncService.start(app)
        } else {
            SyncService.stop(app)
        }
    }

    fun onResetAirclip() = runAsync("resetAirclip") {
        val app = getApplication<Application>()
        AirclipIdentity.deviceId?.let { PeerManager.broadcastDeviceRemoval(it) }
        delay(200)
        SyncService.stop(app)
        SyncEngine.disconnect()
        PairingSession.stop()
        keyManager.clearKeypair()
        AirclipIdentity.clearAll(app)
        ClipHistoryStore.clear(app)
        Prefs.clearAll()
        _uiState.update {
            UiState(deviceName = android.os.Build.MODEL)
        }
        log("Airclip reset — all data cleared")
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

    override fun onCleared() {
        PairingSession.stop()
        super.onCleared()
    }
}

internal object SpaceNameSuggestions {
    private val names = listOf(
        "Jelly Comet", "Lucky Orbit", "Fizzy Nova", "Purple Portal", "Candy Compass",
        "Bubble Moon", "Cosmic Marble", "Peachy Planet", "Jolly Meteor", "Magic Rocket",
        "Sunny Nebula", "Bouncy Pixel", "Glitter Galaxy", "Mango Moon", "Tiny Satellite",
        "Sparkle Orbit", "Jelly Star", "Happy Comet", "Fuzzy Planet", "Lucky Meteor",
        "Bubble Nova", "Cosmic Dice", "Peachy Orbit", "Jolly Rocket", "Magic Moon",
        "Sunny Star", "Bouncy Comet", "Glitter Portal", "Mango Meteor", "Tiny Nova",
        "Sparkle Planet", "Jelly Orbit", "Happy Rocket", "Fuzzy Moon", "Lucky Star",
        "Bubble Comet", "Cosmic Compass", "Peachy Nova", "Jolly Planet", "Magic Meteor",
        "Sunny Orbit", "Bouncy Rocket", "Glitter Moon", "Mango Star", "Tiny Comet",
        "Sparkle Nova", "Jelly Planet", "Happy Meteor", "Fuzzy Orbit", "Lucky Moon",
        "Bubble Rocket", "Cosmic Pixel", "Peachy Meteor", "Jolly Star", "Magic Comet",
        "Sunny Planet", "Bouncy Nova", "Glitter Orbit", "Mango Moonbeam", "Tiny Rocket",
        "Sparkle Comet", "Jelly Nova", "Happy Planet", "Fuzzy Meteor", "Lucky Rocket",
        "Bubble Star", "Cosmic Lantern", "Peachy Moon", "Jolly Comet", "Magic Nova",
        "Sunny Rocket", "Bouncy Planet", "Glitter Star", "Mango Orbit", "Tiny Meteor",
        "Sparkle Moon", "Jelly Rocket", "Happy Nova", "Fuzzy Star", "Lucky Planet",
        "Bubble Meteor", "Cosmic Portal", "Peachy Rocket", "Jolly Moon", "Magic Star",
        "Sunny Comet", "Bouncy Orbit", "Glitter Nova", "Mango Planet", "Tiny Moon",
        "Sparkle Rocket", "Jelly Meteor", "Happy Orbit", "Fuzzy Nova", "Lucky Comet",
        "Bubble Planet", "Cosmic Prism", "Peachy Star", "Jolly Orbit", "Magic Moonbeam",
    )

    fun next(excluding: Set<String>): String? = names.filterNot(excluding::contains).randomOrNull()
}
