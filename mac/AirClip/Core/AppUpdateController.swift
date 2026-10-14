import Sparkle

@MainActor
final class AppUpdateController: NSObject, SPUUpdaterDelegate {
    static let shared = AppUpdateController()

    private var controller: SPUStandardUpdaterController!

    private override init() {
        super.init()
        controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: self,
            userDriverDelegate: nil
        )
    }

    func checkForUpdates() {
        controller.checkForUpdates(nil)
    }

    func updater(_ updater: SPUUpdater, mayPerform updateCheck: SPUUpdateCheck) throws {
        PrivacyAnalytics.shared.record(.updateCheck)
    }

    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        PrivacyAnalytics.shared.record(.updateAvailable)
    }

    func updater(
        _ updater: SPUUpdater,
        userDidMake choice: SPUUserUpdateChoice,
        forUpdate item: SUAppcastItem,
        state: SPUUserUpdateState
    ) {
        if choice == .install { PrivacyAnalytics.shared.record(.updateOpened) }
    }

    func updater(_ updater: SPUUpdater, didAbortWithError error: any Error) {
        if (error as NSError).code != 1001 { // Sparkle's documented SUNoUpdateError.
            PrivacyAnalytics.shared.record(.updateFailure)
        }
    }
}
