import SwiftUI
import AppKit
import UserNotifications

@main
struct AirClipApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Menu-bar-only app — no document windows.
        // An empty Settings scene satisfies the App protocol requirement.
        Settings { EmptyView() }
    }
}

// MARK: - AppDelegate

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Belt-and-suspenders alongside LSUIElement=YES
        NSApp.setActivationPolicy(.accessory)

        // Wire core components together
        ClipboardMonitor.shared.syncEngine = SyncEngine.shared
        SyncEngine.shared.clipboardMonitor = ClipboardMonitor.shared
        DeviceNotificationCoordinator.shared.configure()

        // Build the menu bar
        StatusBarController.shared.setup()

        let retentionDays = HistoryRetentionPolicy.days[HistoryRetentionPolicy.selectedIndex()]
        if retentionDays > 0 {
            LocalHistoryStore.shared.pruneToRetention(days: retentionDays)
        }

        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(recoverAfterWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )

        // StatusBarController validates any stored session before starting sync.
    }

    @MainActor @objc private func recoverAfterWake() {
        SyncModeStore.shared.recoverRuntime()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false  // keep alive when all windows are closed
    }
}

// MARK: - Device notifications

final class DeviceNotificationCoordinator: NSObject, UNUserNotificationCenterDelegate {
    static let shared = DeviceNotificationCoordinator()

    private static let categoryIdentifier = "AIRCLIP_DEVICE_AVAILABLE"
    private static let openActionIdentifier = "OPEN_AIRCLIP"
    private let notifiedDeviceIDsKey = "com.airclip.notifiedDeviceIDs.v1"

    private override init() {}

    func configure() {
        let openAction = UNNotificationAction(
            identifier: Self.openActionIdentifier,
            title: "Open AirClip",
            options: [.foreground]
        )
        let category = UNNotificationCategory(
            identifier: Self.categoryIdentifier,
            actions: [openAction],
            intentIdentifiers: [],
            options: []
        )
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.setNotificationCategories([category])
    }

    func requestAuthorizationForOnboarding() async {
        _ = await requestAuthorizationIfNeeded()
    }

    @MainActor
    func notifyDeviceAdded(_ device: PairedDevice) {
        sendDeviceNotificationIfNeeded(
            deviceID: device.deviceId,
            deviceName: device.deviceName,
            title: "New device added",
            body: "\(device.deviceName) is now part of this AirClip network."
        )
    }

    @MainActor
    func notifyDeviceConnectedOnce(_ device: PairedDevice) {
        sendDeviceNotificationIfNeeded(
            deviceID: device.deviceId,
            deviceName: device.deviceName,
            title: "Device connected",
            body: "\(device.deviceName) is now available in AirClip."
        )
    }

    private func sendDeviceNotificationIfNeeded(
        deviceID: String,
        deviceName: String,
        title: String,
        body: String
    ) {
        guard !deviceID.isEmpty else { return }
        guard !hasNotifiedDevice(deviceID) else { return }

        Task {
            let authorized = await requestAuthorizationIfNeeded()
            guard authorized else {
                markDeviceNotified(deviceID)
                return
            }

            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.categoryIdentifier = Self.categoryIdentifier
            content.interruptionLevel = .passive
            content.userInfo = [
                "deviceID": deviceID,
                "deviceName": deviceName,
            ]

            let request = UNNotificationRequest(
                identifier: "airclip-device-\(deviceID)",
                content: content,
                trigger: nil
            )

            do {
                try await UNUserNotificationCenter.current().add(request)
                markDeviceNotified(deviceID)
            } catch {
                // Notification delivery should never block device pairing or sync.
            }
        }
    }

    private func requestAuthorizationIfNeeded() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()

        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert])) ?? false
        case .denied:
            return false
        @unknown default:
            return false
        }
    }

    private func hasNotifiedDevice(_ deviceID: String) -> Bool {
        Set(UserDefaults.standard.stringArray(forKey: notifiedDeviceIDsKey) ?? []).contains(deviceID)
    }

    private func markDeviceNotified(_ deviceID: String) {
        var ids = Set(UserDefaults.standard.stringArray(forKey: notifiedDeviceIDsKey) ?? [])
        ids.insert(deviceID)
        UserDefaults.standard.set(Array(ids).sorted(), forKey: notifiedDeviceIDsKey)
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard response.actionIdentifier == UNNotificationDefaultActionIdentifier ||
              response.actionIdentifier == Self.openActionIdentifier
        else {
            return
        }

        await MainActor.run {
            StatusBarController.shared.openAirClipFromNotification()
        }
    }
}
