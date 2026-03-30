import Foundation
import Security
import Combine

enum AuthError: Error, LocalizedError {
    case missingToken
    case keychainFailed

    var errorDescription: String? {
        switch self {
        case .missingToken: return "Authentication token missing"
        case .keychainFailed: return "Keychain operation failed"
        }
    }
}

enum DeviceApprovalStatus {
    case approved
    case pendingApproval
}

@MainActor
final class AuthManager: ObservableObject {
    static let shared = AuthManager()

    @Published var isAuthenticated = false
    @Published var isDeviceApproved = false
    @Published var accountEmail: String?
    @Published var deviceId: String?

    private let acctTokenAccount = "account-token"
    private let devTokenAccount = "device-token"

    var accountToken: String? { keychainLoad(account: acctTokenAccount) }
    var deviceToken: String? { keychainLoad(account: devTokenAccount) }

    private init() { restoreState() }

    private func restoreState() {
        if accountToken != nil {
            isAuthenticated = true
            accountEmail = UserDefaults.standard.string(forKey: "accountEmail")
            deviceId = UserDefaults.standard.string(forKey: "deviceId")
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

    func registerDevice(name: String) async throws -> DeviceApprovalStatus {
        let publicKey = try CryptoManager.shared.publicKeyBase64
        let resp = try await APIClient.shared.registerDevice(name: name, publicKey: publicKey)

        UserDefaults.standard.set(resp.deviceId, forKey: "deviceId")
        UserDefaults.standard.set(name, forKey: "deviceName")
        deviceId = resp.deviceId

        if let token = resp.deviceToken {
            try keychainSave(account: devTokenAccount, value: token)
            isDeviceApproved = true
            return .approved
        }
        return .pendingApproval
    }

    /// Returns true if this device has become approved.
    func checkApproval() async throws -> Bool {
        let devices = try await APIClient.shared.listDevices()
        guard let myId = deviceId,
              let me = devices.first(where: { $0.id == myId }),
              me.trustStatus == "approved" else { return false }
        isDeviceApproved = true
        return true
    }

    func signOut() async {
        keychainDelete(account: acctTokenAccount)
        keychainDelete(account: devTokenAccount)
        CryptoManager.shared.clearKeys()
        ["accountEmail", "deviceId", "deviceName", "lastSeenSeq"].forEach {
            UserDefaults.standard.removeObject(forKey: $0)
        }
        accountEmail = nil
        deviceId = nil
        isAuthenticated = false
        isDeviceApproved = false
        SyncEngine.shared.disconnect()
        LocalHistoryStore.shared.clearAll()
    }

    // MARK: - Keychain helpers

    private func keychainSave(account: String, value: String) throws {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: AppConfig.keychainService,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        SecItemDelete(query as CFDictionary)
        guard SecItemAdd(query as CFDictionary, nil) == errSecSuccess else {
            throw AuthError.keychainFailed
        }
    }

    func keychainLoad(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: AppConfig.keychainService,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func keychainDelete(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: AppConfig.keychainService,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}
