package com.airclip.airclip.pairing

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import com.google.gson.Gson
import com.google.zxing.EncodeHintType
import com.google.zxing.qrcode.decoder.ErrorCorrectionLevel
import com.google.zxing.qrcode.encoder.Encoder
import kotlinx.coroutines.*
import java.util.concurrent.atomic.AtomicReference
import java.security.SecureRandom

/** Content encoded in the QR code / sent via pair_info. */
data class PairingPayload(
    val airclip_id: String?,       // null for brand-new device that hasn't joined yet
    val device_id: String,
    val device_name: String,
    val space_name: String? = null,
    val public_key: String,     // base64 X25519 public key
    val code: String,           // 6-digit numeric OTP
    val host: String? = null,   // LAN IP of the host — connect directly, no mDNS race
    val ssid: String? = null,   // WiFi SSID of host — shown if joining device isn't on same net
)

/**
 * Manages the ephemeral pairing session on this device.
 *
 * - Generates a 6-digit OTP that refreshes every 30 seconds silently.
 * - Embeds airclip_id + device identity + OTP into a QR-ready JSON string.
 * - Renders the QR as an Android [Bitmap] for display in Compose.
 *
 * Call [start] from the ViewModel when entering the pairing screen.
 * Call [stop] when leaving (e.g., on cancel or success).
 */
object PairingSession {

    const val CODE_LIFETIME_MS = 30_000L
    const val PREVIOUS_CODE_GRACE_MS = 30_000L

    private data class PreviousCode(val value: String, val validUntilMs: Long)

    private val random = SecureRandom()
    private val gson     = Gson()
    private val _current = AtomicReference<PairingPayload?>(null)
    private val _previous = AtomicReference<PreviousCode?>(null)
    private val scope    = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private var job: Job? = null
    private var onPayloadChanged: ((PairingPayload) -> Unit)? = null

    val current: PairingPayload? get() = _current.get()
    val currentCode: String?     get() = _current.get()?.code

    fun start(
        airClipId: String?,
        deviceId: String,
        deviceName: String,
        spaceName: String,
        publicKey: String,
        onPayloadChanged: (PairingPayload) -> Unit = {},
    ) {
        stop()
        this.onPayloadChanged = onPayloadChanged
        refresh(airClipId, deviceId, deviceName, spaceName, publicKey)
        job = scope.launch {
            while (isActive) {
                delay(CODE_LIFETIME_MS)
                refresh(airClipId, deviceId, deviceName, spaceName, publicKey)
            }
        }
    }

    fun stop() {
        job?.cancel()
        job = null
        _current.set(null)
        _previous.set(null)
        onPayloadChanged = null
    }

    fun refreshNow() {
        val current = _current.get() ?: return
        refresh(current.airclip_id, current.device_id, current.device_name, current.space_name.orEmpty(), current.public_key)
    }

    /** Returns true for the current OTP or the immediately previous OTP during its grace window. */
    fun verifyCode(code: String): Boolean {
        val normalized = PairingCode.normalize(code)
        if (_current.get()?.code == normalized) return true
        val previous = _previous.get() ?: return false
        return previous.value == normalized && System.currentTimeMillis() <= previous.validUntilMs
    }

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
        val matrix = Encoder.encode(
            content,
            ErrorCorrectionLevel.L,
            mapOf(EncodeHintType.CHARACTER_SET to "UTF-8"),
        ).matrix
        val quietZone = 4
        val moduleSize = size.toFloat() / (matrix.width + quietZone * 2)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.BLACK }

        Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888).also { bitmap ->
            val canvas = Canvas(bitmap)
            canvas.drawColor(Color.WHITE)
            for (x in 0 until matrix.width) for (y in 0 until matrix.height) {
                if (matrix[x, y].toInt() != 1) continue
                val left = (x + quietZone) * moduleSize
                val top = (y + quietZone) * moduleSize
                val rect = RectF(left, top, left + moduleSize, top + moduleSize)
                val isFinder =
                    (x < 7 && y < 7) ||
                    (x >= matrix.width - 7 && y < 7) ||
                    (x < 7 && y >= matrix.height - 7)
                val radius = if (isFinder) 0f else moduleSize * 0.45f
                canvas.drawRoundRect(rect, radius, radius, paint)
            }
        }
    }.getOrNull()

    private fun refresh(airClipId: String?, deviceId: String, deviceName: String, spaceName: String, publicKey: String) {
        _current.get()?.code?.let {
            _previous.set(PreviousCode(it, System.currentTimeMillis() + PREVIOUS_CODE_GRACE_MS))
        }
        val code = random.nextInt(1_000_000).toString().padStart(PairingCode.LENGTH, '0')
        val payload = PairingPayload(airClipId, deviceId, deviceName, spaceName, publicKey, code)
        _current.set(payload)
        onPayloadChanged?.invoke(payload)
    }
}
