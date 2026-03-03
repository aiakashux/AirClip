package com.cliprplus.clipr.auth

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.firstOrNull

// One DataStore per application — singleton enforced by the delegate.
// TODO: Replace with EncryptedDataStore before production to protect tokens at rest.
private val Context.tokenDataStore: DataStore<Preferences> by preferencesDataStore(name = "cliprplus_tokens")

private val KEY_ACCOUNT_TOKEN  = stringPreferencesKey("account_token")
private val KEY_ACCOUNT_ID     = stringPreferencesKey("account_id")
private val KEY_DEVICE_TOKEN   = stringPreferencesKey("device_token")
private val KEY_DEVICE_ID      = stringPreferencesKey("device_id")
private val KEY_APPROVAL_STATE = stringPreferencesKey("device_approval_state")

/**
 * Token store for AccountToken and DeviceToken.
 *
 * In-memory [@Volatile] fields provide synchronous read access throughout the
 * codebase. Persistence to/from disk is handled by the suspend functions below,
 * which the ViewModel calls on startup, auth events, and logout.
 *
 * DataStore keys:
 *   account_token, account_id, device_token, device_id, device_approval_state
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

    // ── Synchronous in-memory setters (existing call sites unchanged) ──

    fun setAccountAuth(token: String, accId: String) {
        accountToken = token
        accountId    = accId
    }

    fun setDeviceAuth(token: String, devId: String) {
        deviceToken = token
        deviceId    = devId
    }

    /** Clears ONLY device-scoped credentials from memory. Account token is not affected. */
    fun clearDeviceAuth() {
        deviceToken = null
        deviceId    = null
    }

    fun clear() {
        accountToken = null
        deviceToken  = null
        accountId    = null
        deviceId     = null
    }

    // ── DataStore-backed persistence ─────────────────────────────────

    /**
     * Read persisted tokens from DataStore and hydrate in-memory fields.
     * Call once on app launch (before any UI interaction).
     *
     * @return the raw approval-state string (e.g. "Approved", "PendingApproval")
     *         or null if absent. The caller maps this to [DeviceApprovalState].
     */
    suspend fun loadFromDisk(context: Context): String? {
        val prefs  = context.tokenDataStore.data.firstOrNull() ?: return null
        val aToken = prefs[KEY_ACCOUNT_TOKEN]
        val aId    = prefs[KEY_ACCOUNT_ID]
        val dToken = prefs[KEY_DEVICE_TOKEN]
        val dId    = prefs[KEY_DEVICE_ID]
        if (aToken != null && aId != null) setAccountAuth(aToken, aId)
        if (dToken != null && dId != null) setDeviceAuth(dToken, dId)
        return prefs[KEY_APPROVAL_STATE]
    }

    /** Persist account credentials to DataStore and update in-memory fields. */
    suspend fun saveAccount(context: Context, accountId: String, accountToken: String) {
        setAccountAuth(accountToken, accountId)
        context.tokenDataStore.edit { prefs ->
            prefs[KEY_ACCOUNT_TOKEN] = accountToken
            prefs[KEY_ACCOUNT_ID]    = accountId
        }
    }

    /** Persist device credentials to DataStore and update in-memory fields. */
    suspend fun saveDevice(context: Context, deviceId: String, deviceToken: String) {
        setDeviceAuth(deviceToken, deviceId)
        context.tokenDataStore.edit { prefs ->
            prefs[KEY_DEVICE_TOKEN] = deviceToken
            prefs[KEY_DEVICE_ID]    = deviceId
        }
    }

    /**
     * Persist the device approval state string.
     * Value must equal [DeviceApprovalState.name] (e.g. "Approved", "PendingApproval").
     */
    suspend fun saveApprovalState(context: Context, state: String) {
        context.tokenDataStore.edit { prefs ->
            prefs[KEY_APPROVAL_STATE] = state
        }
    }

    /**
     * Clear device credentials from DataStore and in-memory.
     * Account token and account_id are not affected.
     */
    suspend fun clearDeviceAuth(context: Context) {
        clearDeviceAuth()   // in-memory (0-arg overload)
        context.tokenDataStore.edit { prefs ->
            prefs.remove(KEY_DEVICE_TOKEN)
            prefs.remove(KEY_DEVICE_ID)
            prefs.remove(KEY_APPROVAL_STATE)
        }
    }

    /** Clear all persisted credentials from DataStore and in-memory. */
    suspend fun clearAll(context: Context) {
        clear()   // in-memory
        context.tokenDataStore.edit { it.clear() }
    }
}
