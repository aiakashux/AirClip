package com.cliprplus.clipr.crypto

import android.util.Base64
import com.cliprplus.clipr.util.RedactingLogger
import com.goterl.lazysodium.interfaces.Box

/**
 * Per-device X25519 keypair manager.
 *
 * STORAGE: In-memory only in this step.
 * TODO: Migrate private key to Android Keystore (or EncryptedSharedPreferences)
 *       before production. The interface below is designed for that upgrade path —
 *       swap the backing store without changing callers.
 *
 * Key facts (per docs/protocol.md §3.1):
 *   - Private key: never sent to server, never logged.
 *   - Public key: uploaded during device registration.
 */
class KeyManager {

    // TODO: replace with Keystore-backed storage
    private var _publicKey: ByteArray? = null
    private var _privateKey: ByteArray? = null

    val isInitialized: Boolean get() = _publicKey != null

    /**
     * Generate a new X25519 keypair and store it in memory.
     * Call once per device lifecycle; a future step will persist and reload the keypair.
     */
    fun generateKeypair() {
        val pub = ByteArray(Box.PUBLICKEYBYTES)   // 32 bytes
        val priv = ByteArray(Box.SECRETKEYBYTES)  // 32 bytes
        val ok = Sodium.ls.cryptoBoxKeypair(pub, priv)
        check(ok) { "cryptoBoxKeypair failed" }
        _publicKey = pub
        _privateKey = priv
        // Log public key fingerprint only — private key is never logged
        RedactingLogger.logBytes("keypair_public", pub)
        RedactingLogger.info("KeyManager: keypair generated")
    }

    /** Base64 (NO_WRAP) encoded public key — safe to send to server. */
    fun getPublicKeyBase64(): String =
        Base64.encodeToString(
            _publicKey ?: error("KeyManager: keypair not initialised"),
            Base64.NO_WRAP
        )

    /** Raw public key bytes. */
    fun getPublicKeyBytes(): ByteArray =
        _publicKey?.copyOf() ?: error("KeyManager: keypair not initialised")

    /**
     * Raw private key bytes.
     * Callers MUST NOT log, serialise, or expose this value.
     */
    fun getPrivateKeyBytes(): ByteArray =
        _privateKey?.copyOf() ?: error("KeyManager: keypair not initialised")
}
