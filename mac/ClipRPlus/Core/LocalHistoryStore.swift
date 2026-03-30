import Foundation
import SwiftData

@Model
final class ClipboardItem {
    var id: UUID
    var text: String
    var receivedAt: Date
    var fromDeviceId: String
    var isLocal: Bool

    init(
        id: UUID = UUID(),
        text: String,
        receivedAt: Date = Date(),
        fromDeviceId: String,
        isLocal: Bool
    ) {
        self.id = id
        self.text = text
        self.receivedAt = receivedAt
        self.fromDeviceId = fromDeviceId
        self.isLocal = isLocal
    }
}

@MainActor
final class LocalHistoryStore {
    static let shared = LocalHistoryStore()

    let container: ModelContainer

    private init() {
        let schema = Schema([ClipboardItem.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("SwiftData init failed: \(error)")
        }
    }

    func insert(text: String, fromDeviceId: String, isLocal: Bool) {
        let ctx = container.mainContext
        let item = ClipboardItem(text: text, fromDeviceId: fromDeviceId, isLocal: isLocal)
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

    // Keep at most 20 items, deleting oldest first.
    private func evictOldItems(ctx: ModelContext) {
        let descriptor = FetchDescriptor<ClipboardItem>(
            sortBy: [SortDescriptor(\.receivedAt, order: .forward)]
        )
        guard let all = try? ctx.fetch(descriptor), all.count > 20 else { return }
        all.prefix(all.count - 20).forEach { ctx.delete($0) }
    }
}
