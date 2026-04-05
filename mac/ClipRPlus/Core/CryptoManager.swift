import Foundation
import Security
import Sodium

enum CryptoError: Error, LocalizedError {
    case keychainStoreFailed(OSStatus)
    case keychainReadFailed(OSStatus)
    case encryptionFailed
    case decryptionFailed
    case invalidPublicKey

    var errorDescription: String? {
        switch self {
        case .keychainStoreFailed(let s): return "Keychain store failed: \(s)"
        case .keychainReadFailed(let s):  return "Keychain read failed: \(s)"
        case .encryptionFailed:           return "Encryption failed"
        case .decryptionFailed:           return "Decryption failed"
        case .invalidPublicKey:           return "Invalid public key"
        }
    }
}

/// NaCl sealed-box crypto (crypto_box_seal / crypto_box_seal_open via libsodium).
///
/// Compatible with Android's SealedBox.kt and the backend E2E test.
/// Sealed box uses an ephemeral sender keypair — no explicit nonce.
/// We return/accept a sentinel nonce value to keep the wire protocol shape consistent.
final class CryptoManager {
    static let shared = CryptoManager()

    private let sodium = Sodium()
    private let privateKeyAccount = "x25519-keypair-v2"   // v2 = sealed-box scheme
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
            try storeInKeychain(fresh)
            _cached = fresh
            return fresh
        }
    }

    var publicKeyBase64: String {
        get throws { Data(try keyPair.publicKey).base64EncodedString() }
    }

    func clearKeys() {
        _cached = nil
        deleteFromKeychain()
    }

    // MARK: - Encryption

    /// NaCl sealed box: encrypt plaintext for recipientPublicKey.
    /// Returns (ciphertext, sentinel nonce) — nonce field is protocol padding only.
    func encrypt(plaintext: String, recipientPublicKeyBase64: String) throws -> (ciphertext: Data, nonce: Data) {
        guard let recipientRaw = Data(base64Encoded: recipientPublicKeyBase64) else {
            throw CryptoError.invalidPublicKey
        }
        guard let ct = sodium.box.seal(
            message: Bytes(plaintext.utf8),
            recipientPublicKey: Bytes(recipientRaw)
        ) else {
            throw CryptoError.encryptionFailed
        }
        // Sentinel matches Android's SealedBox.NONCE_SENTINEL and the E2E test script.
        let sentinel = Data("sealed-box-no-nonce".utf8)
        return (ciphertext: Data(ct), nonce: sentinel)
    }

    // MARK: - Decryption

    /// NaCl sealed box open. senderPublicKeyBase64 is unused — sealed box is anonymous.
    func decrypt(ciphertextBase64: String, nonceBase64: String, senderPublicKeyBase64: String) throws -> String {
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
        guard let text = String(bytes: plain, encoding: .utf8) else {
            throw CryptoError.decryptionFailed
        }
        return text
    }

    // MARK: - Keychain (stores 64 bytes: publicKey[32] + secretKey[32])

    private func storeInKeychain(_ kp: Box.KeyPair) throws {
        let data = Data(kp.publicKey + kp.secretKey)
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: AppConfig.keychainService,
            kSecAttrAccount as String: privateKeyAccount,
            kSecValueData as String:   data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw CryptoError.keychainStoreFailed(status) }
    }

    private func loadFromKeychain() throws -> Box.KeyPair? {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: AppConfig.keychainService,
            kSecAttrAccount as String: privateKeyAccount,
            kSecReturnData as String:  true,
            kSecMatchLimit as String:  kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = item as? Data, data.count == 64 else {
            // Stale entry from old crypto scheme — clear and regenerate
            deleteFromKeychain()
            return nil
        }
        return Box.KeyPair(
            publicKey: Bytes(data.prefix(32)),
            secretKey: Bytes(data.suffix(32))
        )
    }

    private func deleteFromKeychain() {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: AppConfig.keychainService,
            kSecAttrAccount as String: privateKeyAccount
        ]
        SecItemDelete(query as CFDictionary)
    }
}
