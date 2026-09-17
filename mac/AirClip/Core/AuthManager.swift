import Foundation

// AuthManager is superseded by AirclipIdentity.
// Kept as a thin compatibility shim — all state delegates to AirclipIdentity.

enum AuthError: Error, LocalizedError {
    case keychainFailed
    var errorDescription: String? { "Keychain operation failed" }
}

enum DeviceApprovalStatus { case approved, pendingApproval }

@MainActor
final class AuthManager: ObservableObject {
    static let shared = AuthManager()
    private init() {}

    // Proxied to AirclipIdentity so any remaining call sites compile.
    var isAuthenticated: Bool  { AirclipIdentity.shared.isPaired }
    var isDeviceApproved: Bool { AirclipIdentity.shared.isPaired }
    var deviceId: String?      { AirclipIdentity.shared.deviceId }

    /// Legacy: no longer stores an email — returns nil.
    var accountEmail: String?  { nil }

    func signOut() async {
        AirclipIdentity.shared.clearAll()
        SyncEngine.shared.disconnect()
        LocalHistoryStore.shared.clearAll()
        CryptoManager.shared.clearKeys()
    }
}
