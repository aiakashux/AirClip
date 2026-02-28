package com.cliprplus.clipr.device

/** Account-level authentication state. */
sealed class AuthState {
    object LoggedOut : AuthState()
    object AccountTokenReady : AuthState()
}

/**
 * Trust/approval state of this device (docs/protocol.md §4, §2.2).
 *   "pending" → PendingApproval
 *   "trusted" → Approved
 *   Revoked: device token rejected by server (WS auth failure or unexpected status).
 */
sealed class DeviceApprovalState {
    object NotRegistered : DeviceApprovalState()
    object PendingApproval : DeviceApprovalState()
    object Approved : DeviceApprovalState()
    object Revoked : DeviceApprovalState()
}

/**
 * State of the device-scoped JWT (docs/protocol.md §3.4).
 * DeviceToken is issued at registration and used exclusively for WebSocket auth.
 */
sealed class TokenState {
    object NoDeviceToken : TokenState()
    object DeviceTokenReady : TokenState()
    object DeviceTokenInvalid : TokenState()
}

/** WebSocket connection state. */
sealed class WsState {
    object Disconnected : WsState()
    object Connecting : WsState()
    object Connected : WsState()
    data class Backoff(val nextRetrySeconds: Int) : WsState()
}
