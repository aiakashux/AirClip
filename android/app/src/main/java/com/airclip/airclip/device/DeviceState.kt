package com.airclip.airclip.device

/** Whether this device has been paired into a AirClip. */
sealed class PairingState {
    object NotPaired : PairingState()
    object Paired    : PairingState()
}

// ── Legacy (kept for compatibility during transition) ─────────────────────────

sealed class AuthState {
    object LoggedOut          : AuthState()
    object AccountTokenReady  : AuthState()
}

sealed class DeviceApprovalState {
    object NotRegistered   : DeviceApprovalState()
    object PendingApproval : DeviceApprovalState()
    object Approved        : DeviceApprovalState()
    object Revoked         : DeviceApprovalState()
}

sealed class TokenState {
    object NoDeviceToken      : TokenState()
    object DeviceTokenReady   : TokenState()
    object DeviceTokenInvalid : TokenState()
}
