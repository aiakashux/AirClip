"""Exercise the production auth handler without changing the installed app's identity."""
from pathlib import Path
import subprocess
import tempfile

source = (Path(__file__).parents[1] / "Airclip/Core/PeerConnection.swift").read_text()
start = source.index("    private func handleAuth(")
end = source.index("    // MARK: - Auth handshake (client side)", start)
handler = source[start:end].replace("private func handleAuth", "func handleAuth")
client_start = source.index("    private func handleAuthOk(")
client_end = source.index("    // MARK: - Pairing: pair_request", client_start)
handler += source[client_start:client_end].replace("private func handleAuthOk", "func handleAuthOk")
harness = r'''
import Foundation
struct PairedDevice {
    let deviceId: String
    let deviceName: String
    let publicKey: String
    let platform: String
    var wifiNetwork: String? = nil
}
final class AirclipIdentity {
    static let shared = AirclipIdentity()
    var isPaired = false
    var deviceName = "Mac"
    var deviceId: String? = "mac"
    var pairedDevices: [String: PairedDevice] = ["phone": PairedDevice(deviceId: "phone", deviceName: "Phone", publicKey: "paired-key", platform: "android")]
    var joins = 0
    func joinAirclip(airClipId: String, myName: String, spaceName: String?, allDevices: [PairedDevice]) { joins += 1 }
    func addOrUpdateDevice(_ device: PairedDevice) {}
    func touchDevice(_ id: String, wifiNetwork: String?) {}
}
final class PairingSession {
    static let shared = PairingSession()
    var currentCode: String? = "123456"
}
final class CryptoManager {
    static let shared = CryptoManager()
    var publicKeyBase64: String { get throws { "test-key" } }
}
final class PeerManager {
    static let shared = PeerManager()
    var trusted = false
    func isTrusted(airClipId: String, deviceId: String) -> Bool { trusted }
    func registerPeer(_ peer: PeerConnection) {}
}
final class PeerConnection {
    var isIncoming = true
    var deviceId: String?
    var publicKey: String?
    var deviceName: String?
    var platform: String?
    var wifiNetwork: String?
    var closed = false
    var replied = false
    func close() { closed = true }
    func sendJSON(_ json: [String: Any]) { replied = true }
    func currentSSID() -> String? { nil }
    func pushHistoryMutationsToPeer() {}
    func pushHistoryToPeer(publicKey: String) {}
HANDLER
}
for pairing in [false, true] {
    for trusted in [false, true] {
        PairingSession.shared.currentCode = pairing ? "123456" : nil
        PeerManager.shared.trusted = trusted
        for key in ["paired-key", "attacker-key"] {
        let accepted = trusted && key == "paired-key"
        let peer = PeerConnection()
        peer.handleAuth(["device_id": "phone", "airclip_id": "previous-space", "public_key": key])
        precondition(peer.closed == !accepted, "Untrusted auth must be rejected even while pairing")
        precondition(peer.replied == accepted)
        precondition(AirclipIdentity.shared.joins == 0, "Ordinary auth must never join a space")
        }
    }
}
for key in ["paired-key", "attacker-key", ""] {
    let peer = PeerConnection()
    peer.isIncoming = false
    peer.handleAuthOk(["device_id": "phone", "public_key": key])
    precondition(peer.closed == (key != "paired-key"), "Outgoing auth must reject substituted keys")
}
print("Peer auth checks passed")
'''.replace("HANDLER", handler)
with tempfile.TemporaryDirectory(prefix="airclip-auth-check-") as folder:
    swift = Path(folder) / "check.swift"
    swift.write_text(harness)
    binary = Path(folder) / "check"
    subprocess.run(["swiftc", str(swift), "-o", str(binary)], check=True)
    subprocess.run([str(binary)], check=True)
