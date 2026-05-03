import SwiftUI
import SwiftData
import AppKit

// ClipType is defined in ClipTypeDetector.swift

// MARK: - Popover View

struct PopoverView: View {
    @Query(sort: \ClipboardItem.receivedAt, order: .reverse) private var allItems: [ClipboardItem]

    @State private var showToast = false
    @State private var isExiting = false
    @State private var animationSession = 0

    @State private var seeAllHovered  = false
    @State private var settingsHovered = false

    private var recentItems: [ClipboardItem] { Array(allItems.prefix(5)) }

    var body: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                cardSection
                footerBar
            }
            .padding(12)

            if showToast {
                toastView
                    .padding(.top, 8)
                    .zIndex(10)
            }
        }
        .frame(width: 300)
        .background(Color.clear)
        .onReceive(NotificationCenter.default.publisher(for: .panelWillOpen)) { _ in
            isExiting = false
            showToast = false
            animationSession &+= 1
        }
        .onReceive(NotificationCenter.default.publisher(for: .panelWillClose)) { _ in
            dismissWithAnimation()
        }
    }

    // MARK: - Cards

    private var cardSection: some View {
        VStack(spacing: 4) {
            if recentItems.isEmpty {
                emptyState
            } else {
                ForEach(Array(recentItems.enumerated()), id: \.element.id) { idx, item in
                    ClipCard(
                        item: item,
                        entranceDelay: Double(idx) * 0.038,
                        isExiting: isExiting,
                        exitDelay: Double(idx) * 0.026
                    ) {
                        handleCardTap(item: item)
                    }
                    .id("\(item.id)-\(animationSession)")
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        Color.clear
            .frame(height: 1)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    StatusBarController.shared.closePopover()
                    NotificationCenter.default.post(name: .openMainWindow, object: nil)
                }
            }
    }

    // MARK: - Footer

    private var footerBar: some View {
        HStack(spacing: 8) {
            // See All
            Button {
                dismissWithAnimation {
                    NotificationCenter.default.post(name: .openMainWindow, object: nil)
                }
            } label: {
                Text("See All")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.white.opacity(0.85))
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
                    .background(footerButtonBg)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule().strokeBorder(
                            seeAllHovered ? Color.white.opacity(0.22) : Color.white.opacity(0.08),
                            lineWidth: 0.5
                        )
                    )
                    .animation(.spring(response: 0.28, dampingFraction: 0.82), value: seeAllHovered)
            }
            .buttonStyle(FooterPressStyle())
            .onHover { h in
                seeAllHovered = h
                if h { NSCursor.pointingHand.set() } else { NSCursor.arrow.set() }
            }

            // Settings
            Button {
                dismissWithAnimation { openSettingsWindow() }
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(.white.opacity(0.80))
                    .frame(width: 36, height: 36)
                    .background(footerButtonBg)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule().strokeBorder(
                            settingsHovered ? Color.white.opacity(0.22) : Color.white.opacity(0.08),
                            lineWidth: 0.5
                        )
                    )
                    .animation(.spring(response: 0.28, dampingFraction: 0.82), value: settingsHovered)
            }
            .buttonStyle(FooterPressStyle())
            .onHover { h in
                settingsHovered = h
                if h { NSCursor.pointingHand.set() } else { NSCursor.arrow.set() }
            }
        }
        .padding(.top, 8)
    }

    /// Figma: rgba(35,35,36,0.98) — dark near-opaque pill
    private var footerButtonBg: some View {
        Color(red: 35/255, green: 35/255, blue: 36/255).opacity(0.98)
    }

    // MARK: - Toast

    private var toastView: some View {
        HStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(Color.encryptedGreen)
                    .frame(width: 14, height: 14)
                Image(systemName: "checkmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.white)
            }
            Text("Copied to clipboard")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.textPrimary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Color.bgFloating)
                .overlay(Capsule().strokeBorder(Color.borderDefault, lineWidth: 0.5))
                .shadow(color: .black.opacity(0.40), radius: 12, x: 0, y: 4)
        )
        .transition(.asymmetric(
            insertion: .move(edge: .top)
                .combined(with: .opacity)
                .combined(with: .scale(scale: 0.88)),
            removal: .opacity.combined(with: .scale(scale: 0.92))
        ))
    }

    // MARK: - Actions

    /// Animate cards out, optionally run an action, then close the panel.
    private func dismissWithAnimation(then action: (() -> Void)? = nil) {
        guard !isExiting else { return }
        withAnimation { isExiting = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.48) {
            action?()
            StatusBarController.shared.closePopover()
        }
    }

    private func handleCardTap(item: ClipboardItem) {
        ClipboardMonitor.shared.suppressNextChange()
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(item.text, forType: .string)

        withAnimation(.interpolatingSpring(stiffness: 420, damping: 28)) {
            showToast = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            withAnimation { isExiting = true }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.72) {
            StatusBarController.shared.closePopover()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.30) {
                showToast = false
                isExiting = false
            }
        }
    }

    private func openSettingsWindow() {
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 560),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        win.center()
        win.title = "Ring — Settings"
        win.contentView = NSHostingView(rootView: SettingsView())
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

// MARK: - Footer button press style (spring scale + brightness, no opacity change)

private struct FooterPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .brightness(configuration.isPressed ? -0.05 : 0)
            .animation(.spring(response: 0.22, dampingFraction: 0.58), value: configuration.isPressed)
    }
}

// MARK: - Clip Card

private struct ClipCard: View {
    let item: ClipboardItem
    let entranceDelay: Double
    let isExiting: Bool
    let exitDelay: Double
    let onTap: () -> Void

    @State private var yOffset: CGFloat = -14
    @State private var cardScale: CGFloat = 0.95
    @State private var opacity: Double = 0
    @State private var isHovered = false

    private var type: ClipType { ClipType.detect(item.text) }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                metaRow
                contentView
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(cardGradient)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(
                        isHovered
                            ? Color.white.opacity(0.28)
                            : Color.white.opacity(0.08),
                        lineWidth: 0.5
                    )
                    .animation(.spring(response: 0.25, dampingFraction: 0.80), value: isHovered)
            )
        }
        .buttonStyle(CardPressStyle())
        .onHover { hovering in
            isHovered = hovering
            if hovering { NSCursor.pointingHand.set() } else { NSCursor.arrow.set() }
        }
        .offset(y: yOffset)
        .scaleEffect(cardScale)
        .opacity(opacity)
        .onAppear { animateIn() }
        .onChange(of: isExiting) { _, exiting in
            if exiting { animateOut() }
        }
    }

    private var cardGradient: some View {
        LinearGradient(
            colors: [
                Color(red: 0.0576, green: 0.0584, blue: 0.0600).opacity(0.98),
                Color(red: 0.0960, green: 0.0980, blue: 0.1000).opacity(0.98)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var metaRow: some View {
        HStack(spacing: 8) {
            Text(item.receivedAt, format: .dateTime.hour().minute())
                .font(.system(size: 10))
                .foregroundColor(Color(white: 0.40))

            Rectangle()
                .fill(Color(white: 0.40).opacity(0.70))
                .frame(width: 0.5, height: 8)

            Text(item.isLocal ? "This Mac" : "Remote device")
                .font(.system(size: 10))
                .foregroundColor(Color(white: 0.36))
        }
    }

    @ViewBuilder
    private var contentView: some View {
        switch type {
        case .url:
            Text(item.text)
                .font(.system(size: 11))
                .foregroundColor(Color.syncBlue)
                .underline()
                .lineLimit(2)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)

        case .code:
            Text(item.text)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(Color.encryptedGreen.opacity(0.95))
                .lineLimit(4)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)

        case .color:
            HStack(spacing: 12) {
                Text(item.text)
                    .font(.system(size: 22, design: .monospaced))
                    .foregroundColor(.white.opacity(0.85))
                    .lineLimit(1)
                Spacer()
                RoundedRectangle(cornerRadius: 10)
                    .fill(parsedColor ?? Color.accent)
                    .frame(width: 48, height: 48)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(.white.opacity(0.15), lineWidth: 0.5)
                    )
            }

        case .text:
            Text(item.text)
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.85))
                .lineLimit(4)
                .lineSpacing(2)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var parsedColor: Color? {
        var hex = item.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard hex.hasPrefix("#") else { return nil }
        hex = String(hex.dropFirst())
        if hex.count == 3 { hex = hex.map { "\($0)\($0)" }.joined() }
        guard hex.count == 6 || hex.count == 8 else { return nil }
        var rgb: UInt64 = 0
        guard Scanner(string: hex).scanHexInt64(&rgb) else { return nil }
        return Color(
            red:   Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8)  & 0xFF) / 255,
            blue:  Double(rgb         & 0xFF) / 255
        )
    }

    // MARK: - Entrance — single spring, slight natural overshoot built in

    private func animateIn() {
        DispatchQueue.main.asyncAfter(deadline: .now() + entranceDelay) {
            // response: how fast; dampingFraction < 1 = small organic bounce at rest
            withAnimation(.spring(response: 0.48, dampingFraction: 0.70)) {
                yOffset    = 0
                cardScale  = 1.0
                opacity    = 1
            }
        }
    }

    // MARK: - Exit — critically-damped spring: accelerates away, no bounce

    private func animateOut() {
        DispatchQueue.main.asyncAfter(deadline: .now() + exitDelay) {
            withAnimation(.spring(response: 0.30, dampingFraction: 0.92)) {
                yOffset   = -18
                cardScale = 0.93
                opacity   = 0
            }
        }
    }
}

// MARK: - Card press style (spring scale + brightness, not opacity)

private struct CardPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .brightness(configuration.isPressed ? -0.04 : 0)
            .animation(.spring(response: 0.20, dampingFraction: 0.60), value: configuration.isPressed)
    }
}

// MARK: - Connection Badge (kept for future main window use)

struct ConnectionBadge: View {
    let isConnected: Bool
    @State private var dotOpacity: Double = 1.0

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(isConnected ? Color.syncBlue : Color.warningYellow)
                .frame(width: 6, height: 6)
                .opacity(dotOpacity)
                .onAppear { startPulseIfNeeded() }
                .onChange(of: isConnected) { _, _ in startPulseIfNeeded() }

            Text(isConnected ? "Live" : "Offline")
                .font(.ringCaption)
                .foregroundColor(.textSecondary)
        }
    }

    private func startPulseIfNeeded() {
        dotOpacity = 1.0
        guard isConnected else { return }
        withAnimation(.ringPulse.repeatForever(autoreverses: true)) {
            dotOpacity = 0.35
        }
    }
}

// MARK: - Notification names

extension Notification.Name {
    static let openMainWindow = Notification.Name("com.ring.openMainWindow")
    static let panelWillOpen  = Notification.Name("com.ring.panelWillOpen")
    static let panelWillClose = Notification.Name("com.ring.panelWillClose")
    static let authDidComplete = Notification.Name("com.ring.authDidComplete")
}
