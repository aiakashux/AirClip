import AppKit
import SwiftUI
import SwiftData
import Combine

/// Owns the NSStatusItem and a borderless NSPanel that contains the entire app UI.
@MainActor
final class StatusBarController: NSObject {
    static let shared = StatusBarController()
    private static let mainWindowSize = NSSize(width: 860, height: 558)

    private var statusItem: NSStatusItem?
    private var panel: NSPanel?
    private var mainWindow: NSWindow?
    private var eventMonitor: GlobalEventMonitor?
    private var desktopOpenWorkItem: DispatchWorkItem?
    private var activeSpaceObserver: NSObjectProtocol?
    private var unreadObserver: AnyCancellable?

    var isPanelVisible: Bool { panel?.isVisible ?? false }

    private override init() {}

    func setup() {
        // Status bar button
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let defaultIcon = NSImage(named: "menubar-default")
        defaultIcon?.isTemplate = true
        item.button?.image = defaultIcon
        item.button?.image?.accessibilityDescription = "AirClip"
        item.button?.action = #selector(togglePanel)
        item.button?.target = self
        statusItem = item

        unreadObserver = UnreadStore.shared.$hasUnread.sink { [weak self] hasUnread in
            guard let button = self?.statusItem?.button else { return }
            let imageName = hasUnread ? "menubar-unread" : "menubar-default"
            let image = NSImage(named: imageName)
            image?.isTemplate = true
            button.image = image
            button.image?.accessibilityDescription = hasUnread ? "AirClip – New items" : "AirClip"
        }

        // Root SwiftUI view with SwiftData container
        let rootView = RootView()
            .modelContainer(LocalHistoryStore.shared.container)

        // Borderless, fully transparent non-activating panel
        let p = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 324, height: 560),
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

        activeSpaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard self?.isPanelVisible == true else { return }
                NotificationCenter.default.post(name: .panelWillClose, object: nil)
            }
        }

        // Listen for "See All" → open main window
        NotificationCenter.default.addObserver(
            forName: .openMainWindow,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.openMainWindow(onDesktopSpace: true) }
        }

        // Show onboarding if not yet paired; otherwise start sync.
        if !AirClipIdentity.shared.isPaired {
            openMainWindow()
        } else {
            SyncModeStore.shared.applyRuntimePolicy()
        }
    }

    private func openMainWindow(onDesktopSpace: Bool = false) {
        if onDesktopSpace,
           let finder = NSRunningApplication.runningApplications(
               withBundleIdentifier: "com.apple.finder"
           ).first {
            desktopOpenWorkItem?.cancel()
            finder.activate(options: [])

            let workItem = DispatchWorkItem { [weak self] in
                MainActor.assumeIsolated {
                    self?.presentMainWindow()
                }
            }
            desktopOpenWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45, execute: workItem)
            return
        }

        presentMainWindow()
    }

    private func presentMainWindow() {
        // Reusing the same window preserves its assignment to the regular desktop Space.
        if let existing = mainWindow {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let windowSize = Self.mainWindowSize
        let win = NSWindow(
            contentRect: NSRect(origin: .zero, size: windowSize),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        win.center()
        win.title = ""
        win.titleVisibility = .hidden
        win.titlebarAppearsTransparent = true
        win.backgroundColor = MainWindowChromePalette.nsShell
        win.isOpaque = false
        win.isMovableByWindowBackground = true
        win.isReleasedWhenClosed = false
        win.collectionBehavior = [.managed, .fullScreenNone]
        win.contentMinSize = windowSize
        win.contentMaxSize = windowSize
        let hostingView = NSHostingView(
            rootView: WindowRootView(size: windowSize)
                .modelContainer(LocalHistoryStore.shared.container)
        )
        hostingView.frame = NSRect(origin: .zero, size: windowSize)
        win.contentView = hostingView
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        mainWindow = win
    }

    @objc private func togglePanel() {
        guard AirClipIdentity.shared.isPaired else {
            openMainWindow()
            return
        }
        if isPanelVisible { closePopover() } else { openPopover() }
    }

    func openPopover() {
        UnreadStore.shared.markRead()
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

        let panelW: CGFloat = 324
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
            ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.23, 1, 0.32, 1)
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

// MARK: - Root view (popover panel)

struct RootView: View {
    @ObservedObject private var identity = AirClipIdentity.shared
    @ObservedObject private var appearance = AppAppearanceStore.shared

    var body: some View {
        Group {
            if identity.isPaired {
                PopoverView()
            } else {
                OnboardingView()
                    .frame(width: 360, height: 480)
            }
        }
        .preferredColorScheme(appearance.colorScheme)
        .sensitiveClipboardPrompts()
    }
}

// MARK: - Window root view (single window, onboarding → main routing)

struct WindowRootView: View {
    @ObservedObject private var identity = AirClipIdentity.shared
    @ObservedObject private var appearance = AppAppearanceStore.shared
    let size: NSSize

    var body: some View {
        Group {
            if identity.isPaired {
                MainWindowView()
            } else {
                OnboardingView()
            }
        }
        .frame(width: size.width, height: size.height)
        .background(MainWindowChromePalette.shell)
        .preferredColorScheme(appearance.colorScheme)
        .sensitiveClipboardPrompts()
    }
}

private struct SensitiveClipboardPromptModifier: ViewModifier {
    @ObservedObject private var protection = SensitiveClipboardProtectionStore.shared

    func body(content: Content) -> some View {
        content
        .alert(item: Binding(
            get: { protection.prompt },
            set: { if $0 == nil { protection.dismissPrompt() } }
        )) { prompt in
            switch prompt.kind {
            case .automaticBlocked:
                return Alert(
                    title: Text("Sensitive clipboard item blocked"),
                    message: Text("\(prompt.finding.category.label) detected. AirClip kept it on this Mac."),
                    dismissButton: .default(Text("OK")) {
                        protection.dismissPrompt()
                    }
                )
            case .manualConfirmation:
                return Alert(
                    title: Text("Send sensitive clipboard item?"),
                    message: Text("\(prompt.finding.category.label) detected. Only continue if you intend to share it with your paired devices."),
                    primaryButton: .destructive(Text("Send Anyway")) {
                        protection.confirmManualSend()
                    },
                    secondaryButton: .cancel {
                        protection.dismissPrompt()
                    }
                )
            }
        }
    }
}

private extension View {
    func sensitiveClipboardPrompts() -> some View {
        modifier(SensitiveClipboardPromptModifier())
    }
}

private enum MainWindowChromePalette {
    static let shell = adaptiveColor(light: "#F4F6FA", dark: "#121418").opacity(0.88)
    static let primaryText = adaptiveColor(light: "#101828", dark: "#F2F3F5")
    static let nsShell = adaptiveNSColor(light: "#F4F6FA", dark: "#121418", alpha: 0.88)

    private static func adaptiveColor(light: String, dark: String) -> Color {
        Color(adaptiveNSColor(light: light, dark: dark, alpha: 1))
    }

    private static func adaptiveNSColor(light: String, dark: String, alpha: CGFloat) -> NSColor {
        NSColor(name: nil, dynamicProvider: { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            let hex = (isDark ? dark : light).trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
            var int: UInt64 = 0
            Scanner(string: hex).scanHexInt64(&int)
            return NSColor(
                srgbRed: CGFloat((int & 0xFF0000) >> 16) / 255,
                green: CGFloat((int & 0x00FF00) >> 8) / 255,
                blue: CGFloat(int & 0x0000FF) / 255,
                alpha: alpha
            )
        })
    }
}
