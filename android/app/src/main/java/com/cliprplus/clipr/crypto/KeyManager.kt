package com.cliprplus.clipr.crypto

import android.app.Application
import android.util.Base64
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKeys
import com.cliprplus.clipr.util.RedactingLogger
import com.goterl.lazysodium.interfaces.Box

/**
 * Per-device X25519 keypair manager.
 *
 * The keypair is persisted to EncryptedSharedPreferences (AES-256-GCM, Android Keystore
 * master key) so it survives process kill. On cold start, call [loadFromDisk] from a
 * background coroutine before the first decrypt attempt.
 *
 * Key facts (per docs/protocol.md §3.1):
 *   - Private key: never sent to server, never logged.
 *   - Public key: uploaded during device registration.
 */
class KeyManager(private val app: Application) {

    private companion object {
        const val PREFS_NAME  = "cliprplus_keypair"
        const val KEY_PUBLIC  = "pub"
        const val KEY_PRIVATE = "priv"
    }

    // Lazy so EncryptedSharedPreferences init (Android Keystore I/O) happens on a
    // background thread the first time it is accessed, never on the main thread.
    // API shape matches security-crypto:1.0.0: create(fileName, masterKeyAlias, context, ...)
    private val encryptedPrefs by lazy {
        val masterKeyAlias = MasterKeys.getOrCreate(MasterKeys.AES256_GCM_SPEC)
        EncryptedSharedPreferences.create(
            PREFS_NAME,
            masterKeyAlias,
            app,
            EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
            EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
        )
    }

    @Volatile private var _publicKey:  ByteArray? = null
    @Volatile private var _privateKey: ByteArray? = null

    val isInitialized: Boolean get() = _publicKey != null

    /**
     * Load a previously-persisted keypair from EncryptedSharedPreferences.
     * No-op if no keypair has been saved yet (first install, or after [clearKeypair]).
     * Call once on app launch from a background coroutine before the first decrypt.
     */
    fun loadFromDisk() {
        val pubB64  = encryptedPrefs.getString(KEY_PUBLIC,  null) ?: return
        val privB64 = encryptedPrefs.getString(KEY_PRIVATE, null) ?: return
        _publicKey  = Base64.decode(pubB64,  Base64.NO_WRAP)
        _privateKey = Base64.decode(privB64, Base64.NO_WRAP)
        RedactingLogger.logBytes("keypair_public_loaded", _publicKey)
        RedactingLogger.info("KeyManager: keypair loaded from disk")
    }

    /**
     * Generate a new X25519 keypair, store in memory, and persist to
     * EncryptedSharedPreferences so it survives process kill.
     */
    fun generateKeypair() {
        val pub  = ByteArray(Box.PUBLICKEYBYTES)   // 32 bytes
        val priv = ByteArray(Box.SECRETKEYBYTES)   // 32 bytes
        val ok = Sodium.ls.cryptoBoxKeypair(pub, priv)
        check(ok) { "cryptoBoxKeypair failed" }
        _publicKey  = pub
        _privateKey = priv
        encryptedPrefs.edit()
            .putString(KEY_PUBLIC,  Base64.encodeToString(pub,  Base64.NO_WRAP))
            .putString(KEY_PRIVATE, Base64.encodeToString(priv, Base64.NO_WRAP))
            .apply()
        // Log public key fingerprint only — private key is never logged
        RedactingLogger.logBytes("keypair_public", pub)
        RedactingLogger.info("KeyManager: keypair generated and persisted")
    }

    /**
     * Clear keypair from memory and EncryptedSharedPreferences.
     * Call on device logout or de-registration so the next registration generates a fresh keypair.
     * Must be called from a background thread (encryptedPrefs init touches Android Keystore).
     */
    fun clearKeypair() {
        _publicKey  = null
        _privateKey = null
        encryptedPrefs.edit().clear().apply()
        RedactingLogger.info("KeyManager: keypair cleared")
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
