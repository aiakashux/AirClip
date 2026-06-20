import Foundation

@main
struct AddDevicePairingSheetControllerCheck {
    @MainActor
    static func main() {
        let controller = AddDevicePairingSheetController()

        precondition(!controller.didPairDevice)
        precondition(!controller.shouldDismiss)

        controller.handlePairSuccess()

        precondition(controller.didPairDevice)
        precondition(controller.shouldDismiss)

        controller.reset()

        precondition(!controller.didPairDevice)
        precondition(!controller.shouldDismiss)
    }
}
