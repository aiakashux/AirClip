package com.airclip.airclip.pairing

import android.graphics.Bitmap
import android.graphics.Color
import com.google.gson.Gson
import com.google.zxing.BarcodeFormat
import com.google.zxing.EncodeHintType
import com.google.zxing.qrcode.QRCodeWriter
import kotlinx.coroutines.*
import java.util.concurrent.atomic.AtomicReference

/** Content encoded in the QR code / sent via pair_info. */
data class PairingPayload(
    val airclip_id: String?,       // null for brand-new device that hasn't joined yet
    val device_id: String,
    val device_name: String,
    val public_key: String,     // base64 X25519 public key
    val code: String,           // 8-digit numeric OTP
    val host: String? = null,   // LAN IP of the host — connect directly, no mDNS race
    val ssid: String? = null,   // WiFi SSID of host — shown if joining device isn't on same net
)

/**
 * Manages the ephemeral pairing session on this device.
 *
 * - Generates an 8-digit OTP that refreshes every 60 seconds silently.
 * - Embeds airclip_id + device identity + OTP into a QR-ready JSON string.
 * - Renders the QR as an Android [Bitmap] for display in Compose.
 *
 * Call [start] from the ViewModel when entering the pairing screen.
 * Call [stop] when leaving (e.g., on cancel or success).
 */
object PairingSession {

    private val gson     = Gson()
    private val _current = AtomicReference<PairingPayload?>(null)
    private val scope    = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private var job: Job? = null

    val current: PairingPayload? get() = _current.get()
    val currentCode: String?     get() = _current.get()?.code

    fun start(
        airClipId: String?,
        deviceId: String,
        deviceName: String,
        publicKey: String,
    ) {
        stop()
        refresh(airClipId, deviceId, deviceName, publicKey)
        job = scope.launch {
            while (isActive) {
                delay(60_000L)
                refresh(airClipId, deviceId, deviceName, publicKey)
            }
        }
    }

    fun stop() {
        job?.cancel()
        job = null
    }

    /** Returns true if [code] matches the current OTP (case-insensitive, trimmed). */
    fun verifyCode(code: String): Boolean =
        _current.get()?.code == code.trim()

    /** JSON to embed in QR code. */
    fun toQrString(): String {
        val p = _current.get() ?: return ""
        return gson.toJson(p)
    }

    /**
     * Render a square QR bitmap on the calling thread.
     * Must be called from a background/IO thread (CPU-bound).
     */
    fun generateQrBitmap(size: Int = 512): Bitmap? = runCatching {
        val content = toQrString()
        val hints   = mapOf(EncodeHintType.MARGIN to 1)
        val matrix  = QRCodeWriter().encode(content, BarcodeFormat.QR_CODE, size, size, hints)
        Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888).also { bmp ->
            for (x in 0 until size) for (y in 0 until size) {
                bmp.setPixel(x, y, if (matrix[x, y]) Color.BLACK else Color.WHITE)
            }
        }
    }.getOrNull()

    private fun refresh(airClipId: String?, deviceId: String, deviceName: String, publicKey: String) {
        val code = (0..99_999_999).random().toString().padStart(8, '0')
        _current.set(PairingPayload(airClipId, deviceId, deviceName, publicKey, code))
    }
}
