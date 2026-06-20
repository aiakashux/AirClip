package com.airclip.airclip.crypto

import com.goterl.lazysodium.LazySodiumAndroid
import com.goterl.lazysodium.SodiumAndroid

/**
 * Shared singleton for the libsodium JNA instance.
 * Initialised lazily on first access; the native library is loaded once per process.
 */
internal object Sodium {
    val ls: LazySodiumAndroid by lazy {
        LazySodiumAndroid(SodiumAndroid())
    }
}
