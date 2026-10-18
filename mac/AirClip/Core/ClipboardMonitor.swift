import AppKit

/// Polls NSPasteboard every 500 ms and publishes new local copies to SyncEngine.
/// Implements all loop-prevention rules.
@MainActor
final class ClipboardMonitor {
    static let shared = ClipboardMonitor()

    /// Set true before writing a remote payload to NSPasteboard so the
    /// resulting change-count bump is ignored.
    private(set) var remoteUpdateInProgress = false

    /// Set true before a tap-to-copy write so the resulting change is ignored.
    private var isSuppressed = false

    private var timer: Timer?
    private var lastChangeCount: Int = NSPasteboard.general.changeCount

    weak var syncEngine: SyncEngine?

    private init() {}

    // MARK: - Lifecycle

    func start() {
        guard timer?.isValid != true else { return }
        lastChangeCount = NSPasteboard.general.changeCount
        let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.poll() }
        }
        timer.tolerance = 0.1
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func restart() {
        stop()
        start()
    }

    // MARK: - Loop-prevention API

    /// Call before writing to NSPasteboard from a tap-to-copy action.
    func suppressNextChange() {
        isSuppressed = true
    }

    /// Call before writing a known packet from history so the immediate
    /// change-count bump is ignored.
    func suppressPacket(_ packet: ClipboardPacket) {
        isSuppressed = true
    }

    /// Call before writing a remote update to NSPasteboard.
    func markRemoteUpdateStart() {
        remoteUpdateInProgress = true
    }

    // MARK: - Polling

    private func poll() {
        let current = NSPasteboard.general.changeCount
        guard current != lastChangeCount else { return }
        lastChangeCount = current

        let explicitShare = NSPasteboard.general.data(forType: NSPasteboard.PasteboardType("com.airclip.share-files")) != nil
        guard SyncModeStore.shared.mode.allowsAutomaticCapture ||
              (explicitShare && SyncModeStore.shared.mode.allowsOutboundSync) else { return }

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

        let packets = ClipboardCapture.readCurrentPackets(from: NSPasteboard.general)
        for packet in packets {
            syncEngine?.sendClipboard(packet: packet)
        }

        if explicitShare, !packets.isEmpty {
            StatusBarController.shared.showShareConfirmation()
        }
    }
}
