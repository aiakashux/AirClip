import Foundation
import Network
import AppKit
import SwiftData
import CoreWLAN

/// A single WebSocket connection to a LAN peer.
///
/// Lifecycle:
///   Outgoing (client): ready → sendAuth → receive auth_ok → register
///   Incoming (server): ready → receive auth|pair_request|pair_probe → handle → register or close
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
            if let error {
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

        if deviceId == nil {
            // Unauthenticated — only pairing/auth messages allowed
            switch type {
            case "auth":         handleAuth(json)
            case "auth_ok":      handleAuthOk(json)
            case "pair_request": handlePairRequest(json)
            case "pair_probe":   handlePairProbe(json)
            default:             close()
            }
        } else {
            // Authenticated
            switch type {
            case "clip":          handleClip(json)
            case "history_clip":  handleHistoryClip(json)
            case "heartbeat":     handleHeartbeat(json)
            case "heartbeat_ack": handleHeartbeatAck(json)
            case DeviceRemovalNotice.type:
                handleDeviceRemoved(json)
            default:              break
            }
        }
    }

    // MARK: - Auth handshake (server side)

    private func handleAuth(_ json: [String: Any]) {
        guard isIncoming else { return }
        guard
            let peerId     = json["device_id"]  as? String,
            let peerAirClipId = json["airclip_id"]    as? String,
            let peerPubKey = json["public_key"] as? String
        else { close(); return }

        guard PeerManager.shared.isTrusted(airClipId: peerAirClipId, deviceId: peerId) else { close(); return }

        deviceId  = peerId
        publicKey = peerPubKey

        guard
            let myId = AirClipIdentity.shared.deviceId,
            let myPk = try? CryptoManager.shared.publicKeyBase64
        else { close(); return }

        var reply: [String: Any] = ["type": "auth_ok", "device_id": myId, "public_key": myPk]
        if let ssid = currentSSID() { reply["ssid"] = ssid }
        sendJSON(reply)
        PeerManager.shared.registerPeer(self)
        AirClipIdentity.shared.touchDevice(peerId, wifiNetwork: json["ssid"] as? String)
        pushHistoryToPeer(publicKey: peerPubKey)
    }

    // MARK: - Auth handshake (client side)

    private func handleAuthOk(_ json: [String: Any]) {
        guard !isIncoming else { return }
        guard
            let peerId = json["device_id"]  as? String,
            let peerPk = json["public_key"] as? String
        else { return }
        guard AirClipIdentity.shared.pairedDevices[peerId] != nil else {
            close()
            return
        }
        deviceId  = peerId
        publicKey = peerPk
        PeerManager.shared.registerPeer(self)
        AirClipIdentity.shared.touchDevice(peerId, wifiNetwork: json["ssid"] as? String)
        pushHistoryToPeer(publicKey: peerPk)
    }

    // MARK: - Pairing: pair_request (new device joining this AirClip network)

    private func handlePairRequest(_ json: [String: Any]) {
        guard isIncoming else { return }
        guard
            let code       = json["code"]        as? String,
            let peerId     = json["device_id"]   as? String,
            let peerName   = json["device_name"] as? String,
            let peerPubKey = json["public_key"]  as? String,
            let peerAirClipId = json["airclip_id"]     as? String
        else { close(); return }

        guard PairingSession.shared.verifyCode(code) else {
            sendJSON(
                ["type": "pair_reject", "reason": "invalid_code"],
                closeAfterSending: true
            )
            return
        }

        if let myAirClip = AirClipIdentity.shared.airClipId, myAirClip != peerAirClipId {
            sendJSON(["type": "pair_reject", "reason": "airclip_id_mismatch"])
            close()
            return
        }

        var allDevices = AirClipIdentity.shared.pairedDevices.values.map { d -> [String: String] in
            ["device_id": d.deviceId, "device_name": d.deviceName,
             "public_key": d.publicKey, "platform": d.platform]
        }
        if let myId = AirClipIdentity.shared.deviceId,
           let myKey = try? CryptoManager.shared.publicKeyBase64,
           !allDevices.contains(where: { $0["device_id"] == myId }) {
            allDevices.append([
                "device_id": myId,
                "device_name": AirClipIdentity.shared.deviceName,
                "public_key": myKey,
                "platform": "mac",
            ])
        }

        let newDevice = PairedDevice(
            deviceId: peerId, deviceName: peerName,
            publicKey: peerPubKey, platform: json["platform"] as? String ?? ""
        )
        AirClipIdentity.shared.addOrUpdateDevice(newDevice)
        PairingSession.shared.onPairSuccess?()
        sendJSON(
            ["type": "pair_ok", "airclip_id": peerAirClipId, "all_devices": allDevices],
            closeAfterSending: true
        )
    }

    // MARK: - Pairing: pair_probe (code lookup for manual entry)

    private func handlePairProbe(_ json: [String: Any]) {
        guard isIncoming else { return }
        guard let code = json["code"] as? String else { close(); return }

        guard PairingSession.shared.verifyCode(code) else {
            sendJSON(["type": "pair_reject", "reason": "invalid_code"])
            close()
            return
        }

        guard
            let myId = AirClipIdentity.shared.deviceId,
            let myPk = try? CryptoManager.shared.publicKeyBase64
        else { close(); return }

        var response: [String: Any] = [
            "type":        "pair_info",
            "device_id":   myId,
            "device_name": AirClipIdentity.shared.deviceName,
            "public_key":  myPk,
        ]
        if let airClipId = AirClipIdentity.shared.airClipId {
            response["airclip_id"] = airClipId
        }
        sendJSON(response, closeAfterSending: true)
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

    private func handleHistoryClip(_ json: [String: Any]) {
        guard
            let ct = json["ciphertext"] as? String,
            let nonce = json["nonce"] as? String,
            let msgId = json["msg_id"] as? String,
            let peerId = deviceId
        else { return }

        let timestampMs = (json["ts"] as? String).flatMap(Int64.init)
            ?? json["ts"] as? Int64
            ?? Int64(Date().timeIntervalSince1970 * 1000)
        let fromDeviceId = json["from_device_id"] as? String ?? peerId

        Task {
            await SyncEngine.shared.processHistoryClip(
                ciphertextB64: ct,
                nonceB64: nonce,
                timestampMs: timestampMs,
                messageId: msgId,
                fromDeviceId: fromDeviceId
            )
        }
    }

    // MARK: - Presence heartbeat

    private func handleHeartbeat(_ json: [String: Any]) {
        guard let fromId = deviceId else { return }
        AirClipIdentity.shared.touchDevice(fromId, wifiNetwork: json["ssid"] as? String)
        var reply: [String: Any] = [
            "type": "heartbeat_ack",
            "ts": "\(Int64(Date().timeIntervalSince1970 * 1000))",
        ]
        if let ssid = currentSSID() { reply["ssid"] = ssid }
        sendJSON(reply)
    }

    private func handleHeartbeatAck(_ json: [String: Any]) {
        guard let fromId = deviceId else { return }
        AirClipIdentity.shared.touchDevice(fromId, wifiNetwork: json["ssid"] as? String)
    }

    private func handleDeviceRemoved(_ json: [String: Any]) {
        guard DeviceRemovalNotice.targetsCurrentDevice(
            json,
            currentDeviceId: AirClipIdentity.shared.deviceId
        ) else {
            return
        }
        close()
        AirClipIdentity.shared.clearAll()
    }

    // MARK: - History push

    /// Send up to 20 recent clipboard items to a newly authenticated peer.
    /// Each item is individually encrypted for the peer's public key.
    private func pushHistoryToPeer(publicKey: String) {
        let ctx = LocalHistoryStore.shared.container.mainContext
        let descriptor = FetchDescriptor<ClipboardItem>(
            sortBy: [SortDescriptor(\.receivedAt, order: .reverse)]
        )
        guard let items = try? ctx.fetch(descriptor) else { return }
        for item in items.prefix(20) {
            guard let (ct, nonce) = try? CryptoManager.shared.encrypt(
                plaintext: item.clipboardPacket.encodedJSONString() ?? item.text,
                recipientPublicKeyBase64: publicKey
            ) else { continue }
            let tsMs = Int64(item.receivedAt.timeIntervalSince1970 * 1000)
            sendJSON([
                "type":           "history_clip",
                "ciphertext":     ct.base64EncodedString(),
                "nonce":          nonce.base64EncodedString(),
                "ts":             "\(tsMs)",
                "msg_id":         item.id.uuidString,
                "from_device_id": item.fromDeviceId,
            ])
        }
    }

    // MARK: - Send

    private func sendAuth() {
        guard
            let myId     = AirClipIdentity.shared.deviceId,
            let myAirClipId = AirClipIdentity.shared.airClipId,
            let myPk     = try? CryptoManager.shared.publicKeyBase64
        else { return }

        var payload: [String: Any] = ["type": "auth", "device_id": myId, "airclip_id": myAirClipId, "public_key": myPk]
        if let ssid = currentSSID() { payload["ssid"] = ssid }
        sendJSON(payload)
    }

    private func currentSSID() -> String? {
        CWWiFiClient.shared().interface()?.ssid()
    }

    func sendClip(ciphertext: String, nonce: String) {
        sendJSON(["type": "clip", "ciphertext": ciphertext, "nonce": nonce])
    }

    func sendHeartbeat() {
        var payload: [String: Any] = [
            "type": "heartbeat",
            "ts": "\(Int64(Date().timeIntervalSince1970 * 1000))",
        ]
        if let ssid = currentSSID() { payload["ssid"] = ssid }
        sendJSON(payload)
    }

    func sendDeviceRemoved(targetDeviceId: String) {
        sendJSON(DeviceRemovalNotice.payload(targetDeviceId: targetDeviceId), closeAfterSending: true)
    }

    private func sendJSON(_ payload: [String: Any], closeAfterSending: Bool = false) {
        guard let data = try? JSONSerialization.data(withJSONObject: payload) else { return }
        let meta    = NWProtocolWebSocket.Metadata(opcode: .text)
        let context = NWConnection.ContentContext(identifier: "airclip-msg", metadata: [meta])
        connection.send(
            content: data,
            contentContext: context,
            isComplete: true,
            completion: .contentProcessed { [weak self] _ in
                if closeAfterSending {
                    Task { @MainActor [weak self] in self?.close() }
                }
            }
        )
    }

    func close() { connection.cancel() }
}
