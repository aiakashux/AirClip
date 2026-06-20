import Foundation
import Security
import Combine

enum AuthError: Error, LocalizedError {
    case missingToken
    case keychainFailed

    var errorDescription: String? {
        switch self {
        case .missingToken:  return "Authentication token missing"
        case .keychainFailed: return "Keychain operation failed"
        }
    }
}

@MainActor
final class AuthManager: ObservableObject {
    static let shared = AuthManager()

    @Published var isAuthenticated  = false
    @Published var isDeviceApproved = false
    @Published var accountEmail: String?
    @Published var deviceId: String?

    private let acctTokenAccount = "account-token"
    private let devTokenAccount  = "device-token"

    var accountToken: String? { keychainLoad(account: acctTokenAccount) }
    var deviceToken:  String? { keychainLoad(account: devTokenAccount) }

    /// Account ID decoded from the account JWT's `sub` claim.
    /// Used by PeerConnection to verify incoming peers are on the same account.
    var accountId: String? {
        guard let token = accountToken else { return nil }
        return decodeJWTSub(token)
    }

    private func decodeJWTSub(_ token: String) -> String? {
        let parts = token.split(separator: ".")
        guard parts.count == 3 else { return nil }
        var b64 = String(parts[1])
        let rem = b64.count % 4
        if rem > 0 { b64 += String(repeating: "=", count: 4 - rem) }
        guard
            let data = Data(base64Encoded: b64),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        return json["sub"] as? String
    }

    private init() { restoreState() }

    private func restoreState() {
        if accountToken != nil {
            isAuthenticated = true
            accountEmail    = UserDefaults.standard.string(forKey: "accountEmail")
            deviceId        = UserDefaults.standard.string(forKey: "deviceId")
            isDeviceApproved = deviceToken != nil
        }
    }

    // MARK: - Auth flows

    func register(email: String, password: String) async throws {
        let resp = try await APIClient.shared.register(email: email, password: password)
        try keychainSave(account: acctTokenAccount, value: resp.accountToken)
        accountEmail = email
        UserDefaults.standard.set(email, forKey: "accountEmail")
        isAuthenticated = true
    }

    func login(email: String, password: String) async throws {
        let resp = try await APIClient.shared.login(email: email, password: password)
        try keychainSave(account: acctTokenAccount, value: resp.accountToken)
        accountEmail = email
        UserDefaults.standard.set(email, forKey: "accountEmail")
        isAuthenticated = true
    }

    func registerDevice(name: String) async throws {
        let publicKey = try CryptoManager.shared.publicKeyBase64
        let resp      = try await APIClient.shared.registerDevice(name: name, publicKey: publicKey)

        UserDefaults.standard.set(resp.deviceId, forKey: "deviceId")
        UserDefaults.standard.set(name,          forKey: "deviceName")
        deviceId = resp.deviceId

        if let token = resp.deviceToken {
            try keychainSave(account: devTokenAccount, value: token)
            isDeviceApproved = true
        }
    }

    func signOut() async {
        keychainDelete(account: acctTokenAccount)
        keychainDelete(account: devTokenAccount)
        CryptoManager.shared.clearKeys()
        ["accountEmail", "deviceId", "deviceName"].forEach {
            UserDefaults.standard.removeObject(forKey: $0)
        }
        accountEmail     = nil
        deviceId         = nil
        isAuthenticated  = false
        isDeviceApproved = false
        SyncEngine.shared.disconnect()
        LocalHistoryStore.shared.clearAll()
        WidgetSharedState.clear()
    }

    // MARK: - Keychain helpers

    private func keychainSave(account: String, value: String) throws {
        let data  = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: AppConfig.keychainService,
            kSecAttrAccount as String: account,
            kSecValueData as String:   data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        SecItemDelete(query as CFDictionary)
        guard SecItemAdd(query as CFDictionary, nil) == errSecSuccess else {
            throw AuthError.keychainFailed
        }
    }

    func keychainLoad(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: AppConfig.keychainService,
            kSecAttrAccount as String: account,
            kSecReturnData as String:  true,
            kSecMatchLimit as String:  kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func keychainDelete(account: String) {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: AppConfig.keychainService,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}
