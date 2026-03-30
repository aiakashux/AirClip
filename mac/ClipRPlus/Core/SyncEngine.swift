import Foundation
import AppKit
import CryptoKit

/// Manages the WebSocket connection to the relay server, outbound encryption,
/// inbound decryption, and the offline catch-up flow.
@MainActor
final class SyncEngine: ObservableObject {
    static let shared = SyncEngine()

    @Published var isConnected = false

    private var wsTask: URLSessionWebSocketTask?
    private var urlSession: URLSession?
    private var sessionStartedAt: Date?

    private var shouldConnect = false
    private var reconnectDelay: TimeInterval = 1
    private let maxReconnectDelay: TimeInterval = 30
    private var isReconnecting = false

    weak var clipboardMonitor: ClipboardMonitor?

    private init() {}

    // MARK: - Connection lifecycle

    func connect() {
        shouldConnect = true
        reconnectDelay = 1
        Task { await openConnection() }
    }

    func disconnect() {
        shouldConnect = false
        wsTask?.cancel(with: .goingAway, reason: nil)
        wsTask = nil
        isConnected = false
    }

    private func openConnection() async {
        guard shouldConnect, let token = AuthManager.shared.deviceToken else { return }

        let base = UserDefaults.standard.string(forKey: "serverURL") ?? AppConfig.defaultServerURL
        let wsBase = base
            .replacingOccurrences(of: "https://", with: "wss://")
            .replacingOccurrences(of: "http://", with: "ws://")

        guard let url = URL(string: "\(wsBase)/ws") else { return }

        var request = URLRequest(url: url)
        // Auth via header — never query param
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        sessionStartedAt = Date()
        let session = URLSession(configuration: .default)
        urlSession = session
        let task = session.webSocketTask(with: request)
        wsTask = task
        task.resume()

        isConnected = true
        reconnectDelay = 1

        await sendHello()
        await receiveLoop()
    }

    // MARK: - Receive loop

    private func receiveLoop() async {
        guard let task = wsTask else { return }
        while shouldConnect {
            do {
                let msg = try await task.receive()
                switch msg {
                case .string(let text): await dispatch(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) { await dispatch(text) }
                @unknown default: break
                }
            } catch {
                isConnected = false
                wsTask = nil
                if shouldConnect { await scheduleReconnect() }
                return
            }
        }
    }

    private func scheduleReconnect() async {
        guard !isReconnecting else { return }
        isReconnecting = true
        try? await Task.sleep(for: .seconds(reconnectDelay))
        reconnectDelay = min(reconnectDelay * 2, maxReconnectDelay)
        isReconnecting = false
        await openConnection()
    }

    // MARK: - Message dispatch

    private func dispatch(_ text: String) async {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else { return }

        switch type {
        case "hello":           await handleHello(json)
        case "deliver_clipboard": await handleDeliver(json)
        default: break
        }
    }

    // MARK: - Hello / catch-up

    private func sendHello() async {
        let lastSeq = UserDefaults.standard.integer(forKey: "lastSeenSeq")
        await sendJSON(["type": "hello", "last_seen_seq": lastSeq])
    }

    private func handleHello(_ json: [String: Any]) async {
        let raw = json["latest_seq"]
        let latestSeq = (raw as? Int) ?? Int(raw as? String ?? "") ?? 0
        let lastSeenSeq = UserDefaults.standard.integer(forKey: "lastSeenSeq")
        if latestSeq > lastSeenSeq {
            await fetchMissedClips(afterSeq: lastSeenSeq)
        }
    }

    private func fetchMissedClips(afterSeq: Int) async {
        guard let clips = try? await APIClient.shared.fetchMissedClips(afterSeq: afterSeq) else { return }
        for clip in clips.sorted(by: { $0.seq < $1.seq }) {
            // Loop prevention: ignore self-origin
            guard clip.fromDeviceId != AuthManager.shared.deviceId else { continue }
            await processInboundClip(
                messageId: clip.messageId,
                seq: clip.seq,
                fromDeviceId: clip.fromDeviceId,
                ciphertextB64: clip.ciphertext,
                nonceB64: clip.nonce
            )
        }
    }

    // MARK: - Deliver

    private func handleDeliver(_ json: [String: Any]) async {
        guard
            let messageId  = json["message_id"] as? String,
            let fromDevice = json["from_device_id"] as? String,
            let ctB64      = json["ciphertext"] as? String,
            let nonceB64   = json["nonce"] as? String
        else { return }

        // Loop prevention: ignore self-origin
        guard fromDevice != AuthManager.shared.deviceId else { return }

        let seqRaw = json["seq"]
        let seq = (seqRaw as? Int) ?? Int(seqRaw as? String ?? "") ?? 0
        await processInboundClip(
            messageId: messageId,
            seq: seq,
            fromDeviceId: fromDevice,
            ciphertextB64: ctB64,
            nonceB64: nonceB64
        )
        await sendAck(messageId: messageId)
    }

    private func processInboundClip(
        messageId: String,
        seq: Int,
        fromDeviceId: String,
        ciphertextB64: String,
        nonceB64: String
    ) async {
        guard let senderKey = await resolveSenderPublicKey(deviceId: fromDeviceId) else { return }

        do {
            let plaintext = try CryptoManager.shared.decrypt(
                ciphertextBase64: ciphertextB64,
                nonceBase64: nonceB64,
                senderPublicKeyBase64: senderKey
            )

            // Hash dedup — guards against echo loops
            let hash = clipboardMonitor?.sha256(plaintext) ?? ""
            if clipboardMonitor?.containsHash(hash) == true { return }

            LocalHistoryStore.shared.insert(text: plaintext, fromDeviceId: fromDeviceId, isLocal: false)

            // Write to clipboard, suppressing the monitor's next change event
            clipboardMonitor?.markRemoteUpdateStart()
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(plaintext, forType: .string)
            clipboardMonitor?.addHash(hash)

            if seq > 0 { UserDefaults.standard.set(seq, forKey: "lastSeenSeq") }
        } catch {
            // Decryption failure — swallowed intentionally; no plaintext in logs
        }
    }

    // MARK: - Outbound

    func sendClipboard(text: String) {
        Task { await doSend(text: text) }
    }

    private func doSend(text: String) async {
        guard let devices = try? await APIClient.shared.listDevices() else { return }

        let myId = AuthManager.shared.deviceId
        let recipients = devices.filter { $0.trustStatus == "trusted" && $0.id != myId }
        guard !recipients.isEmpty else { return }

        var payloads: [[String: String]] = []
        for dev in recipients {
            guard let pk = dev.publicKey else { continue }
            do {
                let (ct, nonce) = try CryptoManager.shared.encrypt(
                    plaintext: text,
                    recipientPublicKeyBase64: pk
                )
                payloads.append([
                    "to_device_id": dev.id,
                    "ciphertext":   ct.base64EncodedString(),
                    "nonce":        nonce.base64EncodedString()
                ])
            } catch {}
        }
        guard !payloads.isEmpty else { return }

        await sendJSON(["type": "send_clipboard", "payloads": payloads])
        LocalHistoryStore.shared.insert(
            text: text,
            fromDeviceId: myId ?? "",
            isLocal: true
        )
    }

    // MARK: - Device approval

    func approveDevice(targetDeviceId: String) async {
        await sendJSON(["type": "approve_device", "target_device_id": targetDeviceId])
    }

    // MARK: - Helpers

    private func sendAck(messageId: String) async {
        await sendJSON(["type": "ack", "message_id": messageId])
    }

    private func sendJSON(_ payload: [String: Any]) async {
        guard let task = wsTask,
              let data = try? JSONSerialization.data(withJSONObject: payload),
              let text = String(data: data, encoding: .utf8) else { return }
        do {
            try await task.send(.string(text))
        } catch {
            isConnected = false
        }
    }

    private func resolveSenderPublicKey(deviceId: String) async -> String? {
        guard let devices = try? await APIClient.shared.listDevices() else { return nil }
        return devices.first(where: { $0.id == deviceId })?.publicKey
    }
}
