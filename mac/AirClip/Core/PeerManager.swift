import Foundation
import Network
import Combine

/// Owns all active peer connections.
///
/// Trust model: a peer is trusted if its airclip_id matches ours and its device_id
/// is still in the local paired-device registry.
/// Public keys are exchanged in the auth handshake and stored on the PeerConnection itself.
@MainActor
final class PeerManager: ObservableObject {
    static let shared = PeerManager()

    @Published var connectedCount: Int = 0
    @Published var connectedDeviceIds: Set<String> = []

    // Authenticated peers keyed by their deviceId.
    private(set) var peers: [String: PeerConnection] = [:]
    // Connections not yet authenticated.
    private var pending: [UUID: PeerConnection] = [:]
    // Prevents duplicate outgoing connections while auth is in flight.
    private var pendingHints: Set<String> = []
    private var heartbeatTimer: Timer?

    private init() {}

    // MARK: - Trust

    func isTrusted(airClipId: String, deviceId: String) -> Bool {
        guard let myAirClipId = AirClipIdentity.shared.airClipId else { return false }
        return airClipId == myAirClipId
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

        let device = AirClipIdentity.shared.pairedDevices[deviceId]

        var didRegisterNewPeer = false
        if let existing = peers[deviceId] {
            // Keep incoming (server-side) connection; close duplicate.
            if peer.isIncoming { existing.close(); peers[deviceId] = peer }
            else               { peer.close() }
        } else {
            peers[deviceId] = peer
            didRegisterNewPeer = true
        }
        updateCount()
        if didRegisterNewPeer, let device {
            DeviceNotificationCoordinator.shared.notifyDeviceConnectedOnce(device)
        }
    }

    func disconnectDevice(_ deviceId: String, notifyRemote: Bool = false) {
        pendingHints.remove(deviceId)
        if let peer = peers.removeValue(forKey: deviceId) {
            if notifyRemote {
                peer.sendDeviceRemoved(targetDeviceId: deviceId)
            } else {
                peer.close()
            }
        }
        updateCount()
    }

    func broadcastDeviceRemoval(targetDeviceId: String) {
        for peer in peers.values {
            peer.sendDeviceRemoved(targetDeviceId: targetDeviceId)
        }
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

    // MARK: - Count

    private func updateCount() {
        connectedCount     = peers.count
        connectedDeviceIds = Set(peers.keys)
        updateHeartbeatTimer()
        NotificationCenter.default.post(name: .peerCountChanged, object: connectedCount)
    }

    private func updateHeartbeatTimer() {
        if peers.isEmpty {
            heartbeatTimer?.invalidate()
            heartbeatTimer = nil
            return
        }

        guard heartbeatTimer == nil else { return }
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.sendHeartbeats()
            }
        }
    }

    private func sendHeartbeats() {
        for peer in peers.values {
            peer.sendHeartbeat()
        }
    }

    // MARK: - Broadcast

    func broadcast(packet: ClipboardPacket) {
        let myId = AirClipIdentity.shared.deviceId ?? ""
        for (deviceId, peer) in peers where deviceId != myId {
            guard let pk = peer.publicKey else { continue }
            do {
                let (ct, nonce) = try CryptoManager.shared.encrypt(
                    plaintext: packet.encodedJSONString() ?? packet.text,
                    recipientPublicKeyBase64: pk
                )
                peer.sendClip(
                    ciphertext: ct.base64EncodedString(),
                    nonce: nonce.base64EncodedString()
                )
            } catch {}
        }
    }
}
