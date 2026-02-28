package com.cliprplus.clipr.crypto

import android.util.Base64
import com.cliprplus.clipr.util.RedactingLogger
import com.goterl.lazysodium.interfaces.Box

/**
 * NaCl sealed-box (crypto_box_seal / crypto_box_seal_open).
 *
 * Compatible with the Mac client's libsodium sealed-box implementation.
 * A sealed box uses an ephemeral sender keypair — there is no explicit nonce.
 * We send a sentinel nonce value to keep protocol field shapes consistent
 * with docs/protocol.md (which lists a `nonce` field on every payload).
 *
 * SENTINEL: Base64("sealed-box-no-nonce") — matches Mac client behaviour.
 */
object SealedBox {

    /** Sentinel sent in the `nonce` field. Matches Mac client. */
    const val NONCE_SENTINEL = "c2VhbGVkLWJveC1uby1ub25jZQ==" // Base64("sealed-box-no-nonce")

    data class EncryptResult(
        val ciphertextBase64: String,
        val nonce: String = NONCE_SENTINEL
    )

    /**
     * Encrypt [plaintext] for the device identified by [recipientPublicKeyBase64].
     * Returns base64-encoded ciphertext + sentinel nonce.
     *
     * DO NOT pass clipboard plaintext to any logger inside or outside this function.
     */
    fun encryptForRecipient(plaintext: ByteArray, recipientPublicKeyBase64: String): EncryptResult {
        val recipientPubKey = Base64.decode(recipientPublicKeyBase64, Base64.NO_WRAP)
        require(recipientPubKey.size == Box.PUBLICKEYBYTES) {
            "Invalid recipient public key length: ${recipientPubKey.size}"
        }

        // Output ciphertext = plaintext + 48-byte sealed-box overhead
        val ciphertext = ByteArray(plaintext.size + Box.SEALBYTES)
        val result = Sodium.ls.crypto_box_seal(
            ciphertext, plaintext, plaintext.size.toLong(), recipientPubKey
        )
        check(result == 0) { "crypto_box_seal failed (result=$result)" }

        val b64 = Base64.encodeToString(ciphertext, Base64.NO_WRAP)
        RedactingLogger.logCiphertext("sealed_ciphertext_out", b64)  // hash/len only
        return EncryptResult(b64)
    }

    /**
     * Decrypt a sealed-box [ciphertextBase64] using this device's keypair.
     * The nonce field is ignored (sentinel only — sealed box has no explicit nonce).
     *
     * NOTE: Decryption is included for interface completeness; it is used in a later step.
     * DO NOT log the return value.
     */
    fun decryptForSelf(
        ciphertextBase64: String,
        publicKeyBytes: ByteArray,
        privateKeyBytes: ByteArray
    ): ByteArray {
        val ciphertext = Base64.decode(ciphertextBase64, Base64.NO_WRAP)
        require(ciphertext.size > Box.SEALBYTES) {
            "Ciphertext too short to be a valid sealed box"
        }
        val plaintext = ByteArray(ciphertext.size - Box.SEALBYTES)
        val result = Sodium.ls.crypto_box_seal_open(
            plaintext, ciphertext, ciphertext.size.toLong(), publicKeyBytes, privateKeyBytes
        )
        check(result == 0) { "crypto_box_seal_open failed (result=$result) — wrong key or corrupt data" }
        // Never log plaintext
        RedactingLogger.info("SealedBox.decryptForSelf: ok plaintext_len=${plaintext.size}")
        return plaintext
    }
}
