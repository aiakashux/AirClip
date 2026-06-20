package com.airclip.airclip.util

import android.util.Log

/**
 * Safe logger: NEVER logs tokens, private keys, ciphertext blobs, or clipboard plaintext.
 * Only logs hashes (12 hex chars) and byte lengths.
 *
 * All callers must route through this class — do not use Log.* directly for sensitive values.
 */
object RedactingLogger {
    private const val TAG = "AirClip"

    fun info(msg: String) = Log.i(TAG, msg)
    fun warn(msg: String) = Log.w(TAG, msg)
    fun error(msg: String, t: Throwable? = null) {
        if (t != null) Log.e(TAG, msg, t) else Log.e(TAG, msg)
    }

    /** Log a token reference — shows only length + hash fingerprint. */
    fun logToken(label: String, token: String?) {
        if (token == null) {
            Log.i(TAG, "$label: null")
        } else {
            Log.i(TAG, "$label: [len=${token.length} hash=${Hash.sha256Short(token)}]")
        }
    }

    /** Log raw bytes — shows only length + hash fingerprint. */
    fun logBytes(label: String, bytes: ByteArray?) {
        if (bytes == null) {
            Log.i(TAG, "$label: null")
        } else {
            Log.i(TAG, "$label: [len=${bytes.size} hash=${Hash.sha256Short(bytes)}]")
        }
    }

    /** Log a base64-encoded ciphertext — shows only base64 length + hash fingerprint. */
    fun logCiphertext(label: String, b64: String?) {
        if (b64 == null) {
            Log.i(TAG, "$label: null")
        } else {
            Log.i(TAG, "$label: [b64_len=${b64.length} hash=${Hash.sha256Short(b64)}]")
        }
    }
}
