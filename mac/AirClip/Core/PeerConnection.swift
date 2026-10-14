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
    private(set) var deviceName: String?
    private(set) var platform: String?
    private(set) var wifiNetwork: String?
    let isIncoming: Bool

    private let connection: NWConnection
    private var isClosed = false

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
        case .waiting, .failed, .cancelled:
            close()
        default:
            break
        }
    }

    // MARK: - Receive loop

    private func receiveNext() {
        guard !isClosed else { return }
        connection.receiveMessage { [weak self] data, context, _, error in
            guard let self else { return }
            let opcode = (context?.protocolMetadata(
                definition: NWProtocolWebSocket.definition
            ) as? NWProtocolWebSocket.Metadata)?.opcode
            if error != nil || opcode == .close {
                Task { @MainActor in self.close() }
                return
            }
            if let data, !data.isEmpty {
                Task { @MainActor in self.handleMessage(data) }
            }
            Task { @MainActor in self.receiveNext() }
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
            case "clip", "file_clip": handleClip(json)
            case "history_clip", "history_file_clip": handleHistoryClip(json)
            case "history_delete": handleHistoryDelete(json)
            case "history_clear":  handleHistoryClear(json)
            case "history_request": handleHistoryRequest()
            case "file_request": SyncEngine.shared.handleFileRequest(json, peer: self)
            case "file_chunk": SyncEngine.shared.handleFileChunk(json, peer: self)
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
            let peerAirclipId = json["airclip_id"]    as? String,
            let peerPubKey = json["public_key"] as? String
        else { close(); return }

        guard PeerManager.shared.isTrusted(airClipId: peerAirclipId, deviceId: peerId) else {
            close()
            return
        }

        deviceId  = peerId
        publicKey = peerPubKey
        deviceName = json["device_name"] as? String
        platform = json["platform"] as? String
        wifiNetwork = json["ssid"] as? String
        let existingDevice = AirclipIdentity.shared.pairedDevices[peerId]
        AirclipIdentity.shared.addOrUpdateDevice(
            PairedDevice(
                deviceId: peerId,
                deviceName: deviceName?.isEmpty == false ? deviceName! : (existingDevice?.deviceName ?? peerId),
                publicKey: peerPubKey,
                platform: platform?.isEmpty == false ? platform! : (existingDevice?.platform ?? ""),
                wifiNetwork: wifiNetwork ?? existingDevice?.wifiNetwork
            )
        )

        guard
            let myId = AirclipIdentity.shared.deviceId,
            let myPk = try? CryptoManager.shared.publicKeyBase64
        else { close(); return }

        var reply: [String: Any] = [
            "type": "auth_ok",
            "device_id": myId,
            "public_key": myPk,
            "device_name": AirclipIdentity.shared.deviceName,
            "platform": "mac",
        ]
        if let ssid = currentSSID() { reply["ssid"] = ssid }
        sendJSON(reply)
        PeerManager.shared.registerPeer(self)
        AirclipIdentity.shared.touchDevice(peerId, wifiNetwork: json["ssid"] as? String)
        pushHistoryMutationsToPeer()
        pushHistoryToPeer(publicKey: peerPubKey)
    }

    // MARK: - Auth handshake (client side)

    private func handleAuthOk(_ json: [String: Any]) {
        guard !isIncoming else { return }
        guard
            let peerId = json["device_id"]  as? String,
            let peerPk = json["public_key"] as? String,
            AirclipIdentity.shared.pairedDevices[peerId] != nil
        else { close(); return }
        deviceId  = peerId
        publicKey = peerPk
        deviceName = json["device_name"] as? String
        platform = json["platform"] as? String
        wifiNetwork = json["ssid"] as? String
        let existingDevice = AirclipIdentity.shared.pairedDevices[peerId]
        AirclipIdentity.shared.addOrUpdateDevice(
            PairedDevice(
                deviceId: peerId,
                deviceName: deviceName?.isEmpty == false ? deviceName! : (existingDevice?.deviceName ?? peerId),
                publicKey: peerPk,
                platform: platform?.isEmpty == false ? platform! : (existingDevice?.platform ?? ""),
                wifiNetwork: wifiNetwork ?? existingDevice?.wifiNetwork
            )
        )
        PeerManager.shared.registerPeer(self)
        AirclipIdentity.shared.touchDevice(peerId, wifiNetwork: json["ssid"] as? String)
        pushHistoryMutationsToPeer()
        pushHistoryToPeer(publicKey: peerPk)
    }

    // MARK: - Pairing: pair_request (new device joining this Airclip space)

    private func handlePairRequest(_ json: [String: Any]) {
        guard isIncoming else { return }
        guard
            let code       = json["code"]        as? String,
            let peerId     = json["device_id"]   as? String,
            let peerName   = json["device_name"] as? String,
            let peerPubKey = json["public_key"]  as? String,
            let peerAirclipId = json["airclip_id"]     as? String
        else { close(); return }

        guard PairingSession.shared.verifyCode(code) else {
            sendJSON(
                ["type": "pair_reject", "reason": "invalid_code"],
                closeAfterSending: true
            )
            return
        }

        if let myAirclip = AirclipIdentity.shared.airClipId, myAirclip != peerAirclipId {
            sendJSON(["type": "pair_reject", "reason": "airclip_id_mismatch"])
            close()
            return
        }

        var allDevices = AirclipIdentity.shared.pairedDevices.values
            .filter { $0.deviceId != peerId }
            .map { d -> [String: String] in
            ["device_id": d.deviceId, "device_name": d.deviceName,
             "public_key": d.publicKey, "platform": d.platform]
        }
        if let myId = AirclipIdentity.shared.deviceId,
           let myKey = try? CryptoManager.shared.publicKeyBase64,
           !allDevices.contains(where: { $0["device_id"] == myId }) {
            allDevices.append([
                "device_id": myId,
                "device_name": AirclipIdentity.shared.deviceName,
                "public_key": myKey,
                "platform": "mac",
            ])
        }

        let newDevice = PairedDevice(
            deviceId: peerId, deviceName: peerName,
            publicKey: peerPubKey, platform: json["platform"] as? String ?? ""
        )
        if AirclipIdentity.shared.airClipId == nil {
            AirclipIdentity.shared.joinAirclip(
                airClipId: peerAirclipId,
                myName: AirclipIdentity.shared.deviceName,
                spaceName: json["space_name"] as? String,
                allDevices: [newDevice]
            )
        } else {
            AirclipIdentity.shared.addOrUpdateDevice(newDevice)
        }
        PrivacyAnalytics.shared.record(.pairingSuccess)
        PairingSession.shared.onPairSuccess?()
        sendJSON(
            ["type": "pair_ok", "airclip_id": peerAirclipId, "space_name": AirclipIdentity.shared.spaceName, "all_devices": allDevices],
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
            let myId = AirclipIdentity.shared.deviceId,
            let myPk = try? CryptoManager.shared.publicKeyBase64
        else { close(); return }

        var response: [String: Any] = [
            "type":        "pair_info",
            "device_id":   myId,
            "device_name": AirclipIdentity.shared.deviceName,
            "public_key":  myPk,
        ]
        if let airClipId = AirclipIdentity.shared.airClipId {
            response["airclip_id"] = airClipId
        }
        response["space_name"] = AirclipIdentity.shared.spaceName
        sendJSON(response, closeAfterSending: true)
    }

    // MARK: - Inbound clip

    private func handleClip(_ json: [String: Any]) {
        guard
            let ct     = json["ciphertext"] as? String,
            let nonce  = json["nonce"]      as? String,
            let fromId = deviceId
        else { return }
        let timestampMs = (json["ts"] as? String).flatMap(Int64.init)
            ?? json["ts"] as? Int64
            ?? Int64(Date().timeIntervalSince1970 * 1000)
        let messageId = json["msg_id"] as? String ?? UUID().uuidString
        let sourceDeviceId = json["from_device_id"] as? String ?? fromId
        Task {
            await SyncEngine.shared.processInboundClip(
                ciphertextB64: ct,
                nonceB64: nonce,
                fromDeviceId: sourceDeviceId,
                timestampMs: timestampMs,
                messageId: messageId
            )
        }
    }

    private func handleHistoryDelete(_ json: [String: Any]) {
        let messageId = json["msg_id"] as? String ?? "legacy"
        let fromDeviceId = json["from_device_id"] as? String ?? deviceId ?? "unknown"
        let timestampMs = (json["ts"] as? String).flatMap(Int64.init)
            ?? json["ts"] as? Int64
            ?? 0
        SyncEngine.shared.applyHistoryDelete(
            messageId: messageId,
            fromDeviceId: fromDeviceId,
            timestampMs: timestampMs
        )
    }

    private func handleHistoryClear(_ json: [String: Any]) {
        let throughMs = (json["through_ms"] as? String).flatMap(Int64.init)
            ?? json["through_ms"] as? Int64
        guard let throughMs else { return }
        SyncEngine.shared.applyHistoryClear(throughMs: throughMs)
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
        AirclipIdentity.shared.touchDevice(fromId, wifiNetwork: json["ssid"] as? String)
        var reply: [String: Any] = [
            "type": "heartbeat_ack",
            "ts": "\(Int64(Date().timeIntervalSince1970 * 1000))",
        ]
        if let ssid = currentSSID() { reply["ssid"] = ssid }
        sendJSON(reply)
    }

    private func handleHeartbeatAck(_ json: [String: Any]) {
        guard let fromId = deviceId else { return }
        AirclipIdentity.shared.touchDevice(fromId, wifiNetwork: json["ssid"] as? String)
    }

    private func handleDeviceRemoved(_ json: [String: Any]) {
        guard DeviceRemovalNotice.targetsCurrentDevice(
            json,
            currentDeviceId: AirclipIdentity.shared.deviceId
        ) else {
            return
        }
        close()
        AirclipIdentity.shared.clearAll()
    }

    // MARK: - History push

    /// Send the locally retained clipboard history to an authenticated peer.
    /// Each item is individually encrypted for the peer's public key.
    private func pushHistoryToPeer(publicKey: String) {
        let ctx = LocalHistoryStore.shared.container.mainContext
        let descriptor = FetchDescriptor<ClipboardItem>(
            sortBy: [SortDescriptor(\.receivedAt, order: .reverse)]
        )
        guard let items = try? ctx.fetch(descriptor) else { return }
        for item in items.prefix(LocalHistoryStore.maxItems) {
            guard let (ct, nonce) = try? CryptoManager.shared.encrypt(
                plaintext: item.clipboardPacket.encodedJSONString() ?? item.text,
                recipientPublicKeyBase64: publicKey
            ) else { continue }
            let tsMs = Int64(item.receivedAt.timeIntervalSince1970 * 1000)
            sendJSON([
                "type":           item.clipType == .file ? "history_file_clip" : "history_clip",
                "ciphertext":     ct.base64EncodedString(),
                "nonce":          nonce.base64EncodedString(),
                "ts":             "\(tsMs)",
                "msg_id":         item.id.uuidString,
                "from_device_id": item.fromDeviceId,
            ])
        }
    }

    private func handleHistoryRequest() {
        guard let publicKey else { return }
        pushHistoryMutationsToPeer()
        pushHistoryToPeer(publicKey: publicKey)
    }

    private func pushHistoryMutationsToPeer() {
        let throughMs = HistoryMutationStore.clearedThroughMs
        if throughMs > 0 { sendHistoryClear(throughMs: throughMs) }
        HistoryMutationStore.deletedMessageIds.forEach {
            sendHistoryDelete(messageId: $0, fromDeviceId: "unknown", timestampMs: 0)
        }
        HistoryMutationStore.deletedSourceTimes.forEach { marker in
            guard let separator = marker.lastIndex(of: "|"),
                  let timestampMs = Int64(marker[marker.index(after: separator)...])
            else { return }
            sendHistoryDelete(
                messageId: "legacy",
                fromDeviceId: String(marker[..<separator]),
                timestampMs: timestampMs
            )
        }
    }

    // MARK: - Send

    private func sendAuth() {
        guard
            let myId     = AirclipIdentity.shared.deviceId,
            let myAirclipId = AirclipIdentity.shared.airClipId,
            let myPk     = try? CryptoManager.shared.publicKeyBase64
        else { return }

        let payload: [String: Any] = [
            "type": "auth",
            "device_id": myId,
            "airclip_id": myAirclipId,
            "public_key": myPk,
            "device_name": AirclipIdentity.shared.deviceName,
            "platform": "mac",
        ]
        sendJSON(payload)
    }

    private func currentSSID() -> String? {
        CWWiFiClient.shared().interface()?.ssid()
    }

    func sendClip(
        type: String = "clip",
        ciphertext: String,
        nonce: String,
        messageId: String,
        timestampMs: Int64,
        fromDeviceId: String
    ) {
        sendJSON([
            "type": type,
            "ciphertext": ciphertext,
            "nonce": nonce,
            "msg_id": messageId,
            "ts": "\(timestampMs)",
            "from_device_id": fromDeviceId,
        ])
    }

    func sendHistoryDelete(messageId: String, fromDeviceId: String, timestampMs: Int64) {
        sendJSON([
            "type": "history_delete",
            "msg_id": messageId,
            "from_device_id": fromDeviceId,
            "ts": "\(timestampMs)",
        ])
    }

    func sendHistoryClear(throughMs: Int64) {
        sendJSON(["type": "history_clear", "through_ms": "\(throughMs)"])
    }

    func sendHeartbeat() {
        var payload: [String: Any] = [
            "type": "heartbeat",
            "ts": "\(Int64(Date().timeIntervalSince1970 * 1000))",
        ]
        if let ssid = currentSSID() { payload["ssid"] = ssid }
        sendJSON(payload)
    }

    func sendFileMessage(_ payload: [String: Any]) {
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
            completion: .contentProcessed { [weak self] error in
                if error != nil || closeAfterSending {
                    Task { @MainActor [weak self] in self?.close() }
                }
            }
        )
    }

    func close() {
        guard !isClosed else { return }
        isClosed = true
        connection.cancel()
        PeerManager.shared.removePeer(id: id)
    }
}
