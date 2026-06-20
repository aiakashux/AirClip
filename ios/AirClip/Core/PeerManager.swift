import Foundation
import Network
import Combine

/// Owns all active peer connections and the trusted device cache.
///
/// - Incoming connections arrive from LanServer → addIncoming(_:)
/// - Outgoing connections are created by connectIfNeeded(to:peerHint:)
/// - After auth both sides call registerPeer(_:), which stores by deviceId
///   and closes any duplicate.
@MainActor
final class PeerManager: ObservableObject {
    static let shared = PeerManager()

    @Published var connectedCount: Int = 0

    private var peers:         [String: PeerConnection] = [:]
    private var pending:       [UUID: PeerConnection]   = [:]
    private var pendingHints:  Set<String>               = []
    private var trustedDevices:[String: DeviceInfo]      = [:]

    private init() {}

    // MARK: - Device cache

    func updateTrustedDevices(_ devices: [DeviceInfo]) {
        trustedDevices = Dictionary(uniqueKeysWithValues: devices.map { ($0.id, $0) })
    }

    func isTrustedDevice(_ deviceId: String) -> Bool {
        trustedDevices[deviceId] != nil
    }

    func publicKey(for deviceId: String) -> String? {
        trustedDevices[deviceId]?.publicKey
    }

    // MARK: - Peer lifecycle

    func addIncoming(_ peer: PeerConnection) {
        pending[peer.id] = peer
    }

    func connectIfNeeded(to endpoint: NWEndpoint, peerHint: String) {
        guard peers[peerHint] == nil else { return }
        guard !pendingHints.contains(peerHint) else { return }
        pendingHints.insert(peerHint)

        let params    = NWParameters.tcp
        let wsOptions = NWProtocolWebSocket.Options()
        wsOptions.autoReplyPing = true
        params.defaultProtocolStack.applicationProtocols.insert(wsOptions, at: 0)

        let conn = NWConnection(to: endpoint, using: params)
        let peer = PeerConnection(connection: conn, isIncoming: false)
        pending[peer.id] = peer
    }

    func registerPeer(_ peer: PeerConnection) {
        guard let deviceId = peer.deviceId else { return }
        pending.removeValue(forKey: peer.id)
        pendingHints.remove(deviceId)

        if let existing = peers[deviceId] {
            if peer.isIncoming {
                existing.close()
                peers[deviceId] = peer
            } else {
                peer.close()
            }
        } else {
            peers[deviceId] = peer
        }
        updateCount()
    }

    func removePeer(id: UUID) {
        if let peer = pending[id] {
            if let hint = peer.deviceId { pendingHints.remove(hint) }
            pending.removeValue(forKey: id)
        }
        if let key = peers.first(where: { $0.value.id == id })?.key {
            peers.removeValue(forKey: key)
        }
        updateCount()
    }

    func disconnectAll() {
        pending.values.forEach { $0.close() }
        peers.values.forEach   { $0.close() }
        pending.removeAll()
        peers.removeAll()
        pendingHints.removeAll()
        updateCount()
    }

    // MARK: - Broadcast

    func broadcast(plaintext: String) {
        let myId = AuthManager.shared.deviceId ?? ""
        for (deviceId, peer) in peers where deviceId != myId {
            guard let pk = peer.publicKey else { continue }
            do {
                let (ct, nonce) = try CryptoManager.shared.encrypt(
                    plaintext: plaintext,
                    recipientPublicKeyBase64: pk
                )
                peer.sendClip(
                    ciphertext: ct.base64EncodedString(),
                    nonce: nonce.base64EncodedString()
                )
            } catch {}
        }
    }

    // MARK: - Private

    private func updateCount() {
        connectedCount = peers.count
        NotificationCenter.default.post(name: .peerCountChanged, object: connectedCount)
    }
}
