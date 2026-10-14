import Sparkle
import Combine

@MainActor
final class AppUpdateController: NSObject, ObservableObject, SPUUpdaterDelegate {
    static let shared = AppUpdateController()

    @Published private(set) var updateStatus: String?

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
        updateStatus = "Checking for updates…"
        controller.updater.checkForUpdateInformation()
    }

    func updater(_ updater: SPUUpdater, mayPerform updateCheck: SPUUpdateCheck) throws {
        PrivacyAnalytics.shared.record(.updateCheck)
    }

    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        PrivacyAnalytics.shared.record(.updateAvailable)
        updateStatus = "Version \(item.displayVersionString) available"
    }

    func updaterDidNotFindUpdate(_ updater: SPUUpdater) {
        updateStatus = "Airclip is up to date"
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
            updateStatus = "Couldn’t check for updates"
        } else {
            updateStatus = "Airclip is up to date"
        }
    }

    func updater(
        _ updater: SPUUpdater,
        didFinishUpdateCycleFor updateCheck: SPUUpdateCheck,
        error: (any Error)?
    ) {
        guard let error else { return }
        if (error as NSError).code != 1001 {
            updateStatus = "Couldn’t check for updates"
        } else if updateStatus == "Checking for updates…" {
            updateStatus = "Airclip is up to date"
        }
    }
}
