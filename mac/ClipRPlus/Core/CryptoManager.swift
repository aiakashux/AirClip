import Foundation
import CryptoKit
import Security

enum CryptoError: Error, LocalizedError {
    case keychainStoreFailed(OSStatus)
    case keychainReadFailed(OSStatus)
    case encryptionFailed
    case decryptionFailed
    case invalidPublicKey

    var errorDescription: String? {
        switch self {
        case .keychainStoreFailed(let s): return "Keychain store failed: \(s)"
        case .keychainReadFailed(let s): return "Keychain read failed: \(s)"
        case .encryptionFailed: return "Encryption failed"
        case .decryptionFailed: return "Decryption failed"
        case .invalidPublicKey: return "Invalid public key"
        }
    }
}

final class CryptoManager {
    static let shared = CryptoManager()

    private let privateKeyAccount = "x25519-private-key"
    private var _cachedPrivateKey: Curve25519.KeyAgreement.PrivateKey?

    private init() {}

    // MARK: - Key Management

    var privateKey: Curve25519.KeyAgreement.PrivateKey {
        get throws {
            if let cached = _cachedPrivateKey { return cached }
            if let existing = try loadFromKeychain() {
                _cachedPrivateKey = existing
                return existing
            }
            let fresh = Curve25519.KeyAgreement.PrivateKey()
            try storeInKeychain(fresh)
            _cachedPrivateKey = fresh
            return fresh
        }
    }

    var publicKeyBase64: String {
        get throws {
            try privateKey.publicKey.rawRepresentation.base64EncodedString()
        }
    }

    func clearKeys() {
        _cachedPrivateKey = nil
        deleteFromKeychain()
    }

    // MARK: - Encryption

    /// X25519 key agreement → HKDF-SHA256 → AES-GCM encrypt.
    /// Returns (ciphertext: nonce+ciphertext+tag, nonce: 12 bytes).
    func encrypt(plaintext: String, recipientPublicKeyBase64: String) throws -> (ciphertext: Data, nonce: Data) {
        guard let recipientRaw = Data(base64Encoded: recipientPublicKeyBase64) else {
            throw CryptoError.invalidPublicKey
        }
        let recipientPK = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: recipientRaw)
        let myPrivate = try privateKey

        let sharedSecret = try myPrivate.sharedSecretFromKeyAgreement(with: recipientPK)
        let symmetricKey = sharedSecret.hkdfDerivedSymmetricKey(
            using: SHA256.self,
            salt: Data(),
            sharedInfo: Data("clipr-sync".utf8),
            outputByteCount: 32
        )

        let plaintextData = Data(plaintext.utf8)
        let sealedBox = try AES.GCM.seal(plaintextData, using: symmetricKey)
        guard let combined = sealedBox.combined else { throw CryptoError.encryptionFailed }

        // combined = nonce(12) + ciphertext + tag(16)
        let nonceData = Data(sealedBox.nonce)
        let ciphertextAndTag = Data(combined.dropFirst(12))
        return (ciphertext: ciphertextAndTag, nonce: nonceData)
    }

    /// X25519 key agreement → HKDF-SHA256 → AES-GCM decrypt.
    func decrypt(ciphertextBase64: String, nonceBase64: String, senderPublicKeyBase64: String) throws -> String {
        guard
            let ciphertextAndTag = Data(base64Encoded: ciphertextBase64),
            let nonceData = Data(base64Encoded: nonceBase64),
            let senderRaw = Data(base64Encoded: senderPublicKeyBase64)
        else {
            throw CryptoError.decryptionFailed
        }

        let senderPK = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: senderRaw)
        let myPrivate = try privateKey

        let sharedSecret = try myPrivate.sharedSecretFromKeyAgreement(with: senderPK)
        let symmetricKey = sharedSecret.hkdfDerivedSymmetricKey(
            using: SHA256.self,
            salt: Data(),
            sharedInfo: Data("clipr-sync".utf8),
            outputByteCount: 32
        )

        // Reconstruct combined: nonce(12) + ciphertext+tag
        let combined = nonceData + ciphertextAndTag
        let sealedBox = try AES.GCM.SealedBox(combined: combined)
        let plaintextData = try AES.GCM.open(sealedBox, using: symmetricKey)

        guard let plaintext = String(data: plaintextData, encoding: .utf8) else {
            throw CryptoError.decryptionFailed
        }
        return plaintext
    }

    // MARK: - Keychain

    private func storeInKeychain(_ key: Curve25519.KeyAgreement.PrivateKey) throws {
        let data = key.rawRepresentation
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: AppConfig.keychainService,
            kSecAttrAccount as String: privateKeyAccount,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw CryptoError.keychainStoreFailed(status) }
    }

    private func loadFromKeychain() throws -> Curve25519.KeyAgreement.PrivateKey? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: AppConfig.keychainService,
            kSecAttrAccount as String: privateKeyAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw CryptoError.keychainReadFailed(status) }
        guard let data = item as? Data else { return nil }
        return try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: data)
    }

    private func deleteFromKeychain() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: AppConfig.keychainService,
            kSecAttrAccount as String: privateKeyAccount
        ]
        SecItemDelete(query as CFDictionary)
    }
}
