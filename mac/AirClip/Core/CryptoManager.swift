import Foundation
import Sodium

enum CryptoError: Error, LocalizedError {
    case encryptionFailed
    case decryptionFailed
    case invalidPublicKey

    var errorDescription: String? {
        switch self {
        case .encryptionFailed:  return "Encryption failed"
        case .decryptionFailed:  return "Decryption failed"
        case .invalidPublicKey:  return "Invalid public key"
        }
    }
}

/// NaCl sealed-box crypto (crypto_box_seal / crypto_box_seal_open via libsodium).
///
/// Compatible with Android's SealedBox.kt and the backend E2E test.
/// Sealed box uses an ephemeral sender keypair — no explicit nonce.
/// We return/accept a sentinel nonce value to keep the wire protocol shape consistent.
///
/// Key storage: UserDefaults (in the app's sandboxed container).
/// This avoids macOS keychain access dialogs on every debug rebuild while keeping
/// the key isolated to the app's own sandbox.
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
            if let stored = loadFromUserDefaults() {
                _cached = stored
                return stored
            }
            guard let fresh = sodium.box.keyPair() else { throw CryptoError.encryptionFailed }
            saveToUserDefaults(fresh)
            _cached = fresh
            return fresh
        }
    }

    var publicKeyBase64: String {
        get throws { Data(try keyPair.publicKey).base64EncodedString() }
    }

    func clearKeys() {
        _cached = nil
        UserDefaults.standard.removeObject(forKey: udKey)
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

    // MARK: - UserDefaults persistence (64 bytes: publicKey[32] + secretKey[32])

    private func saveToUserDefaults(_ kp: Box.KeyPair) {
        let data = Data(kp.publicKey + kp.secretKey)
        UserDefaults.standard.set(data.base64EncodedString(), forKey: udKey)
    }

    private func loadFromUserDefaults() -> Box.KeyPair? {
        guard let b64  = UserDefaults.standard.string(forKey: udKey),
              let data = Data(base64Encoded: b64),
              data.count == 64 else { return nil }
        return Box.KeyPair(
            publicKey: Bytes(data.prefix(32)),
            secretKey: Bytes(data.suffix(32))
        )
    }
}
