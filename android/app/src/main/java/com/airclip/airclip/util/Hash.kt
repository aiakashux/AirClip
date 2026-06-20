package com.airclip.airclip.util

import java.security.MessageDigest

object Hash {

    fun sha256Bytes(input: ByteArray): ByteArray =
        MessageDigest.getInstance("SHA-256").digest(input)

    fun sha256Hex(input: ByteArray): String =
        sha256Bytes(input).joinToString("") { "%02x".format(it) }

    fun sha256Hex(input: String): String = sha256Hex(input.toByteArray(Charsets.UTF_8))

    /** First 12 hex chars of SHA-256 — safe to log as a fingerprint. */
    fun sha256Short(input: String): String = sha256Hex(input).take(12)

    fun sha256Short(input: ByteArray): String = sha256Hex(input).take(12)
}
