import Combine
import Foundation

@MainActor
final class AddDevicePairingSheetController: ObservableObject {
    @Published private(set) var didPairDevice = false
    @Published private(set) var shouldDismiss = false

    func reset() {
        didPairDevice = false
        shouldDismiss = false
    }

    func handlePairSuccess() {
        didPairDevice = true
        shouldDismiss = true
    }
}
