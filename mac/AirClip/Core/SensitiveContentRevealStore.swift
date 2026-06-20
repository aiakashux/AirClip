import Combine
import Foundation

@MainActor
final class SensitiveContentRevealStore: ObservableObject {
    static let shared = SensitiveContentRevealStore()

    @Published private var revealedItemIDs: Set<UUID> = []

    private init() {}

    func isRevealed(_ itemID: UUID) -> Bool {
        revealedItemIDs.contains(itemID)
    }

    func setRevealed(_ revealed: Bool, for itemID: UUID) {
        if revealed {
            revealedItemIDs.insert(itemID)
        } else {
            revealedItemIDs.remove(itemID)
        }
    }

    func toggle(_ itemID: UUID) {
        setRevealed(!isRevealed(itemID), for: itemID)
    }
}
