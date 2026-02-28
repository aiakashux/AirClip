package com.cliprplus.clipr.auth

/**
 * In-memory store for AccountToken and DeviceToken.
 *
 * STORAGE: Tokens are held in memory only — not persisted to disk in this step.
 * TODO: Persist using EncryptedSharedPreferences before production use.
 *
 * Token separation rules (per docs/protocol.md §3.4):
 *   - accountToken: used exclusively with REST endpoints
 *   - deviceToken:  used exclusively for WebSocket auth
 *   Never cross-use them.
 */
object TokenStore {
    @Volatile var accountToken: String? = null
        private set

    @Volatile var deviceToken: String? = null
        private set

    @Volatile var accountId: String? = null
        private set

    @Volatile var deviceId: String? = null
        private set

    fun setAccountAuth(token: String, accId: String) {
        accountToken = token
        accountId = accId
    }

    fun setDeviceAuth(token: String, devId: String) {
        deviceToken = token
        deviceId = devId
    }

    /** Clears ONLY device-scoped credentials. Account token is not affected. */
    fun clearDeviceAuth() {
        deviceToken = null
        deviceId = null
    }

    fun clear() {
        accountToken = null
        deviceToken = null
        accountId = null
        deviceId = null
    }
}
