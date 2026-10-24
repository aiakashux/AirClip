import Foundation
import Sodium
import Security

enum CryptoError: Error, LocalizedError {
    case encryptionFailed
    case decryptionFailed
    case invalidPublicKey
    case keyStorageFailed

    var errorDescription: String? {
        switch self {
        case .encryptionFailed:  return "Encryption failed"
        case .decryptionFailed:  return "Decryption failed"
        case .invalidPublicKey:  return "Invalid public key"
        case .keyStorageFailed: return "Could not access the device identity in Keychain"
        }
    }
}

/// NaCl sealed-box crypto (crypto_box_seal / crypto_box_seal_open via libsodium).
///
/// Compatible with Android's SealedBox.kt and the backend E2E test.
/// Sealed box uses an ephemeral sender keypair — no explicit nonce.
/// We return/accept a sentinel nonce value to keep the wire protocol shape consistent.
///
/// Device keys live in Keychain. Existing preference-backed identities migrate
/// only after a successful write and read-back, preserving paired-device identity.
final class CryptoManager {
    static let shared = CryptoManager()

    private let sodium = Sodium()
    private let udKey  = "airclip.crypto.keypair.v2"   // UserDefaults key
    private var _cached: Box.KeyPair?

    private init() {}

    // MARK: - Key management

    private var keyPair: Box.KeyPair {
        get throws {
            if let cached = _cached { return cached }
            if let stored = try loadFromKeychain() {
                _cached = stored
                return stored
            }
            guard let fresh = sodium.box.keyPair() else { throw CryptoError.encryptionFailed }
            try saveToKeychain(fresh)
            _cached = fresh
            return fresh
        }
    }

    var publicKeyBase64: String {
        get throws { Data(try keyPair.publicKey).base64EncodedString() }
    }

    func clearKeys() {
        let status = SecItemDelete(keychainQuery as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { return }
        _cached = nil
        UserDefaults.standard.removeObject(forKey: udKey)
    }

    // MARK: - Encryption

    /// NaCl sealed box: encrypt plaintext for recipientPublicKey.
    /// Returns (ciphertext, sentinel nonce) — nonce field is protocol padding only.
    func encrypt(plaintext: String, recipientPublicKeyBase64: String) throws -> (ciphertext: Data, nonce: Data) {
        try encrypt(data: Data(plaintext.utf8), recipientPublicKeyBase64: recipientPublicKeyBase64)
    }

    func encrypt(data: Data, recipientPublicKeyBase64: String) throws -> (ciphertext: Data, nonce: Data) {
        guard let recipientRaw = Data(base64Encoded: recipientPublicKeyBase64) else {
            throw CryptoError.invalidPublicKey
        }
        guard let ct = sodium.box.seal(
            message: Bytes(data),
            recipientPublicKey: Bytes(recipientRaw)
        ) else {
            throw CryptoError.encryptionFailed
        }
        let sentinel = Data("sealed-box-no-nonce".utf8)
        return (ciphertext: Data(ct), nonce: sentinel)
    }

    // MARK: - Decryption

    /// NaCl sealed box open. senderPublicKeyBase64 is unused — sealed box is anonymous.
    func decrypt(ciphertextBase64: String, nonceBase64: String, senderPublicKeyBase64: String) throws -> String {
        let plain = try decryptData(ciphertextBase64: ciphertextBase64)
        guard let text = String(data: plain, encoding: .utf8) else { throw CryptoError.decryptionFailed }
        return text
    }

    func decryptData(ciphertextBase64: String) throws -> Data {
        guard let ctData = Data(base64Encoded: ciphertextBase64) else {
            throw CryptoError.decryptionFailed
        }
        let kp = try keyPair
        guard let plain = sodium.box.open(
            anonymousCipherText: Bytes(ctData),
            recipientPublicKey: kp.publicKey,
            recipientSecretKey: kp.secretKey
        ) else {
            throw CryptoError.decryptionFailed
        }
        return Data(plain)
    }

    /// Copy the current key material before dispatching a large history decrypt
    /// away from the main actor. The background job never touches cached state.
    func historyDecryptionKeys() throws -> (publicKey: [UInt8], secretKey: [UInt8]) {
        let kp = try keyPair
        return (kp.publicKey, kp.secretKey)
    }

    static func decryptHistoryData(
        ciphertextBase64: String,
        publicKey: [UInt8],
        secretKey: [UInt8]
    ) throws -> Data {
        guard let ciphertext = Data(base64Encoded: ciphertextBase64),
              let plaintext = Sodium().box.open(
                anonymousCipherText: Bytes(ciphertext),
                recipientPublicKey: publicKey,
                recipientSecretKey: secretKey
              ) else {
            throw CryptoError.decryptionFailed
        }
        return Data(plaintext)
    }

    // MARK: - Keychain persistence (publicKey[32] + secretKey[32])

    private var keychainQuery: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: AppConfig.keychainService,
         kSecAttrAccount as String: udKey]
    }

    private func readKeychainData() throws -> Data? {
        var query = keychainQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data, data.count == 64 else {
            throw CryptoError.keyStorageFailed
        }
        return data
    }

    private func saveToKeychain(_ kp: Box.KeyPair) throws {
        let data = Data(kp.publicKey + kp.secretKey)
        var attributes = keychainQuery
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(attributes as CFDictionary, nil)
        // Do not overwrite another identity if the item already exists.
        guard status == errSecSuccess || status == errSecDuplicateItem,
              try readKeychainData() == data else { throw CryptoError.keyStorageFailed }
    }

    private func loadFromKeychain() throws -> Box.KeyPair? {
        if let data = try readKeychainData() {
            UserDefaults.standard.removeObject(forKey: udKey)
            return Box.KeyPair(publicKey: Bytes(data.prefix(32)), secretKey: Bytes(data.suffix(32)))
        }
        guard let stored = UserDefaults.standard.string(forKey: udKey) else { return nil }
        guard let data = Data(base64Encoded: stored), data.count == 64 else {
            throw CryptoError.keyStorageFailed
        }
        let pair = Box.KeyPair(publicKey: Bytes(data.prefix(32)), secretKey: Bytes(data.suffix(32)))
        try saveToKeychain(pair)
        UserDefaults.standard.removeObject(forKey: udKey)
        return pair
    }
}
