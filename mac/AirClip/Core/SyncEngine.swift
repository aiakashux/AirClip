import Foundation
import AppKit

struct FileTransferProgress: Equatable {
    enum Phase: Equatable { case downloading, downloaded, failed(String) }
    var phase: Phase
    var received: Int64
    var total: Int64
    var temporaryPreview = false
}

private let filePreviewMaxBytes: Int64 = 3 * 1024 * 1024

/// Orchestrates LAN sync: starts the local server + browser and routes
/// clipboard data to/from peers. No server dependency — all trust is local.
@MainActor
final class SyncEngine: ObservableObject {
    static let shared = SyncEngine()

    @Published var isConnected = false
    @Published private(set) var fileTransfers: [String: FileTransferProgress] = [:]

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
        guard AirclipIdentity.shared.isPaired,
              SyncModeStore.shared.mode.keepsLanServiceRunning
        else { return }

        disconnect()
        connect()
    }

    // MARK: - Outbound

    func sendClipboard(packet: ClipboardPacket, prepared: Bool = false, isSaved: Bool = false) {
        guard SyncModeStore.shared.mode.allowsOutboundSync else { return }
        if packet.kind == .file, !prepared, let id = packet.file?.id {
            Task {
                var enriched = packet
                if let file = enriched.file {
                    enriched.file = await FileClipSource.enrichMedia(file)
                }
                if let thumbnail = await FileClipSource.thumbnail(for: id) {
                    enriched.file?.thumbnailBase64 = thumbnail.base64EncodedString()
                }
                sendClipboard(packet: enriched, prepared: true, isSaved: isSaved)
            }
            return
        }
        let myId = AirclipIdentity.shared.deviceId ?? ""
        let messageId = UUID()
        let timestamp = Date()
        LocalHistoryStore.shared.insert(
            packet,
            fromDeviceId: myId,
            isLocal: true,
            id: messageId,
            receivedAt: timestamp,
            isSaved: isSaved
        )
        PeerManager.shared.broadcast(
            packet: packet,
            messageId: messageId.uuidString,
            timestampMs: Int64(timestamp.timeIntervalSince1970 * 1000),
            fromDeviceId: myId
        )
    }

    // MARK: - Inbound

    func processInboundClip(
        ciphertextB64: String,
        nonceB64: String,
        fromDeviceId: String,
        timestampMs: Int64,
        messageId: String
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

            LocalHistoryStore.shared.insert(
                packet,
                fromDeviceId: fromDeviceId,
                isLocal: false,
                id: UUID(uuidString: messageId) ?? UUID(),
                receivedAt: Date(timeIntervalSince1970: TimeInterval(timestampMs) / 1000)
            )

            if packet.kind != .file {
                clipboardMonitor?.markRemoteUpdateStart()
                ClipboardCapture.write(packet, to: NSPasteboard.general)
            }
            PrivacyAnalytics.shared.record(.firstTransfer)
        } catch {
            PrivacyAnalytics.shared.record(.transferFailure)
        }
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

    func deleteHistoryItem(_ item: ClipboardItem) {
        let messageId = item.id.uuidString
        let timestampMs = Int64(item.receivedAt.timeIntervalSince1970 * 1000)
        HistoryMutationStore.recordDelete(
            messageId: messageId,
            fromDeviceId: item.fromDeviceId,
            timestampMs: timestampMs
        )
        LocalHistoryStore.shared.delete(
            messageId: messageId,
            fromDeviceId: item.fromDeviceId,
            timestampMs: timestampMs
        )
        PeerManager.shared.broadcastHistoryDelete(
            messageId: messageId,
            fromDeviceId: item.fromDeviceId,
            timestampMs: timestampMs
        )
    }

    func clearHistory() {
        let throughMs = Int64(Date().timeIntervalSince1970 * 1000)
        HistoryMutationStore.recordClear(throughMs: throughMs)
        LocalHistoryStore.shared.clear(throughMs: throughMs)
        PeerManager.shared.broadcastHistoryClear(throughMs: throughMs)
    }

    func applyHistoryDelete(messageId: String, fromDeviceId: String, timestampMs: Int64) {
        HistoryMutationStore.recordDelete(
            messageId: messageId,
            fromDeviceId: fromDeviceId,
            timestampMs: timestampMs
        )
        LocalHistoryStore.shared.delete(
            messageId: messageId,
            fromDeviceId: fromDeviceId,
            timestampMs: timestampMs
        )
    }

    func applyHistoryClear(throughMs: Int64) {
        HistoryMutationStore.recordClear(throughMs: throughMs)
        LocalHistoryStore.shared.clear(throughMs: throughMs)
    }

    private static func downloadedURL(for file: FileClipMetadata) -> URL? {
        guard let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        let directory = support.appendingPathComponent("AirclipFiles", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let ext = URL(fileURLWithPath: file.name).pathExtension
        return directory.appendingPathComponent(file.id + (ext.isEmpty ? "" : "." + ext))
    }

    private static func previewURL(for file: FileClipMetadata) -> URL? {
        guard let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else { return nil }
        let directory = base.appendingPathComponent("AirclipFilePreviews", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let ext = URL(fileURLWithPath: file.name).pathExtension
        return directory.appendingPathComponent(file.id + (ext.isEmpty ? "" : "." + ext))
    }

    func availablePreviewURL(for item: ClipboardItem) -> URL? {
        guard let file = item.fileMetadata, file.size <= filePreviewMaxBytes else { return nil }
        if item.isLocal { return FileClipSource.url(for: file.id) }
        guard let url = Self.previewURL(for: file),
              FileManager.default.fileExists(atPath: url.path),
              ((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? -1) == Int(file.size)
        else { return nil }
        return url
    }

    func previewFile(_ item: ClipboardItem) {
        guard let file = item.fileMetadata, file.size <= filePreviewMaxBytes,
              !item.isLocal,
              let peer = PeerManager.shared.peers[item.fromDeviceId],
              let destination = Self.previewURL(for: file)
        else { return }
        if FileManager.default.fileExists(atPath: destination.path),
           ((try? destination.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? -1) == Int(file.size) { return }
        let partial = destination.appendingPathExtension("part")
        var offset = Int64((try? partial.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        if offset > file.size {
            try? FileManager.default.removeItem(at: partial)
            offset = 0
        }
        fileTransfers[file.id] = FileTransferProgress(
            phase: .downloading, received: offset, total: file.size, temporaryPreview: true
        )
        peer.sendFileMessage([
            "type": "file_request", "file_id": file.id, "offset": "\(offset)",
            "preview_limit": "\(file.size)", "preview_only": "true"
        ])
    }

    func clearPreviewFile(for item: ClipboardItem) {
        guard let file = item.fileMetadata else { return }
        if !item.isLocal, let url = Self.previewURL(for: file) {
            try? FileManager.default.removeItem(at: url)
            try? FileManager.default.removeItem(at: url.appendingPathExtension("part"))
        }
        if fileTransfers[file.id]?.temporaryPreview == true { fileTransfers.removeValue(forKey: file.id) }
    }

    func availableFileURL(for item: ClipboardItem) -> URL? {
        guard let file = item.fileMetadata else { return nil }
        if item.isLocal { return FileClipSource.url(for: file.id) }
        guard let url = Self.downloadedURL(for: file), FileManager.default.fileExists(atPath: url.path) else { return nil }
        return url
    }

    func withAvailableFileURL<T>(for item: ClipboardItem, _ operation: (URL) throws -> T) rethrows -> T? {
        guard let file = item.fileMetadata else { return nil }
        if item.isLocal { return try FileClipSource.withAccess(to: file.id, operation) }
        guard let url = Self.downloadedURL(for: file), FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try operation(url)
    }

    func downloadFile(_ item: ClipboardItem) {
        guard let file = item.fileMetadata,
              item.fromDeviceId != AirclipIdentity.shared.deviceId,
              let peer = PeerManager.shared.peers[item.fromDeviceId],
              let destination = Self.downloadedURL(for: file)
        else {
            if let file = item.fileMetadata {
                fileTransfers[file.id] = FileTransferProgress(phase: .failed("Source device is offline"), received: 0, total: file.size)
            }
            return
        }
        let partial = destination.appendingPathExtension("part")
        var offset = Int64((try? partial.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        if offset > file.size {
            try? FileManager.default.removeItem(at: partial)
            offset = 0
        }
        fileTransfers[file.id] = FileTransferProgress(phase: .downloading, received: offset, total: file.size)
        peer.sendFileMessage(["type": "file_request", "file_id": file.id, "offset": "\(offset)"])
    }

    func handleFileRequest(_ json: [String: Any], peer: PeerConnection) {
        guard let id = json["file_id"] as? String,
              let offset = (json["offset"] as? String).flatMap(Int64.init), offset >= 0,
              let publicKey = peer.publicKey,
              let file = LocalHistoryStore.shared.fileMetadata(id: id),
              offset <= file.size
        else {
            peer.sendFileMessage(["type": "file_chunk", "file_id": json["file_id"] as? String ?? "", "error": "File unavailable"])
            return
        }
        let previewLimit = (json["preview_limit"] as? String).flatMap(Int64.init)
        let transferLimit: Int64
        if let previewLimit {
            guard previewLimit >= 0, previewLimit <= filePreviewMaxBytes, previewLimit == file.size else {
                peer.sendFileMessage(["type": "file_chunk", "file_id": id, "error": "Preview unavailable"])
                return
            }
            transferLimit = previewLimit
        } else {
            transferLimit = file.size
        }
        guard offset <= transferLimit else {
            peer.sendFileMessage(["type": "file_chunk", "file_id": id, "error": "Preview unavailable"])
            return
        }
        do {
            let sent = try FileClipSource.withAccess(to: id) { url in
                let values = try url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
                guard Int64(values.fileSize ?? -1) == file.size,
                      values.contentModificationDate.map({ Int64($0.timeIntervalSince1970 * 1000) }) == file.modifiedAtMs
                else { throw CocoaError(.fileReadCorruptFile) }
                let handle = try FileHandle(forReadingFrom: url)
                defer { try? handle.close() }
                try handle.seek(toOffset: UInt64(offset))
                let chunk = try handle.read(upToCount: Int(min(512 * 1024, transferLimit - offset))) ?? Data()
                let encrypted = try CryptoManager.shared.encrypt(data: chunk, recipientPublicKeyBase64: publicKey)
                peer.sendFileMessage([
                    "type": "file_chunk", "file_id": id, "offset": "\(offset)",
                    "ciphertext": encrypted.ciphertext.base64EncodedString(),
                    "done": String(offset + Int64(chunk.count) >= transferLimit),
                    "preview_only": String(previewLimit != nil)
                ])
                return true
            }
            guard sent == true else { throw CocoaError(.fileNoSuchFile) }
        } catch {
            peer.sendFileMessage(["type": "file_chunk", "file_id": id, "error": "File unavailable"])
        }
    }

    func handleFileChunk(_ json: [String: Any], peer: PeerConnection) {
        guard let id = json["file_id"] as? String,
              var state = fileTransfers[id], state.phase == .downloading,
              let item = LocalHistoryStore.shared.fileItem(id: id),
              item.fromDeviceId == peer.deviceId,
              let file = item.fileMetadata
        else { return }
        let previewOnly = state.temporaryPreview || (json["preview_only"] as? String == "true")
        guard !previewOnly || file.size <= filePreviewMaxBytes,
              let destination = previewOnly ? Self.previewURL(for: file) : Self.downloadedURL(for: file)
        else { return }
        if let error = json["error"] as? String {
            state.phase = .failed(error)
            fileTransfers[id] = state
            return
        }
        guard let offset = (json["offset"] as? String).flatMap(Int64.init), offset == state.received,
              let ciphertext = json["ciphertext"] as? String
        else {
            state.phase = .failed("Transfer interrupted")
            fileTransfers[id] = state
            return
        }
        let chunk = ciphertext.isEmpty && file.size == 0
            ? Data()
            : (try? CryptoManager.shared.decryptData(ciphertextBase64: ciphertext))
        guard let chunk, offset + Int64(chunk.count) <= file.size else {
            state.phase = .failed("Transfer interrupted")
            fileTransfers[id] = state
            return
        }
        let partial = destination.appendingPathExtension("part")
        do {
            if !FileManager.default.fileExists(atPath: partial.path) {
                FileManager.default.createFile(atPath: partial.path, contents: nil)
            }
            let handle = try FileHandle(forWritingTo: partial)
            defer { try? handle.close() }
            try handle.seek(toOffset: UInt64(offset))
            try handle.write(contentsOf: chunk)
            state.received += Int64(chunk.count)
            if json["done"] as? Bool == true || json["done"] as? String == "true" {
                guard state.received == file.size else { throw CocoaError(.fileReadCorruptFile) }
                if FileManager.default.fileExists(atPath: destination.path) { try FileManager.default.removeItem(at: destination) }
                try FileManager.default.moveItem(at: partial, to: destination)
                state.phase = .downloaded
                state.temporaryPreview = previewOnly
            } else {
                peer.sendFileMessage([
                    "type": "file_request", "file_id": id, "offset": "\(state.received)",
                    "preview_limit": previewOnly ? "\(file.size)" : "",
                    "preview_only": String(previewOnly)
                ].filter { !$0.value.isEmpty })
            }
            fileTransfers[id] = state
        } catch {
            state.phase = .failed("Could not save file")
            fileTransfers[id] = state
        }
    }
}

@MainActor
enum ManualClipboardSender {
    static func sendCurrentClipboard() {
        guard SyncModeStore.shared.mode.allowsOutboundSync else {
            NSSound.beep()
            return
        }
        let packets = ClipboardCapture.readCurrentPackets(from: NSPasteboard.general)
        guard !packets.isEmpty else {
            NSSound.beep()
            return
        }
        for packet in packets {
            send(packet)
        }
    }

    private static func send(_ packet: ClipboardPacket) {
        guard SyncModeStore.shared.mode.allowsOutboundSync
        else {
            NSSound.beep()
            return
        }

        SyncEngine.shared.sendClipboard(packet: packet)
    }

}

// MARK: - PeerCount notification

extension Notification.Name {
    static let peerCountChanged = Notification.Name("com.airclip.peerCountChanged")
}
