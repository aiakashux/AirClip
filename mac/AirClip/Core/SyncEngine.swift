import Foundation
import AppKit

/// Orchestrates LAN sync: starts the local server + browser and routes
/// clipboard data to/from peers. No server dependency — all trust is local.
@MainActor
final class SyncEngine: ObservableObject {
    static let shared = SyncEngine()

    @Published var isConnected = false

    weak var clipboardMonitor: ClipboardMonitor?

    private var peerCountObserver: Any?

    private init() {
        peerCountObserver = NotificationCenter.default.addObserver(
            forName: .peerCountChanged, object: nil, queue: .main
        ) { [weak self] note in
            Task { @MainActor [weak self] in
                self?.isConnected = (note.object as? Int ?? 0) > 0
            }
        }
    }

    // MARK: - Connection lifecycle

    func connect() {
        guard SyncModeStore.shared.mode.keepsLanServiceRunning else {
            disconnect()
            return
        }
        LanServer.shared.start()
        LanBrowser.shared.start()
    }

    func disconnect() {
        LanServer.shared.stop()
        LanBrowser.shared.stop()
        PeerManager.shared.disconnectAll()
        isConnected = false
    }

    func reconnect() {
        guard AirClipIdentity.shared.isPaired,
              SyncModeStore.shared.mode.keepsLanServiceRunning
        else { return }

        disconnect()
        connect()
    }

    // MARK: - Outbound

    func sendClipboard(packet: ClipboardPacket, sensitiveOverride: Bool = false) {
        guard SyncModeStore.shared.mode.allowsOutboundSync else { return }
        if !sensitiveOverride {
            let assessment = SensitiveClipboardClassifier.classify(packet.text)
            if let finding = assessment.primaryFinding {
                let action = SensitiveClipboardProtectionStore.shared.action(
                    for: finding.category
                )
                guard SensitiveClipboardPolicy.decide(
                    assessment,
                    intent: .manual,
                    action: action
                ) == .allow else {
                    return
                }
            }
        }
        let myId = AirClipIdentity.shared.deviceId ?? ""
        LocalHistoryStore.shared.insert(packet, fromDeviceId: myId, isLocal: true)
        PeerManager.shared.broadcast(packet: packet)
    }

    // MARK: - Inbound

    func processInboundClip(
        ciphertextB64: String,
        nonceB64: String,
        fromDeviceId: String
    ) async {
        guard SyncModeStore.shared.mode.keepsLanServiceRunning else { return }
        do {
            let plaintext = try CryptoManager.shared.decrypt(
                ciphertextBase64: ciphertextB64,
                nonceBase64: nonceB64,
                senderPublicKeyBase64: ""
            )

            let packet = ClipboardPacket.decode(from: plaintext)
                ?? ClipboardPacket(kind: ClipType.detect(plaintext).clipboardKind, text: plaintext)

            guard SyncModeStore.shared.mode.keepsLanServiceRunning else { return }

            let hash = clipboardMonitor?.sha256(packet.fingerprint) ?? ""
            if clipboardMonitor?.containsHash(hash) == true { return }

            // Add hash BEFORE writing to pasteboard so any poll that fires
            // between the write and the next run-loop tick sees it as known.
            clipboardMonitor?.addHash(hash)

            LocalHistoryStore.shared.insert(packet, fromDeviceId: fromDeviceId, isLocal: false)

            clipboardMonitor?.markRemoteUpdateStart()
            ClipboardCapture.write(packet, to: NSPasteboard.general)
        } catch {}
    }

    func processHistoryClip(
        ciphertextB64: String,
        nonceB64: String,
        timestampMs: Int64,
        messageId: String,
        fromDeviceId: String
    ) async {
        guard SyncModeStore.shared.mode.keepsLanServiceRunning else { return }
        do {
            let plaintext = try CryptoManager.shared.decrypt(
                ciphertextBase64: ciphertextB64,
                nonceBase64: nonceB64,
                senderPublicKeyBase64: ""
            )

            let packet = ClipboardPacket.decode(from: plaintext)
                ?? ClipboardPacket(kind: ClipType.detect(plaintext).clipboardKind, text: plaintext)

            let receivedAt = Date(timeIntervalSince1970: TimeInterval(timestampMs) / 1000)
            LocalHistoryStore.shared.mergeHistoryItem(
                packet,
                fromDeviceId: fromDeviceId,
                receivedAt: receivedAt,
                messageId: messageId
            )
        } catch {}
    }
}

@MainActor
enum ManualClipboardSender {
    static func sendCurrentClipboard() {
        guard SyncModeStore.shared.mode.allowsOutboundSync,
              let packet = ClipboardCapture.readCurrentPacket(from: NSPasteboard.general)
        else {
            NSSound.beep()
            return
        }

        let assessment = SensitiveClipboardClassifier.classify(packet.text)
        if let finding = assessment.primaryFinding {
            let action = SensitiveClipboardProtectionStore.shared.action(for: finding.category)
            switch SensitiveClipboardPolicy.decide(assessment, intent: .manual, action: action) {
            case .block:
                showAlert(
                    title: "Sensitive clipboard blocked",
                    message: "Your \(finding.category.label.lowercased()) rule keeps this item on this Mac."
                )
                return
            case .requireConfirmation:
                guard confirmSend(category: finding.category) else { return }
            case .allow:
                break
            }
        }

        SyncEngine.shared.sendClipboard(packet: packet, sensitiveOverride: true)
    }

    private static func confirmSend(category: SensitiveCategory) -> Bool {
        let alert = NSAlert()
        alert.messageText = "Send sensitive clipboard item?"
        alert.informativeText = "\(category.label) detected. Only continue if you intend to share it with your paired devices."
        alert.addButton(withTitle: "Send Anyway")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .warning
        return alert.runModal() == .alertFirstButtonReturn
    }

    private static func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

// MARK: - PeerCount notification

extension Notification.Name {
    static let peerCountChanged = Notification.Name("com.airclip.peerCountChanged")
}
