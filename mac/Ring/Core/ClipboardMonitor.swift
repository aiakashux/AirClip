import AppKit
import CryptoKit

/// Polls NSPasteboard every 500 ms and publishes new local copies to SyncEngine.
/// Implements all loop-prevention rules.
@MainActor
final class ClipboardMonitor {
    static let shared = ClipboardMonitor()

    /// Set true before writing a remote payload to NSPasteboard so the
    /// resulting change-count bump is ignored.
    private(set) var remoteUpdateInProgress = false

    /// Rolling cache of the last 10 SHA-256 hashes of sent/received content.
    private var recentHashes: [String] = []
    private let maxHashes = 10

    /// Set true before a tap-to-copy write so the resulting change is ignored.
    private var isSuppressed = false

    private var timer: Timer?
    private var lastChangeCount: Int = NSPasteboard.general.changeCount

    weak var syncEngine: SyncEngine?

    private init() {}

    // MARK: - Lifecycle

    func start() {
        lastChangeCount = NSPasteboard.general.changeCount
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.poll() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Loop-prevention API

    /// Call before writing to NSPasteboard from a tap-to-copy action.
    func suppressNextChange() {
        isSuppressed = true
    }

    /// Call before writing a remote update to NSPasteboard.
    func markRemoteUpdateStart() {
        remoteUpdateInProgress = true
    }

    func containsHash(_ hash: String) -> Bool {
        recentHashes.contains(hash)
    }

    func addHash(_ hash: String) {
        recentHashes.append(hash)
        if recentHashes.count > maxHashes { recentHashes.removeFirst() }
    }

    // MARK: - Polling

    private func poll() {
        let current = NSPasteboard.general.changeCount
        guard current != lastChangeCount else { return }
        lastChangeCount = current

        // Rule 1: remote update wrote to the clipboard — skip
        if remoteUpdateInProgress {
            remoteUpdateInProgress = false
            return
        }

        // Rule 1b: tap-to-copy suppression
        if isSuppressed {
            isSuppressed = false
            return
        }

        guard let text = NSPasteboard.general.string(forType: .string), !text.isEmpty else { return }

        // Rule 2: hash-based dedup
        let hash = sha256(text)
        guard !recentHashes.contains(hash) else { return }

        // Rule 3: new content — record hash and forward to SyncEngine
        addHash(hash)
        syncEngine?.sendClipboard(text: text)
    }

    // MARK: - Helpers

    func sha256(_ text: String) -> String {
        let digest = SHA256.hash(data: Data(text.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
