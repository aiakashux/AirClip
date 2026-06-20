import SwiftUI
import AppKit

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

        // Build the menu bar
        StatusBarController.shared.setup()

        // StatusBarController validates any stored session before starting sync.
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false  // keep alive when all windows are closed
    }
}
