import SwiftUI
import BackgroundTasks

@main
struct AirClipApp: App {
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var syncEngine  = SyncEngine.shared
    @Environment(\.scenePhase) private var scenePhase

    init() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: AppConfig.bgRefreshTaskID, using: nil
        ) { task in
            Task { @MainActor in
                await SyncEngine.shared.refreshDeviceCache()
                SyncEngine.shared.scheduleBackgroundRefresh()
                task.setTaskCompleted(success: true)
            }
            (task as? BGAppRefreshTask)?.expirationHandler = {
                task.setTaskCompleted(success: false)
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if authManager.isAuthenticated && authManager.isDeviceApproved {
                    ContentView()
                        .environmentObject(authManager)
                        .environmentObject(syncEngine)
                } else {
                    LoginView()
                        .environmentObject(authManager)
                }
            }
            .onOpenURL { url in
                handleDeepLink(url)
            }
            .modelContainer(LocalHistoryStore.shared.container)
        }
        .onChange(of: scenePhase) { phase in
            switch phase {
            case .active:
                if authManager.isDeviceApproved {
                    syncEngine.connect()
                    drainShareExtensionOutbox()
                }
            case .background:
                syncEngine.scheduleBackgroundRefresh()
            case .inactive:
                break
            @unknown default:
                break
            }
        }
    }

    // MARK: - Deep link handling

    private func handleDeepLink(_ url: URL) {
        guard url.scheme == AppConfig.urlScheme else { return }
        if url.host == "send" {
            drainShareExtensionOutbox()
        }
    }

    /// Read text queued by the Share Extension and send it.
    private func drainShareExtensionOutbox() {
        let defaults = UserDefaults(suiteName: AppConfig.appGroupID)
        let sendRequested = defaults?.bool(forKey: "widget_send_requested") ?? false
        guard sendRequested else { return }

        defaults?.removeObject(forKey: "widget_send_requested")

        if let text = defaults?.string(forKey: "share_extension_outbox"), !text.isEmpty {
            defaults?.removeObject(forKey: "share_extension_outbox")
            syncEngine.sendClipboard(text: text)
        } else {
            // Triggered from widget Send button — read current clipboard
            syncEngine.sendCurrentClipboard()
        }
    }
}
