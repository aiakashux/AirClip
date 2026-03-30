import AppKit
import SwiftUI
import SwiftData

/// Owns the NSStatusItem and the NSPopover that contains the entire app UI.
@MainActor
final class StatusBarController: NSObject {
    static let shared = StatusBarController()

    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var eventMonitor: GlobalEventMonitor?

    private override init() {}

    func setup() {
        // Create the status bar button
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(
            systemSymbolName: "doc.on.clipboard",
            accessibilityDescription: "Clipr+"
        )
        item.button?.action = #selector(togglePopover)
        item.button?.target = self
        statusItem = item

        // Build the root SwiftUI view with model container + env objects injected
        let rootView = RootView()
            .modelContainer(LocalHistoryStore.shared.container)

        let pop = NSPopover()
        pop.contentSize = NSSize(width: 360, height: 480)
        pop.behavior = .transient
        pop.contentViewController = NSHostingController(rootView: rootView)
        popover = pop

        // Dismiss popover on outside clicks
        eventMonitor = GlobalEventMonitor(mask: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            if self?.popover?.isShown == true { self?.closePopover() }
        }
    }

    @objc private func togglePopover() {
        if popover?.isShown == true { closePopover() } else { openPopover() }
    }

    private func openPopover() {
        guard let button = statusItem?.button else { return }
        popover?.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        NSApp.activate(ignoringOtherApps: true)
        eventMonitor?.start()
    }

    private func closePopover() {
        popover?.performClose(nil)
        eventMonitor?.stop()
    }
}

// MARK: - Global mouse-event monitor (dismisses popover on outside click)

final class GlobalEventMonitor {
    private var monitor: Any?
    private let mask: NSEvent.EventTypeMask
    private let handler: (NSEvent?) -> Void

    init(mask: NSEvent.EventTypeMask, handler: @escaping (NSEvent?) -> Void) {
        self.mask = mask
        self.handler = handler
    }

    func start() {
        monitor = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: handler)
    }

    func stop() {
        if let m = monitor { NSEvent.removeMonitor(m); monitor = nil }
    }
}

// MARK: - Root view (switches between onboarding and main UI)

struct RootView: View {
    @ObservedObject private var authManager = AuthManager.shared

    var body: some View {
        if authManager.isAuthenticated && authManager.isDeviceApproved {
            PopoverView()
        } else {
            OnboardingView()
                .frame(width: 360, height: 480)
        }
    }
}
