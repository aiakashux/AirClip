import Foundation
import UIKit
import BackgroundTasks
import WidgetKit
import CryptoKit

/// Orchestrates LAN sync on iOS: starts the local server + browser, manages the
/// trusted-device cache, and routes clipboard data to/from peers.
///
/// Key iOS differences from Mac:
///   - UIPasteboard for clipboard writes
///   - No clipboard monitoring (iOS forbids background reads; user taps Send explicitly)
///   - BGAppRefreshTask registration for lightweight background refresh
///   - App Group UserDefaults → WidgetKit state sync
@MainActor
final class SyncEngine: ObservableObject {
    static let shared = SyncEngine()

    @Published var isConnected = false

    private var recentHashes  = RecentHashSet()
    private var peerCountObserver: Any?

    private init() {
        peerCountObserver = NotificationCenter.default.addObserver(
            forName: .peerCountChanged, object: nil, queue: .main
        ) { [weak self] note in
            let count = note.object as? Int ?? 0
            self?.isConnected = count > 0
            self?.updateWidgetForPeerCount(count)
        }
    }

    // MARK: - Connection lifecycle

    func connect() {
        Task { await refreshDeviceCache() }
        LanServer.shared.start()
        LanBrowser.shared.start()
    }

    func disconnect() {
        LanServer.shared.stop()
        LanBrowser.shared.stop()
        PeerManager.shared.disconnectAll()
        isConnected = false
    }

    // MARK: - Device cache

    func refreshDeviceCache() async {
        guard let devices = try? await APIClient.shared.listDevices() else { return }
        PeerManager.shared.updateTrustedDevices(devices)
    }

    // MARK: - Outbound

    /// Read the current clipboard and broadcast to all peers.
    /// Call from UI (explicit user action) — reading clipboard from background is forbidden on iOS.
    func sendCurrentClipboard() {
        guard let text = UIPasteboard.general.string, !text.isEmpty else { return }
        sendClipboard(text: text)
    }

    /// Encrypt `text` and broadcast to authenticated peers.
    func sendClipboard(text: String) {
        let myId = AuthManager.shared.deviceId ?? ""
        LocalHistoryStore.shared.insert(text: text, fromDeviceId: myId, isLocal: true)

        let hash = sha256(text)
        recentHashes.record(hash)

        PeerManager.shared.broadcast(plaintext: text)

        WidgetSharedState.save(state: .synced)
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - Inbound

    func processInboundClip(ciphertextB64: String, nonceB64: String, fromDeviceId: String) async {
        do {
            let plaintext = try CryptoManager.shared.decrypt(
                ciphertextBase64: ciphertextB64,
                nonceBase64: nonceB64,
                senderPublicKeyBase64: ""   // sealed box — no sender key needed
            )

            let hash = sha256(plaintext)
            if recentHashes.isKnown(hash) { return }
            recentHashes.record(hash)

            LocalHistoryStore.shared.insert(
                text: plaintext, fromDeviceId: fromDeviceId, isLocal: false
            )

            // Write to clipboard (allowed from any context on iOS — only reading is restricted)
            UIPasteboard.general.string = plaintext

            // Update widget — show "New from Mac" with preview
            WidgetSharedState.save(state: .pending, preview: plaintext.prefix(40).description, lastText: plaintext)
            WidgetCenter.shared.reloadAllTimelines()

        } catch {
            // Decryption failure — swallowed; no plaintext in logs.
        }
    }

    // MARK: - Background refresh

    func scheduleBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: AppConfig.bgRefreshTaskID)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }

    // MARK: - Widget helpers

    private func updateWidgetForPeerCount(_ count: Int) {
        let current = WidgetSharedState.state
        if count == 0, current != .noDevices {
            WidgetSharedState.save(state: .noDevices)
            WidgetCenter.shared.reloadAllTimelines()
        } else if count > 0, current == .noDevices {
            WidgetSharedState.save(state: .synced)
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    // MARK: - Hash dedup

    func sha256(_ text: String) -> String {
        let hash = SHA256.hash(data: Data(text.utf8))
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Notification name

extension Notification.Name {
    static let peerCountChanged = Notification.Name("com.airclip.peerCountChanged")
}

// MARK: - Bounded recent-hash set (echo suppression)

private class RecentHashSet {
    private var hashes: [String] = []
    private let maxSize = 50

    func isKnown(_ hash: String) -> Bool { hashes.contains(hash) }

    func record(_ hash: String) {
        guard !hashes.contains(hash) else { return }
        hashes.append(hash)
        if hashes.count > maxSize { hashes.removeFirst() }
    }
}
