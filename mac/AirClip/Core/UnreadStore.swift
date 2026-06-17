import Foundation

@MainActor
final class UnreadStore: ObservableObject {
    static let shared = UnreadStore()
    @Published private(set) var hasUnread = false

    private init() {}

    func markUnread() {
        hasUnread = true
    }

    func markRead() {
        hasUnread = false
    }
}
