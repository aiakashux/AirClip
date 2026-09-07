import Foundation
import SwiftData

enum HistoryRetentionPolicy {
    static let labels = ["1 day", "3 days", "7 days", "15 days", "30 days", "No time limit (500)"]
    static let days = [1, 3, 7, 15, 30, 0]
    static let maxItems = 500

    static func selectedIndex(defaults: UserDefaults = .standard) -> Int {
        guard let stored = defaults.object(forKey: "historyDepth") as? Int else {
            setSelectedIndex(4, defaults: defaults)
            return 4
        }
        guard defaults.integer(forKey: "historyDepthVersion") >= 2 else {
            let migrated = [2, 4, 4, 5][min(max(stored, 0), 3)]
            setSelectedIndex(migrated, defaults: defaults)
            return migrated
        }
        return min(max(stored, 0), days.count - 1)
    }

    static func setSelectedIndex(_ index: Int, defaults: UserDefaults = .standard) {
        defaults.set(min(max(index, 0), days.count - 1), forKey: "historyDepth")
        defaults.set(2, forKey: "historyDepthVersion")
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
            let decoded = ClipType(rawValue: kindRaw) ?? ClipType.detect(text)
            return decoded == .code ? .text : decoded
        }

        var clipboardPacket: ClipboardPacket {
            ClipboardPacket(kind: clipType.clipboardKind, text: text, imageData: imageData)
        }
    }
}

enum ClipboardMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [ClipboardSchemaV1.self, ClipboardSchemaV2.self] }
    static var stages: [MigrationStage] {
        [.lightweight(fromVersion: ClipboardSchemaV1.self, toVersion: ClipboardSchemaV2.self)]
    }
}

typealias ClipboardItem = ClipboardSchemaV2.ClipboardItem

struct ClipboardItemSnapshot {
    let id: UUID
    let text: String
    let kindRaw: String
    let imageData: Data?
    let receivedAt: Date
    let fromDeviceId: String
    let isLocal: Bool
    let isSaved: Bool

    init(_ item: ClipboardItem) {
        id = item.id
        text = item.text
        kindRaw = item.kindRaw
        imageData = item.imageData
        receivedAt = item.receivedAt
        fromDeviceId = item.fromDeviceId
        isLocal = item.isLocal
        isSaved = item.isSaved
    }
}

@MainActor
final class LocalHistoryStore {
    static let shared = LocalHistoryStore()
    static let maxItems = HistoryRetentionPolicy.maxItems

    let container: ModelContainer

    private init() {
        container = Self.makeContainer(retryingAfterStoreReset: true) ?? Self.makeInMemoryContainer()
    }

    private static func makeContainer(retryingAfterStoreReset: Bool) -> ModelContainer? {
        let schema = Schema(versionedSchema: ClipboardSchemaV2.self)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(
                for: schema,
                migrationPlan: ClipboardMigrationPlan.self,
                configurations: [config]
            )
        } catch {
            guard retryingAfterStoreReset else { return nil }
            resetPersistentStore()
            return makeContainer(retryingAfterStoreReset: false)
        }
    }

    private static func makeInMemoryContainer() -> ModelContainer {
        let schema = Schema(versionedSchema: ClipboardSchemaV2.self)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try! ModelContainer(
            for: schema,
            migrationPlan: ClipboardMigrationPlan.self,
            configurations: [config]
        )
    }

    private static func resetPersistentStore() {
        let fm = FileManager.default
        guard let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }
        let storeURL = appSupport.appendingPathComponent("default.store")
        let walURL = appSupport.appendingPathComponent("default.store-wal")
        let shmURL = appSupport.appendingPathComponent("default.store-shm")
        [storeURL, walURL, shmURL].forEach { try? fm.removeItem(at: $0) }
    }

    func insert(text: String, fromDeviceId: String, isLocal: Bool) {
        insert(
            ClipboardPacket(kind: ClipType.detect(text).clipboardKind, text: text),
            fromDeviceId: fromDeviceId,
            isLocal: isLocal
        )
    }

    func insert(_ packet: ClipboardPacket, fromDeviceId: String, isLocal: Bool) {
        let ctx = container.mainContext
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
            text: packet.text,
            kindRaw: packet.kind.rawValue,
            imageData: packet.imageData,
            fromDeviceId: fromDeviceId,
            isLocal: isLocal
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
            receivedAt: receivedAt,
            fromDeviceId: fromDeviceId,
            isLocal: fromDeviceId == AirClipIdentity.shared.deviceId
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

    func restore(_ snapshot: ClipboardItemSnapshot) {
        let ctx = container.mainContext
        let id = snapshot.id
        let descriptor = FetchDescriptor<ClipboardItem>(predicate: #Predicate { $0.id == id })
        guard ((try? ctx.fetchCount(descriptor)) ?? 0) == 0 else { return }
        ctx.insert(ClipboardItem(
            id: snapshot.id,
            text: snapshot.text,
            kindRaw: snapshot.kindRaw,
            imageData: snapshot.imageData,
            receivedAt: snapshot.receivedAt,
            fromDeviceId: snapshot.fromDeviceId,
            isLocal: snapshot.isLocal,
            isSaved: snapshot.isSaved
        ))
        try? ctx.save()
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
