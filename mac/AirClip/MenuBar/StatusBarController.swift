import AppKit
import SwiftUI
import SwiftData
import Combine
import Carbon

private final class MainWindowTitlebarLogo: NSTitlebarAccessoryViewController {
    override func loadView() {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 80, height: 36))
        let logo = NSImageView()
        logo.image = NSImage(named: "TitlebarLogoWordmark")
        logo.imageScaling = .scaleProportionallyDown
        logo.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(logo)

        NSLayoutConstraint.activate([
            container.widthAnchor.constraint(equalToConstant: 80),
            container.heightAnchor.constraint(equalToConstant: 36),
            logo.widthAnchor.constraint(equalToConstant: 63),
            logo.heightAnchor.constraint(equalToConstant: 16),
            logo.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -14),
            logo.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])

        view = container
        layoutAttribute = .right
    }
}

private final class MainWindowTitlebarSeparator: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

/// Owns the NSStatusItem and a borderless NSPanel that contains the entire app UI.
@MainActor
final class StatusBarController: NSObject {
    static let shared = StatusBarController()
    private static let mainWindowSize = NSSize(width: 940, height: 674)
    private static let popoverPanelSize = NSSize(width: 372, height: 560)

    private var statusItem: NSStatusItem?
    private var panel: NSPanel?
    private var mainWindow: NSWindow?
    private var menuBarIconShowsUnread = false
    private var eventMonitor: GlobalEventMonitor?
    private var desktopOpenWorkItem: DispatchWorkItem?
    private var activeSpaceObserver: NSObjectProtocol?
    private var unreadObserver: AnyCancellable?
    private var openHotKey: EventHotKeyRef?
    private var popoverHotKey: EventHotKeyRef?
    private var hotKeyHandler: EventHandlerRef?
    private var hotKeyObserver: AnyCancellable?
    private var popoverHotKeyObserver: AnyCancellable?

    var isPanelVisible: Bool { panel?.isVisible ?? false }

    private override init() {}

    func setup() {
        // Status bar button
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let initiallyUnread = UnreadStore.shared.hasUnread
        menuBarIconShowsUnread = initiallyUnread
        let initialIcon = NSImage(named: initiallyUnread ? "menubar-unread" : "menubar-default")
        initialIcon?.isTemplate = true
        item.button?.image = initialIcon
        item.button?.image?.accessibilityDescription = initiallyUnread ? "Airclip – New items" : "Airclip"
        item.button?.action = #selector(togglePanel)
        item.button?.target = self
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        statusItem = item
        installPasteHotKeyHandler()
        hotKeyObserver = PasteShortcutStore.shared.$shortcut
            .sink { [weak self] _ in self?.updatePasteHotKeyRegistration() }
        popoverHotKeyObserver = PasteShortcutStore.popover.$shortcut
            .sink { [weak self] _ in self?.updatePopoverHotKeyRegistration() }

        unreadObserver = UnreadStore.shared.$hasUnread.sink { [weak self] hasUnread in
            self?.updateMenuBarIcon(hasUnread: hasUnread)
        }

        // Root SwiftUI view with SwiftData container
        let rootView = RootView()
            .modelContainer(LocalHistoryStore.shared.container)

        // Borderless, fully transparent non-activating panel
        let p = NSPanel(
            contentRect: NSRect(origin: .zero, size: Self.popoverPanelSize),
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
        if !AirclipIdentity.shared.isPaired {
            openMainWindow()
        } else {
            SyncModeStore.shared.applyRuntimePolicy()
        }
    }

    private func updateMenuBarIcon(hasUnread: Bool) {
        guard menuBarIconShowsUnread != hasUnread,
              let button = statusItem?.button else { return }
        menuBarIconShowsUnread = hasUnread

        let image = NSImage(named: hasUnread ? "menubar-unread" : "menubar-default")
        image?.isTemplate = true

        if !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            button.wantsLayer = true
            let transition = CATransition()
            transition.type = .fade
            transition.duration = 0.22
            transition.timingFunction = CAMediaTimingFunction(controlPoints: 0.25, 0.46, 0.45, 0.94)
            button.layer?.add(transition, forKey: "airclip.menuBarIconCrossfade")
        }

        button.image = image
        button.image?.accessibilityDescription = hasUnread ? "Airclip – New items" : "Airclip"
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

    private func installPasteHotKeyHandler() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, context in
                guard let context else { return OSStatus(eventNotHandledErr) }
                let controller = Unmanaged<StatusBarController>
                    .fromOpaque(context)
                    .takeUnretainedValue()
                var hotKeyID = EventHotKeyID()
                GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                Task { @MainActor in
                    hotKeyID.id == 2 ? controller.togglePopoverFromShortcut() : controller.pasteLatestItem()
                }
                return noErr
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &hotKeyHandler
        )

    }

    private func updatePasteHotKeyRegistration() {
        if let openHotKey {
            UnregisterEventHotKey(openHotKey)
            self.openHotKey = nil
        }

        guard let shortcut = PasteShortcutStore.shared.shortcut else { return }
        let hotKeyID = EventHotKeyID(signature: 0x41434C50, id: 1) // ACLP
        RegisterEventHotKey(
            shortcut.keyCode,
            shortcut.modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &openHotKey
        )
    }

    private func updatePopoverHotKeyRegistration() {
        if let popoverHotKey {
            UnregisterEventHotKey(popoverHotKey)
            self.popoverHotKey = nil
        }

        guard let shortcut = PasteShortcutStore.popover.shortcut else { return }
        let hotKeyID = EventHotKeyID(signature: 0x41434C50, id: 2)
        RegisterEventHotKey(
            shortcut.keyCode,
            shortcut.modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &popoverHotKey
        )
    }

    private func pasteLatestItem() {
        guard let packet = LocalHistoryStore.shared.latestPacket() else {
            NSSound.beep()
            return
        }
        guard CGPreflightPostEventAccess() || CGRequestPostEventAccess() else {
            NSSound.beep()
            return
        }
        ClipboardMonitor.shared.suppressPacket(packet)
        ClipboardCapture.write(packet, to: .general)

        guard let source = CGEventSource(stateID: .hidSystemState),
              let keyDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: false) else {
            NSSound.beep()
            return
        }
        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
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
        win.toolbarStyle = .unifiedCompact
        win.titlebarSeparatorStyle = .none
        win.backgroundColor = MainWindowChromePalette.nsShell
        win.isOpaque = false
        win.isMovableByWindowBackground = true
        win.isReleasedWhenClosed = false
        win.collectionBehavior = [.managed, .fullScreenNone]
        win.contentMinSize = windowSize
        win.contentMaxSize = windowSize
        for button in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
            win.standardWindowButton(button)?.controlSize = .regular
        }
        let hostingView = NSHostingView(
            rootView: WindowRootView(size: windowSize)
                .modelContainer(LocalHistoryStore.shared.container)
        )
        hostingView.frame = NSRect(origin: .zero, size: windowSize)
        win.contentView = hostingView
        let titlebarLogo = MainWindowTitlebarLogo()
        win.addTitlebarAccessoryViewController(titlebarLogo)
        win.makeKeyAndOrderFront(nil)
        positionMainWindowTrafficLights(in: win)
        installMainWindowTitlebarSeparator(in: win)
        NSApp.activate(ignoringOtherApps: true)
        mainWindow = win
    }

    private func installMainWindowTitlebarSeparator(in window: NSWindow) {
        guard let titlebar = window.standardWindowButton(.closeButton)?.superview else { return }
        let separator = MainWindowTitlebarSeparator(
            frame: NSRect(x: 0, y: 0, width: titlebar.bounds.width, height: 1)
        )
        separator.wantsLayer = true
        separator.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.075).cgColor
        separator.autoresizingMask = [.width, .maxYMargin]
        titlebar.addSubview(separator, positioned: .above, relativeTo: nil)
    }

    private func positionMainWindowTrafficLights(in window: NSWindow) {
        let buttonTypes: [NSWindow.ButtonType] = [.closeButton, .miniaturizeButton, .zoomButton]
        let buttons = buttonTypes.compactMap(window.standardWindowButton)
        guard buttons.count == buttonTypes.count else { return }

        var leading: CGFloat = 12
        for button in buttons {
            var frame = button.frame
            frame.origin.x = leading
            if let titlebar = button.superview {
                frame.origin.y = (titlebar.bounds.height - frame.height) / 2
            }
            button.setFrameOrigin(frame.origin)
            leading += frame.width + 10
        }
    }

    @objc private func togglePanel() {
        if let event = NSApp.currentEvent, event.type == .rightMouseUp {
            showContextMenu()
            return
        }
        togglePopoverFromShortcut()
    }

    private func togglePopoverFromShortcut() {
        guard AirclipIdentity.shared.isPaired else {
            openMainWindow()
            return
        }
        if isPanelVisible { closePopover() } else { openPopover() }
    }

    private func showContextMenu() {
        let menu = NSMenu()

        let openItem = NSMenuItem(title: "Open Airclip", action: #selector(contextOpenApp), keyEquivalent: "")
        openItem.target = self
        menu.addItem(openItem)

        let settingsItem = NSMenuItem(title: "Settings", action: #selector(contextOpenSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let aboutItem = NSMenuItem(title: "About Airclip", action: #selector(contextAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit Airclip", action: #selector(contextQuit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil
    }

    @objc private func contextOpenApp() {
        if isPanelVisible { closePopover() }
        openMainWindow(onDesktopSpace: true)
    }

    func openAirclipFromNotification() {
        if isPanelVisible { closePopover() }
        openMainWindow(onDesktopSpace: true)
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .openDevicesTab, object: nil)
        }
    }

    @objc private func contextOpenSettings() {
        if isPanelVisible { closePopover() }
        openMainWindow(onDesktopSpace: true)
        NotificationCenter.default.post(name: .openSettingsTab, object: nil)
    }

    @objc private func contextAbout() {
        NSApp.orderFrontStandardAboutPanel(nil)
    }

    @objc private func contextQuit() {
        NSApp.terminate(nil)
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

        let panelW = Self.popoverPanelSize.width
        let panelH = Self.popoverPanelSize.height
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

@MainActor
final class PasteShortcutStore: ObservableObject {
    struct Shortcut: Codable, Equatable {
        let keyCode: UInt32
        let modifiers: UInt32
        let keyLabel: String

        var displayKeys: [String] {
            var keys: [String] = []
            if modifiers & UInt32(cmdKey) != 0 { keys.append("⌘") }
            if modifiers & UInt32(optionKey) != 0 { keys.append("⌥") }
            if modifiers & UInt32(controlKey) != 0 { keys.append("⌃") }
            if modifiers & UInt32(shiftKey) != 0 { keys.append("⇧") }
            return keys + [keyLabel]
        }
    }

    static let shared = PasteShortcutStore()
    static let popover = PasteShortcutStore(
        defaultsKey: "popoverToggleShortcut",
        defaultShortcut: Shortcut(keyCode: UInt32(kVK_ANSI_Grave), modifiers: UInt32(controlKey), keyLabel: "~")
    )

    @Published private(set) var shortcut: Shortcut? {
        didSet { save() }
    }

    private let defaultsKey: String
    private let allowsBareKey: Bool

    private init(
        defaultsKey: String = "pasteLatestShortcut",
        defaultShortcut: Shortcut? = nil,
        allowsBareKey: Bool = false
    ) {
        self.defaultsKey = defaultsKey
        self.allowsBareKey = allowsBareKey
        let storedShortcut = UserDefaults.standard.data(forKey: defaultsKey)
            .flatMap { try? JSONDecoder().decode(Shortcut.self, from: $0) }
        let migratePopoverShortcut = defaultsKey == "popoverToggleShortcut" &&
            storedShortcut?.keyCode == UInt32(kVK_ANSI_Grave) &&
            [UInt32(0), UInt32(shiftKey), UInt32(optionKey), UInt32(controlKey | shiftKey)].contains(storedShortcut?.modifiers ?? 0)
        shortcut = migratePopoverShortcut ? defaultShortcut : storedShortcut ?? defaultShortcut
        if migratePopoverShortcut { save() }
    }

    @discardableResult
    func set(keyCode: UInt16, modifiers: NSEvent.ModifierFlags, keyLabel: String) -> Bool {
        let flags = modifiers.intersection(.deviceIndependentFlagsMask)
        let carbonModifiers = carbonModifiers(from: flags)
        let modifierCount = [cmdKey, optionKey, controlKey, shiftKey]
            .filter { carbonModifiers & UInt32($0) != 0 }
            .count
        let validModifierCount = allowsBareKey ? (0...2) : (1...2)
        guard validModifierCount.contains(modifierCount),
              carbonModifiers & UInt32(cmdKey | controlKey) != 0,
              !keyLabel.isEmpty else { return false }
        shortcut = Shortcut(keyCode: UInt32(keyCode), modifiers: carbonModifiers, keyLabel: keyLabel)
        return true
    }

    func clear() {
        shortcut = nil
    }

    private func save() {
        guard let shortcut else {
            UserDefaults.standard.removeObject(forKey: defaultsKey)
            return
        }
        UserDefaults.standard.set(try? JSONEncoder().encode(shortcut), forKey: defaultsKey)
    }

    private func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var result: UInt32 = 0
        if flags.contains(.command) { result |= UInt32(cmdKey) }
        if flags.contains(.option) { result |= UInt32(optionKey) }
        if flags.contains(.control) { result |= UInt32(controlKey) }
        if flags.contains(.shift) { result |= UInt32(shiftKey) }
        return result
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var identity = AirclipIdentity.shared
    @ObservedObject private var appearance = AppAppearanceStore.shared

    var body: some View {
        Group {
            if identity.isPaired {
                PopoverView()
                    .transition(rootTransition)
            } else {
                OnboardingView()
                    .frame(width: 360, height: 480)
                    .transition(rootTransition)
            }
        }
        .preferredColorScheme(appearance.colorScheme)
    }

    private var rootTransition: AnyTransition {
        .asymmetric(
            insertion: .opacity.animation(reduceMotion
                ? .easeOut(duration: 0.12)
                : .timingCurve(0.23, 1, 0.32, 1, duration: 0.22)),
            removal: .opacity.animation(.easeOut(duration: reduceMotion ? 0.12 : 0.14))
        )
    }
}

// MARK: - Window root view (single window, onboarding → main routing)

struct WindowRootView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var identity = AirclipIdentity.shared
    @ObservedObject private var appearance = AppAppearanceStore.shared
    let size: NSSize

    var body: some View {
        Group {
            if identity.isPaired {
                MainWindowView()
                    .transition(rootTransition)
            } else {
                OnboardingView()
                    .transition(rootTransition)
            }
        }
        .frame(width: size.width, height: size.height)
        .background(MainWindowChromePalette.shell)
        .preferredColorScheme(appearance.colorScheme)
    }

    private var rootTransition: AnyTransition {
        .asymmetric(
            insertion: .opacity.animation(reduceMotion
                ? .easeOut(duration: 0.12)
                : .timingCurve(0.23, 1, 0.32, 1, duration: 0.22)),
            removal: .opacity.animation(.easeOut(duration: reduceMotion ? 0.12 : 0.14))
        )
    }
}

private enum MainWindowChromePalette {
    static let shell = adaptiveColor(light: "#F4F6FA", dark: "#121418").opacity(0.88)
    static let primaryText = adaptiveColor(light: "#101828", dark: "#F2F3F5")
    static let nsShell = adaptiveNSColor(light: "#F9FAFB", dark: "#101113", alpha: 1)

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
