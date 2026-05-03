import AppKit
import SwiftUI
import SwiftData

/// Owns the NSStatusItem and a borderless NSPanel that contains the entire app UI.
@MainActor
final class StatusBarController: NSObject {
    static let shared = StatusBarController()

    private var statusItem: NSStatusItem?
    private var panel: NSPanel?
    private var mainWindow: NSWindow?
    private var authWindow: NSWindow?
    private var eventMonitor: GlobalEventMonitor?

    var isPanelVisible: Bool { panel?.isVisible ?? false }

    private override init() {}

    func setup() {
        // Status bar button
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(
            systemSymbolName: "doc.on.clipboard",
            accessibilityDescription: "Ring"
        )
        item.button?.action = #selector(togglePanel)
        item.button?.target = self
        statusItem = item

        // Root SwiftUI view with SwiftData container
        let rootView = RootView()
            .modelContainer(LocalHistoryStore.shared.container)

        // Borderless, fully transparent non-activating panel
        let p = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 560),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        p.backgroundColor = .clear
        p.isOpaque = false
        p.hasShadow = false
        p.level = .popUpMenu
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        p.isMovableByWindowBackground = false

        let hc = NSHostingController(rootView: rootView)
        hc.view.wantsLayer = true
        hc.view.layer?.backgroundColor = .clear
        p.contentViewController = hc
        panel = p

        // Dismiss on outside clicks — post notification so cards animate out first
        eventMonitor = GlobalEventMonitor(mask: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            if self?.isPanelVisible == true {
                NotificationCenter.default.post(name: .panelWillClose, object: nil)
            }
        }

        // Listen for "See All" → open main window
        NotificationCenter.default.addObserver(
            forName: .openMainWindow,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.openMainWindow() }
        }

        // Listen for auth completion → close auth window
        NotificationCenter.default.addObserver(
            forName: .authDidComplete,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.authWindow?.close()
                self?.authWindow = nil
            }
        }

        // Open auth window immediately if not yet authenticated
        let auth = AuthManager.shared
        if !auth.isAuthenticated || !auth.isDeviceApproved {
            openAuthWindow()
        }
    }

    private func openMainWindow() {
        // Bring existing window to front if already open
        if let existing = mainWindow, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 620),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        win.center()
        win.title = "Ring"
        win.minSize = NSSize(width: 680, height: 520)
        win.contentView = NSHostingView(
            rootView: MainWindowView()
                .modelContainer(LocalHistoryStore.shared.container)
        )
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        mainWindow = win
    }

    private func openAuthWindow() {
        if let existing = authWindow, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 520),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        win.center()
        win.title = "Ring"
        win.isMovableByWindowBackground = true
        win.contentView = NSHostingView(rootView: OnboardingView())
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        authWindow = win
    }

    @objc private func togglePanel() {
        let auth = AuthManager.shared
        guard auth.isAuthenticated && auth.isDeviceApproved else {
            openAuthWindow()
            return
        }
        if isPanelVisible { closePopover() } else { openPopover() }
    }

    func openPopover() {
        guard let button = statusItem?.button, let panel = panel else { return }

        // Resolve button's exact rect in screen coordinates
        let buttonInWindow = button.convert(button.bounds, to: nil)
        let buttonOnScreen: NSRect
        if let win = button.window {
            buttonOnScreen = win.convertToScreen(buttonInWindow)
        } else {
            // Fallback: top-right area of main screen
            let s = NSScreen.main?.frame ?? .zero
            buttonOnScreen = NSRect(x: s.maxX - 40, y: s.maxY - 24, width: 24, height: 24)
        }

        let panelW: CGFloat = 300
        let panelH: CGFloat = 560
        let gap: CGFloat    = 8

        var x = (buttonOnScreen.midX - panelW / 2).rounded()
        let y = (buttonOnScreen.minY - panelH - gap).rounded()

        // Clamp horizontally so panel never leaves the screen
        let screen = NSScreen.screens.first { $0.frame.contains(NSPoint(x: buttonOnScreen.midX, y: buttonOnScreen.midY)) }
                     ?? NSScreen.main
        if let s = screen {
            x = max(s.frame.minX + 8, min(x, s.frame.maxX - panelW - 8))
        }

        panel.setFrame(NSRect(x: x, y: y, width: panelW, height: panelH), display: false)

        // Notify cards to re-run entrance animations
        NotificationCenter.default.post(name: .panelWillOpen, object: nil)

        // Fade + scale in
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.20
            ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.25, 0.46, 0.45, 0.94)
            panel.animator().alphaValue = 1.0
        }

        eventMonitor?.start()
    }

    func closePopover() {
        guard let panel = panel else { return }
        eventMonitor?.stop()
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.14
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak panel] in
            panel?.orderOut(nil)
            panel?.alphaValue = 1   // restore for next open
        })
    }
}

// MARK: - Global mouse-event monitor

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

// MARK: - Root view

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
