import AppIntents
import UIKit
import WidgetKit

/// Widget button: paste the last received clip back to the iOS clipboard.
struct PasteClipIntent: AppIntent {
    static var title: LocalizedStringResource = "Paste Last Clip"
    static var description = IntentDescription("Paste the most recently received clip to the clipboard.")

    func perform() async throws -> some IntentResult {
        let text = WidgetSharedState.lastText
        guard !text.isEmpty else { return .result() }
        UIPasteboard.general.string = text
        WidgetSharedState.save(state: .synced)
        return .result()
    }
}

/// Widget button: queue current clipboard for sending when app opens.
///
/// The Share Extension / app is the only place clipboard *reads* are reliable on iOS.
/// This intent writes a send-request flag; the app processes it on next foreground.
struct SendClipIntent: AppIntent {
    static var title: LocalizedStringResource = "Send Clipboard"
    static var description = IntentDescription("Send the current clipboard to AirClip peers.")

    @MainActor
    func perform() async throws -> some IntentResult {
        // Mark pending outbox — SyncEngine drains on next app foreground
        UserDefaults(suiteName: AppConfig.appGroupID)?.set(true, forKey: "widget_send_requested")
        WidgetSharedState.save(state: .readyToSend)

        // Open the main app to complete the send (clipboard read requires foreground)
        if let url = URL(string: "\(AppConfig.urlScheme)://send") {
            UIApplication.shared.open(url)
        }
        return .result()
    }
}
