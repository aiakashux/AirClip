package com.airclip.airclip

import android.content.Context
import android.os.Build
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.*
import androidx.datastore.preferences.preferencesDataStore
import com.google.gson.Gson
import com.google.gson.reflect.TypeToken
import com.airclip.airclip.lan.PeerManager
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.firstOrNull
import java.util.UUID

// ── Data model ────────────────────────────────────────────────────────────────

/** A device paired into this AirClip. */
data class PairedDevice(
    val deviceId: String,
    val deviceName: String,
    val publicKey: String,          // base64 X25519 public key
    val platform: String = "",
    val lastSeenMs: Long = 0L,
    val lastActiveMs: Long = 0L,
    val wifiNetwork: String? = null,
)

// ── DataStore singleton ────────────────────────────────────────────────────────

private val Context.airClipIdentityStore: DataStore<Preferences>
    by preferencesDataStore(name = "airclip_identity")

private val KEY_AIRCLIP_ID  = stringPreferencesKey("airclip_id")
private val KEY_DEVICE_ID   = stringPreferencesKey("device_id")
private val KEY_DEVICE_NAME = stringPreferencesKey("device_name")
private val KEY_DEVICES     = stringPreferencesKey("paired_devices_json")
private val KEY_DEVICE_NAMES = stringPreferencesKey("known_device_names_json")
private val KEY_IS_PAIRED   = booleanPreferencesKey("is_paired")

/**
 * Self-sovereign identity store — no server required.
 *
 * airclip_id:   shared UUID across all devices in the same AirClip.
 *            Joining = adopting an existing airclip_id via QR/code pairing.
 * device_id: UUID unique to this device; used as the mDNS service name.
 * pairedDevices: locally-stored registry of trusted devices — built via QR/code pairing.
 *
 * Thread safety: @Volatile in-memory fields + DataStore for persistence.
 * Call [loadFromDisk] once on startup before any reads.
 */
object AirClipIdentity {

    @Volatile var airClipId: String?  = null; private set
    @Volatile var deviceId: String? = null; private set
    @Volatile var deviceName: String = ""; private set
    @Volatile var isPaired: Boolean  = false; private set

    private val _pairedDevices = mutableMapOf<String, PairedDevice>()
    private val _knownDeviceNames = mutableMapOf<String, String>()
    val pairedDevices: Map<String, PairedDevice> get() = _pairedDevices.toMap()
    private val _pairedDevicesFlow = MutableStateFlow<List<PairedDevice>>(emptyList())
    val pairedDevicesFlow: StateFlow<List<PairedDevice>> = _pairedDevicesFlow

    private val gson    = Gson()
    private val mapType = object : TypeToken<Map<String, PairedDevice>>() {}.type
    private val nameMapType = object : TypeToken<Map<String, String>>() {}.type

    // ── Startup ──────────────────────────────────────────────────────────────

    suspend fun loadFromDisk(context: Context) {
        val prefs  = context.airClipIdentityStore.data.firstOrNull() ?: return
        airClipId     = prefs[KEY_AIRCLIP_ID]
        deviceId   = prefs[KEY_DEVICE_ID]
        deviceName = prefs[KEY_DEVICE_NAME] ?: Build.MODEL
        isPaired   = prefs[KEY_IS_PAIRED] ?: false
        _pairedDevices.clear()
        prefs[KEY_DEVICES]?.let { json ->
            runCatching<Map<String, PairedDevice>> { gson.fromJson(json, mapType) }
                .getOrNull()
                ?.let { _pairedDevices.putAll(it) }
        }
        _knownDeviceNames.clear()
        prefs[KEY_DEVICE_NAMES]?.let { json ->
            runCatching<Map<String, String>> { gson.fromJson(json, nameMapType) }
                .getOrNull()
                ?.let { _knownDeviceNames.putAll(it) }
        }
        rememberDeviceNames(_pairedDevices.values)
        publishDevices()
    }

    // ── AirClip creation ─────────────────────────────────────────────────────────

    /**
     * Called on "Create AirClip network". Generates airclip_id + device_id, stores immediately.
     * KeyManager keypair must already be generated before calling this.
     */
    suspend fun createAirClip(context: Context, name: String) {
        airClipId     = UUID.randomUUID().toString()
        deviceId   = UUID.randomUUID().toString()
        deviceName = name
        isPaired   = true
        _pairedDevices.clear()
        _knownDeviceNames.clear()
        persist(context)
    }

    // ── Joining an existing AirClip ──────────────────────────────────────────────

    /**
     * Called when pairing succeeds and we adopt an existing AirClip's identity.
     * [allDevices] = the existing AirClip's current device list from the pairing host.
     */
    suspend fun joinAirClip(
        context: Context,
        incomingAirClipId: String,
        myName: String,
        allDevices: List<PairedDevice>,
    ) {
        if (deviceId == null) deviceId = UUID.randomUUID().toString()
        airClipId     = incomingAirClipId
        deviceName = myName
        isPaired   = true
        _pairedDevices.clear()
        allDevices
            .filter { it.deviceId != deviceId }
            .forEach {
                _pairedDevices[it.deviceId] = it
                rememberDeviceName(it)
            }
        persist(context)
    }

    // ── Device management ────────────────────────────────────────────────────

    /** Add or refresh a paired device record. */
    suspend fun addOrUpdateDevice(context: Context, device: PairedDevice) {
        _pairedDevices[device.deviceId] = device
        rememberDeviceName(device)
        persistDevices(context)
    }

    /** Rename this device and persist the new label immediately. */
    suspend fun renameDevice(context: Context, name: String) {
        deviceName = name
        persist(context)
    }

    /** Record that [deviceId] was seen now (updates lastSeenMs in persisted record). */
    suspend fun touchDevice(context: Context, deviceId: String, wifi: String? = null) {
        val d = _pairedDevices[deviceId] ?: return
        _pairedDevices[deviceId] = d.copy(
            lastSeenMs  = System.currentTimeMillis(),
            wifiNetwork = wifi ?: d.wifiNetwork,
        )
        persistDevices(context)
    }

    suspend fun markDeviceActive(context: Context, deviceId: String, activeAtMs: Long) {
        val d = _pairedDevices[deviceId] ?: return
        _pairedDevices[deviceId] = d.copy(
            lastSeenMs = activeAtMs,
            lastActiveMs = activeAtMs,
        )
        persistDevices(context)
    }

    /** Remove a paired device from the local registry. */
    suspend fun removeDevice(context: Context, deviceId: String) {
        _pairedDevices[deviceId]?.let(::rememberDeviceName)
        _pairedDevices.remove(deviceId)
        persistDevices(context)
        PeerManager.disconnectDevice(deviceId, notifyRemote = true)
    }

    /** Ensure this device has a device_id even before full pairing completes (for QR). */
    fun ensureDeviceId() {
        if (deviceId == null) deviceId = UUID.randomUUID().toString()
    }

    fun setDeviceName(name: String) { deviceName = name }

    fun deviceNameFor(deviceId: String): String? =
        _pairedDevices[deviceId]?.deviceName ?: _knownDeviceNames[deviceId]

    // ── Reset ─────────────────────────────────────────────────────────────────

    suspend fun clearAll(context: Context) {
        airClipId     = null
        deviceId   = null
        deviceName = ""
        isPaired   = false
        _pairedDevices.clear()
        _knownDeviceNames.clear()
        publishDevices()
        context.airClipIdentityStore.edit { it.clear() }
    }

    // ── Persistence ───────────────────────────────────────────────────────────

    private suspend fun persist(context: Context) {
        context.airClipIdentityStore.edit { prefs ->
            prefs[KEY_AIRCLIP_ID]  = airClipId!!
            prefs[KEY_DEVICE_ID]   = deviceId!!
            prefs[KEY_DEVICE_NAME] = deviceName
            prefs[KEY_IS_PAIRED]   = isPaired
            prefs[KEY_DEVICES]     = gson.toJson(_pairedDevices)
            prefs[KEY_DEVICE_NAMES] = gson.toJson(_knownDeviceNames)
        }
        publishDevices()
    }

    private suspend fun persistDevices(context: Context) {
        context.airClipIdentityStore.edit { prefs ->
            prefs[KEY_DEVICES] = gson.toJson(_pairedDevices)
            prefs[KEY_DEVICE_NAMES] = gson.toJson(_knownDeviceNames)
        }
        publishDevices()
    }

    private fun rememberDeviceNames(devices: Collection<PairedDevice>) {
        devices.forEach(::rememberDeviceName)
    }

    private fun rememberDeviceName(device: PairedDevice) {
        if (device.deviceId.isNotBlank() && device.deviceName.isNotBlank()) {
            _knownDeviceNames[device.deviceId] = device.deviceName
        }
    }

    private fun publishDevices() {
        _pairedDevicesFlow.value = _pairedDevices.values.toList()
    }
}
