import Foundation
import SwiftData

enum HistoryMutationPolicy {
    static func accepts(
        messageId: String,
        fromDeviceId: String,
        timestampMs: Int64,
        clearedThroughMs: Int64,
        deletedMessageIds: Set<String>,
        deletedSourceTimes: Set<String> = []
    ) -> Bool {
        timestampMs > clearedThroughMs &&
            !deletedMessageIds.contains(messageId) &&
            !deletedSourceTimes.contains { marker in
                guard let separator = marker.lastIndex(of: "|"),
                      marker[..<separator] == fromDeviceId,
                      let deletedAt = Int64(marker[marker.index(after: separator)...])
                else { return false }
                return abs(Double(deletedAt) - Double(timestampMs)) <= 2_000
            }
    }
}

enum HistoryMutationStore {
    private static let clearKey = "historyClearThroughMs"
    private static let deletedKey = "historyDeletedMessageIds"
    private static let deletedSourceTimesKey = "historyDeletedSourceTimes"
    private static let maxDeletedIds = 500

    static var clearedThroughMs: Int64 {
        Int64(UserDefaults.standard.double(forKey: clearKey))
    }

    static var deletedMessageIds: Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: deletedKey) ?? [])
    }

    static var deletedSourceTimes: Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: deletedSourceTimesKey) ?? [])
    }

    static func accepts(messageId: String, fromDeviceId: String, timestampMs: Int64) -> Bool {
        HistoryMutationPolicy.accepts(
            messageId: messageId,
            fromDeviceId: fromDeviceId,
            timestampMs: timestampMs,
            clearedThroughMs: clearedThroughMs,
            deletedMessageIds: deletedMessageIds,
            deletedSourceTimes: deletedSourceTimes
        )
    }

    static func recordDelete(messageId: String, fromDeviceId: String, timestampMs: Int64) {
        var ids = Array(deletedMessageIds)
        ids.removeAll { $0 == messageId }
        ids.append(messageId)
        UserDefaults.standard.set(Array(ids.suffix(maxDeletedIds)), forKey: deletedKey)
        var sourceTimes = Array(deletedSourceTimes)
        let marker = "\(fromDeviceId)|\(timestampMs)"
        sourceTimes.removeAll { $0 == marker }
        sourceTimes.append(marker)
        UserDefaults.standard.set(Array(sourceTimes.suffix(maxDeletedIds)), forKey: deletedSourceTimesKey)
    }

    static func recordClear(throughMs: Int64) {
        UserDefaults.standard.set(Double(max(clearedThroughMs, throughMs)), forKey: clearKey)
        UserDefaults.standard.removeObject(forKey: deletedKey)
        UserDefaults.standard.removeObject(forKey: deletedSourceTimesKey)
    }

    static func reset() {
        UserDefaults.standard.removeObject(forKey: clearKey)
        UserDefaults.standard.removeObject(forKey: deletedKey)
        UserDefaults.standard.removeObject(forKey: deletedSourceTimesKey)
    }
}

enum HistoryRetentionPolicy {
    static let labels = ["1 day", "3 days", "7 days", "15 days", "30 days", "No time limit (500)"]
    static let days = [1, 3, 7, 15, 30, 0]
    static let maxItems = 500
    private static let currentVersion = 3
    private static let defaultIndex = 2

    static func selectedIndex(defaults: UserDefaults = .standard) -> Int {
        guard let stored = defaults.object(forKey: "historyDepth") as? Int else {
            setSelectedIndex(defaultIndex, defaults: defaults)
            return defaultIndex
        }
        let version = defaults.integer(forKey: "historyDepthVersion")
        guard version >= currentVersion else {
            let previousValue = version < 2
                ? [2, 4, 4, 5][min(max(stored, 0), 3)]
                : min(max(stored, 0), days.count - 1)
            let migrated = previousValue == 4 ? defaultIndex : previousValue
            setSelectedIndex(migrated, defaults: defaults)
            return migrated
        }
        return min(max(stored, 0), days.count - 1)
    }

    static func setSelectedIndex(_ index: Int, defaults: UserDefaults = .standard) {
        defaults.set(min(max(index, 0), days.count - 1), forKey: "historyDepth")
        defaults.set(currentVersion, forKey: "historyDepthVersion")
    }
}

enum ClipboardSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { .init(1, 0, 0) }

    static var models: [any PersistentModel.Type] { [ClipboardItem.self] }

    @Model
    final class ClipboardItem {
        var id: UUID
        var text: String
        var receivedAt: Date
        var fromDeviceId: String
        var isLocal: Bool
        var isSaved: Bool = false

        init(
            id: UUID = UUID(),
            text: String,
            receivedAt: Date = Date(),
            fromDeviceId: String,
            isLocal: Bool,
            isSaved: Bool = false
        ) {
            self.id = id
            self.text = text
            self.receivedAt = receivedAt
            self.fromDeviceId = fromDeviceId
            self.isLocal = isLocal
            self.isSaved = isSaved
        }
    }
}

enum ClipboardSchemaV2: VersionedSchema {
    static var versionIdentifier: Schema.Version { .init(2, 0, 0) }

    static var models: [any PersistentModel.Type] { [ClipboardItem.self] }

    @Model
    final class ClipboardItem {
        var id: UUID
        var text: String
        var kindRaw: String
        var imageData: Data?
        var receivedAt: Date
        var fromDeviceId: String
        var isLocal: Bool
        var isSaved: Bool = false

        init(
            id: UUID = UUID(),
            text: String,
            kindRaw: String = ClipType.text.rawValue,
            imageData: Data? = nil,
            receivedAt: Date = Date(),
            fromDeviceId: String,
            isLocal: Bool,
            isSaved: Bool = false
        ) {
            self.id = id
            self.text = text
            self.kindRaw = kindRaw
            self.imageData = imageData
            self.receivedAt = receivedAt
            self.fromDeviceId = fromDeviceId
            self.isLocal = isLocal
            self.isSaved = isSaved
        }

        var clipType: ClipType {
            ClipType(rawValue: kindRaw) ?? ClipType.detect(text)
        }

        var clipboardPacket: ClipboardPacket {
            ClipboardPacket(kind: clipType.clipboardKind, text: text, imageData: imageData)
        }
    }
}

enum ClipboardSchemaV3: VersionedSchema {
    static var versionIdentifier: Schema.Version { .init(3, 0, 0) }
    static var models: [any PersistentModel.Type] { [ClipboardItem.self] }

    @Model
    final class ClipboardItem {
        var id: UUID
        var text: String
        var kindRaw: String
        var imageData: Data?
        var fileMetadataData: Data?
        var receivedAt: Date
        var fromDeviceId: String
        var isLocal: Bool
        var isSaved: Bool = false

        init(
            id: UUID = UUID(),
            text: String,
            kindRaw: String = ClipType.text.rawValue,
            imageData: Data? = nil,
            fileMetadataData: Data? = nil,
            receivedAt: Date = Date(),
            fromDeviceId: String,
            isLocal: Bool,
            isSaved: Bool = false
        ) {
            self.id = id
            self.text = text
            self.kindRaw = kindRaw
            self.imageData = imageData
            self.fileMetadataData = fileMetadataData
            self.receivedAt = receivedAt
            self.fromDeviceId = fromDeviceId
            self.isLocal = isLocal
            self.isSaved = isSaved
        }

        var clipType: ClipType {
            ClipType(rawValue: kindRaw) ?? ClipType.detect(text)
        }

        var fileMetadata: FileClipMetadata? {
            fileMetadataData.flatMap { try? JSONDecoder().decode(FileClipMetadata.self, from: $0) }
        }

        var clipboardPacket: ClipboardPacket {
            ClipboardPacket(kind: clipType.clipboardKind, text: text, imageData: imageData, file: fileMetadata)
        }
    }
}

enum ClipboardMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [ClipboardSchemaV1.self, ClipboardSchemaV2.self, ClipboardSchemaV3.self] }
    static var stages: [MigrationStage] {
        [
            .lightweight(fromVersion: ClipboardSchemaV1.self, toVersion: ClipboardSchemaV2.self),
            .lightweight(fromVersion: ClipboardSchemaV2.self, toVersion: ClipboardSchemaV3.self)
        ]
    }
}

typealias ClipboardItem = ClipboardSchemaV3.ClipboardItem

@MainActor
final class LocalHistoryStore {
    static let shared = LocalHistoryStore()
    static let maxItems = HistoryRetentionPolicy.maxItems

    let container: ModelContainer

    private init() {
        container = Self.makeContainer() ?? Self.makeInMemoryContainer()
    }

    private static func makeContainer() -> ModelContainer? {
        let schema = Schema(versionedSchema: ClipboardSchemaV3.self)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(
                for: schema,
                migrationPlan: ClipboardMigrationPlan.self,
                configurations: [config]
            )
        } catch {
            // Keep the existing store intact if a migration fails. An in-memory
            // fallback is safer than silently deleting the user's clip history.
            return nil
        }
    }

    private static func makeInMemoryContainer() -> ModelContainer {
        let schema = Schema(versionedSchema: ClipboardSchemaV3.self)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try! ModelContainer(
            for: schema,
            migrationPlan: ClipboardMigrationPlan.self,
            configurations: [config]
        )
    }

    func insert(text: String, fromDeviceId: String, isLocal: Bool) {
        insert(
            ClipboardPacket(kind: ClipType.detect(text).clipboardKind, text: text),
            fromDeviceId: fromDeviceId,
            isLocal: isLocal
        )
    }

    func insert(
        _ packet: ClipboardPacket,
        fromDeviceId: String,
        isLocal: Bool,
        id: UUID = UUID(),
        receivedAt: Date = Date(),
        isSaved: Bool = false
    ) {
        let ctx = container.mainContext
        let timestampMs = Int64(receivedAt.timeIntervalSince1970 * 1000)
        guard HistoryMutationStore.accepts(
            messageId: id.uuidString,
            fromDeviceId: fromDeviceId,
            timestampMs: timestampMs
        ) else { return }
        if packet.kind == .image {
            let imageData = packet.imageData
            let imageKind = ClipboardKind.image.rawValue
            let descriptor = FetchDescriptor<ClipboardItem>(
                predicate: #Predicate { $0.kindRaw == imageKind && $0.imageData == imageData }
            )
            if ((try? ctx.fetchCount(descriptor)) ?? 0) > 0 {
                return
            }
        }

        let item = ClipboardItem(
            id: id,
            text: packet.text,
            kindRaw: packet.kind.rawValue,
            imageData: packet.imageData,
            fileMetadataData: packet.file.flatMap { try? JSONEncoder().encode($0) },
            receivedAt: receivedAt,
            fromDeviceId: fromDeviceId,
            isLocal: isLocal,
            isSaved: isSaved
        )
        ctx.insert(item)
        evictOldItems(ctx: ctx)
        try? ctx.save()
        if !isLocal {
            Task { @MainActor in UnreadStore.shared.markUnread() }
        }
    }

    func mergeHistoryItem(
        _ packet: ClipboardPacket,
        fromDeviceId: String,
        receivedAt: Date,
        messageId: String
    ) {
        let ctx = container.mainContext
        let timestampMs = Int64(receivedAt.timeIntervalSince1970 * 1000)
        guard HistoryMutationStore.accepts(
            messageId: messageId,
            fromDeviceId: fromDeviceId,
            timestampMs: timestampMs
        ) else { return }
        if let uuid = UUID(uuidString: messageId) {
            let descriptor = FetchDescriptor<ClipboardItem>(
                predicate: #Predicate { $0.id == uuid }
            )
            if ((try? ctx.fetchCount(descriptor)) ?? 0) > 0 { return }
        }

        let alreadyMerged: Bool
        if packet.kind == .image {
            let imageData = packet.imageData
            let imageKind = ClipboardKind.image.rawValue
            let descriptor = FetchDescriptor<ClipboardItem>(
                predicate: #Predicate { $0.kindRaw == imageKind && $0.imageData == imageData }
            )
            alreadyMerged = ((try? ctx.fetchCount(descriptor)) ?? 0) > 0
        } else {
            let text = packet.text
            let kind = packet.kind.rawValue
            let earliest = receivedAt.addingTimeInterval(-2)
            let latest = receivedAt.addingTimeInterval(2)
            let descriptor = FetchDescriptor<ClipboardItem>(
                predicate: #Predicate {
                    $0.fromDeviceId == fromDeviceId &&
                    $0.receivedAt >= earliest && $0.receivedAt <= latest &&
                    $0.kindRaw == kind && $0.text == text
                }
            )
            alreadyMerged = ((try? ctx.fetchCount(descriptor)) ?? 0) > 0
        }
        guard !alreadyMerged else { return }

        let item = ClipboardItem(
            id: UUID(uuidString: messageId) ?? UUID(),
            text: packet.text,
            kindRaw: packet.kind.rawValue,
            imageData: packet.imageData,
            fileMetadataData: packet.file.flatMap { try? JSONEncoder().encode($0) },
            receivedAt: receivedAt,
            fromDeviceId: fromDeviceId,
            isLocal: fromDeviceId == AirclipIdentity.shared.deviceId
        )
        ctx.insert(item)
        evictOldItems(ctx: ctx)
        try? ctx.save()
    }

    func clearAll() {
        let ctx = container.mainContext
        let descriptor = FetchDescriptor<ClipboardItem>()
        if let all = try? ctx.fetch(descriptor) {
            all.forEach { ctx.delete($0) }
        }
        try? ctx.save()
    }

    func delete(messageId: String, fromDeviceId: String, timestampMs: Int64) {
        let ctx = container.mainContext
        let timestamp = TimeInterval(timestampMs) / 1000
        let cutoffStart = Date(timeIntervalSince1970: timestamp - 2)
        let cutoffEnd = Date(timeIntervalSince1970: timestamp + 2)
        let descriptor = FetchDescriptor<ClipboardItem>()
        if let items = try? ctx.fetch(descriptor) {
            items.filter {
                $0.id.uuidString == messageId ||
                    (timestampMs > 0 && $0.fromDeviceId == fromDeviceId &&
                        $0.receivedAt >= cutoffStart && $0.receivedAt <= cutoffEnd)
            }.forEach { ctx.delete($0) }
        }
        try? ctx.save()
    }

    func clear(throughMs: Int64) {
        let cutoff = Date(timeIntervalSince1970: TimeInterval(throughMs) / 1000)
        let ctx = container.mainContext
        let descriptor = FetchDescriptor<ClipboardItem>(predicate: #Predicate { $0.receivedAt <= cutoff })
        if let items = try? ctx.fetch(descriptor) { items.forEach { ctx.delete($0) } }
        try? ctx.save()
    }

    func latestPacket() -> ClipboardPacket? {
        var descriptor = FetchDescriptor<ClipboardItem>(
            sortBy: [SortDescriptor(\.receivedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try? container.mainContext.fetch(descriptor).first?.clipboardPacket
    }

    func fileItem(id: String) -> ClipboardItem? {
        let descriptor = FetchDescriptor<ClipboardItem>()
        return (try? container.mainContext.fetch(descriptor))?.first { $0.fileMetadata?.id == id }
    }

    func fileMetadata(id: String) -> FileClipMetadata? {
        fileItem(id: id)?.fileMetadata
    }

    /// Prune unsaved items older than `days` days. Saved items are retained until the user removes them.
    func pruneToRetention(days: Int) {
        let ctx = container.mainContext
        guard let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) else { return }
        let descriptor = FetchDescriptor<ClipboardItem>(
            predicate: #Predicate { $0.receivedAt < cutoff }
        )
        if let old = try? ctx.fetch(descriptor) {
            old.filter { !$0.isSaved }.forEach { ctx.delete($0) }
        }
        try? ctx.save()
    }

    // Keep at most 500 items by deleting oldest unsaved clips first. Saved clips are protected.
    private func evictOldItems(ctx: ModelContext) {
        let descriptor = FetchDescriptor<ClipboardItem>(
            sortBy: [SortDescriptor(\.receivedAt, order: .forward)]
        )
        guard let all = try? ctx.fetch(descriptor), all.count > Self.maxItems else { return }
        var remainingOverflow = all.count - Self.maxItems
        for item in all where !item.isSaved && remainingOverflow > 0 {
            ctx.delete(item)
            remainingOverflow -= 1
        }
    }
}
