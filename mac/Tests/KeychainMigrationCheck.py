"""Exercise production migration code against fake Keychain APIs; never touch real keys."""
from pathlib import Path
import subprocess
import tempfile

source = (Path(__file__).parents[1] / 'Airclip/Core/CryptoManager.swift').read_text()
methods = source[source.index('    private var keychainQuery:'):source.rfind('\n}')]
methods = methods.replace('private ', '').replace('as CFDictionary', '')
for name in ('SecItemCopyMatching', 'SecItemAdd'):
    methods = methods.replace(name, 'fake' + name)
harness = r'''
import Foundation
import Security
typealias Bytes = [UInt8]
enum Box { struct KeyPair { let publicKey: Bytes; let secretKey: Bytes } }
enum CryptoError: Error { case keyStorageFailed }
enum AppConfig { static let keychainService = "test-only" }
var secure: Data?
var readStatus: OSStatus = errSecSuccess
var writeStatus: OSStatus = errSecSuccess
func fakeSecItemCopyMatching(_ query: [String: Any], _ result: inout CFTypeRef?) -> OSStatus {
    guard readStatus == errSecSuccess else { return readStatus }
    guard let data = secure else { return errSecItemNotFound }
    result = data as NSData
    return errSecSuccess
}
func fakeSecItemAdd(_ query: [String: Any], _ unused: UnsafeMutablePointer<CFTypeRef?>?) -> OSStatus {
    guard writeStatus == errSecSuccess else { return writeStatus }
    if secure != nil { return errSecDuplicateItem }
    secure = query[kSecValueData as String] as? Data
    return errSecSuccess
}
final class TestStore {
    let udKey = "test-key"
    let defaults: UserDefaults
    init(_ defaults: UserDefaults) { self.defaults = defaults }
METHODS
}
let suite = "airclip-migration-test-\(UUID().uuidString)"
let defaults = UserDefaults(suiteName: suite)!
defer { defaults.removePersistentDomain(forName: suite) }
let store = TestStore(defaults)
let original = Data(repeating: 7, count: 64)
defaults.set(original.base64EncodedString(), forKey: "test-key")
writeStatus = errSecAuthFailed
do { _ = try store.loadFromKeychain(); preconditionFailure("Write failure must fail closed") } catch {}
precondition(defaults.string(forKey: "test-key") != nil, "Failed migration must preserve old identity")
writeStatus = errSecSuccess
let migrated = try store.loadFromKeychain()
precondition(Data(migrated!.publicKey + migrated!.secretKey) == original)
precondition(secure == original && defaults.string(forKey: "test-key") == nil)
readStatus = errSecInteractionNotAllowed
do { _ = try store.loadFromKeychain(); preconditionFailure("Locked Keychain must not generate a replacement") } catch {}
readStatus = errSecSuccess
secure = Data(repeating: 0, count: 4)
do { _ = try store.loadFromKeychain(); preconditionFailure("Corrupt Keychain must fail closed") } catch {}
secure = nil
defaults.set("corrupt", forKey: "test-key")
do { _ = try store.loadFromKeychain(); preconditionFailure("Corrupt legacy key must fail closed") } catch {}
precondition(defaults.string(forKey: "test-key") == "corrupt")
print("Keychain migration checks passed (mock backend; no real Keychain access)")
'''.replace('METHODS', methods.replace('UserDefaults.standard', 'defaults'))
with tempfile.TemporaryDirectory(prefix='airclip-key-migration-') as folder:
    path = Path(folder) / 'check.swift'
    path.write_text(harness)
    subprocess.run(['xcrun', 'swift', str(path)], check=True)
