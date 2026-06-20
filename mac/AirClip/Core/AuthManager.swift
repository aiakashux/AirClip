import Foundation

// AuthManager is superseded by AirClipIdentity.
// Kept as a thin compatibility shim — all state delegates to AirClipIdentity.

enum AuthError: Error, LocalizedError {
    case keychainFailed
    var errorDescription: String? { "Keychain operation failed" }
}

enum DeviceApprovalStatus { case approved, pendingApproval }

@MainActor
final class AuthManager: ObservableObject {
    static let shared = AuthManager()
    private init() {}

    // Proxied to AirClipIdentity so any remaining call sites compile.
    var isAuthenticated: Bool  { AirClipIdentity.shared.isPaired }
    var isDeviceApproved: Bool { AirClipIdentity.shared.isPaired }
    var deviceId: String?      { AirClipIdentity.shared.deviceId }

    /// Legacy: no longer stores an email — returns nil.
    var accountEmail: String?  { nil }

    func signOut() async {
        AirClipIdentity.shared.clearAll()
        SyncEngine.shared.disconnect()
        LocalHistoryStore.shared.clearAll()
        CryptoManager.shared.clearKeys()
    }
}
