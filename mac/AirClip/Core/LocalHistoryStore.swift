import Foundation
import SwiftData

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

enum ClipboardMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [ClipboardSchemaV1.self, ClipboardSchemaV2.self] }
    static var stages: [MigrationStage] {
        [.lightweight(fromVersion: ClipboardSchemaV1.self, toVersion: ClipboardSchemaV2.self)]
    }
}

typealias ClipboardItem = ClipboardSchemaV2.ClipboardItem

@MainActor
final class LocalHistoryStore {
    static let shared = LocalHistoryStore()

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

    func clearAll() {
        let ctx = container.mainContext
        let descriptor = FetchDescriptor<ClipboardItem>()
        if let all = try? ctx.fetch(descriptor) {
            all.forEach { ctx.delete($0) }
        }
        try? ctx.save()
    }

    /// Prune items older than `days` days. Called when user changes history retention setting.
    func pruneToRetention(days: Int) {
        let ctx = container.mainContext
        guard let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) else { return }
        let descriptor = FetchDescriptor<ClipboardItem>(
            predicate: #Predicate { $0.receivedAt < cutoff }
        )
        if let old = try? ctx.fetch(descriptor) {
            old.forEach { ctx.delete($0) }
        }
        try? ctx.save()
    }

    // Keep at most 100 items, deleting oldest first.
    private func evictOldItems(ctx: ModelContext) {
        let descriptor = FetchDescriptor<ClipboardItem>(
            sortBy: [SortDescriptor(\.receivedAt, order: .forward)]
        )
        guard let all = try? ctx.fetch(descriptor), all.count > 100 else { return }
        all.prefix(all.count - 100).forEach { ctx.delete($0) }
    }
}
