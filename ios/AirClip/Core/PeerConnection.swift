import Foundation
import Network

/// A single authenticated WebSocket connection to a LAN peer.
///
/// Lifecycle:
///   Outgoing (client): ready → sendAuth → receive auth_ok → register
///   Incoming (server): ready → wait → receive auth → send auth_ok → register
@MainActor
final class PeerConnection {

    let id = UUID()
    private(set) var deviceId: String?
    private(set) var publicKey: String?
    let isIncoming: Bool

    private let connection: NWConnection

    init(connection: NWConnection, isIncoming: Bool) {
        self.connection = connection
        self.isIncoming = isIncoming
        connection.stateUpdateHandler = { [weak self] state in
            Task { @MainActor [weak self] in self?.handleStateChange(state) }
        }
        connection.start(queue: .main)
        receiveNext()
    }

    // MARK: - State

    private func handleStateChange(_ state: NWConnection.State) {
        switch state {
        case .ready:
            if !isIncoming { sendAuth() }
        case .failed, .cancelled:
            PeerManager.shared.removePeer(id: id)
        default:
            break
        }
    }

    // MARK: - Receive loop

    private func receiveNext() {
        connection.receiveMessage { [weak self] data, _, _, error in
            guard let self else { return }
            if error != nil {
                Task { @MainActor in PeerManager.shared.removePeer(id: self.id) }
                return
            }
            if let data, !data.isEmpty {
                Task { @MainActor in self.handleMessage(data) }
            }
            if error == nil { self.receiveNext() }
        }
    }

    // MARK: - Message dispatch

    private func handleMessage(_ data: Data) {
        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let type = json["type"] as? String
        else { return }

        switch type {
        case "auth":    handleAuth(json)
        case "auth_ok": handleAuthOk(json)
        case "clip":    handleClip(json)
        default:        break
        }
    }

    // MARK: - Handshake (server side)

    private func handleAuth(_ json: [String: Any]) {
        guard isIncoming else { return }
        guard
            let peerId        = json["device_id"]   as? String,
            let peerAccountId = json["account_id"]  as? String,
            let myAccountId   = AuthManager.shared.accountId,
            peerAccountId == myAccountId,
            PeerManager.shared.isTrustedDevice(peerId)
        else {
            close()
            return
        }
        deviceId  = peerId
        publicKey = PeerManager.shared.publicKey(for: peerId)

        guard
            let myId = AuthManager.shared.deviceId,
            let myPk = try? CryptoManager.shared.publicKeyBase64
        else { return }

        sendJSON(["type": "auth_ok", "device_id": myId, "public_key": myPk])
        PeerManager.shared.registerPeer(self)
    }

    // MARK: - Handshake (client side)

    private func handleAuthOk(_ json: [String: Any]) {
        guard !isIncoming else { return }
        guard
            let peerId = json["device_id"]  as? String,
            let peerPk = json["public_key"] as? String
        else { return }
        deviceId  = peerId
        publicKey = PeerManager.shared.publicKey(for: peerId) ?? peerPk
        PeerManager.shared.registerPeer(self)
    }

    // MARK: - Inbound clip

    private func handleClip(_ json: [String: Any]) {
        guard
            let ct     = json["ciphertext"] as? String,
            let nonce  = json["nonce"]      as? String,
            let fromId = deviceId
        else { return }
        Task {
            await SyncEngine.shared.processInboundClip(
                ciphertextB64: ct, nonceB64: nonce, fromDeviceId: fromId
            )
        }
    }

    // MARK: - Send

    private func sendAuth() {
        guard
            let myId      = AuthManager.shared.deviceId,
            let accountId = AuthManager.shared.accountId
        else { return }
        sendJSON(["type": "auth", "device_id": myId, "account_id": accountId])
    }

    func sendClip(ciphertext: String, nonce: String) {
        sendJSON(["type": "clip", "ciphertext": ciphertext, "nonce": nonce])
    }

    private func sendJSON(_ payload: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: payload) else { return }
        let meta    = NWProtocolWebSocket.Metadata(opcode: .text)
        let context = NWConnection.ContentContext(identifier: "airclip-msg", metadata: [meta])
        connection.send(content: data, contentContext: context, isComplete: true, completion: .idempotent)
    }

    func close() {
        connection.cancel()
    }
}
