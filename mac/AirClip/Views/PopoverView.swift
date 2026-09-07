import SwiftUI
import SwiftData
import AppKit

// ClipType is defined in ClipTypeDetector.swift

// MARK: - Popover View

private enum PopoverMetrics {
    static let width: CGFloat = 324
    static let outerPadding: CGFloat = 24
    static let cardSpacing: CGFloat = 8
    static let cardRadius: CGFloat = 16
    static let cardPadding: CGFloat = 12.5
    static let footerTopPadding: CGFloat = 8
    static let footerHeight: CGFloat = 36
    static let emptyHeight: CGFloat = 132
    static let toastTopPadding: CGFloat = 8
    static let dismissDelay: Double = 0.24
    static let copyExitDelay: Double = 0.65
    static let copyCloseDelay: Double = 0.70
}

struct PopoverView: View {
    @Query(sort: \ClipboardItem.receivedAt, order: .reverse) private var allItems: [ClipboardItem]
    @ObservedObject private var syncModeStore = SyncModeStore.shared

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var showToast = false
    @State private var isExiting = false
    @State private var isContentVisible = false
    @State private var animationSession = 0
    @State private var copyFlowSession = 0

    @State private var seeAllHovered = false

    private var recentItems: [ClipboardItem] { Array(allItems.prefix(5)) }
    private var footerLabel: String { allItems.count > 5 ? "See All" : "Open App" }
    private var contentIsVisible: Bool { isContentVisible && !isExiting }

    var body: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                cardSection
                footerBar
            }
            .padding(PopoverMetrics.outerPadding)
            .offset(y: contentIsVisible ? 0 : -12)
            .scaleEffect(contentIsVisible ? 1 : 0.965, anchor: .top)
            .opacity(contentIsVisible ? 1 : 0)

            if showToast {
                toastView
                    .padding(.top, PopoverMetrics.toastTopPadding)
                    .zIndex(10)
            }
        }
        .frame(width: PopoverMetrics.width)
        .background(Color.clear)
        .onReceive(NotificationCenter.default.publisher(for: .panelWillOpen)) { _ in
            copyFlowSession &+= 1
            isExiting = false
            isContentVisible = false
            showToast = false
            animationSession &+= 1
            DispatchQueue.main.async {
                withAnimation(contentAnimation) {
                    isContentVisible = true
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .panelWillClose)) { _ in
            copyFlowSession &+= 1
            dismissWithAnimation()
        }
    }

    // MARK: - Cards

    private var cardSection: some View {
        VStack(spacing: PopoverMetrics.cardSpacing) {
            if recentItems.isEmpty {
                emptyState
                    .popoverListMotion(
                        isVisible: contentIsVisible,
                        index: 0,
                        reduceMotion: reduceMotion
                    )
            } else {
                ForEach(Array(recentItems.enumerated()), id: \.element.id) { index, item in
                    ClipCard(
                        item: item
                    ) {
                        handleCardTap(item: item)
                    }
                    .id("\(item.id)-\(animationSession)")
                    .popoverListMotion(
                        isVisible: contentIsVisible,
                        index: index,
                        reduceMotion: reduceMotion
                    )
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        AirClipFigmaEmptyState()
        .frame(maxWidth: .infinity)
        .frame(height: PopoverMetrics.emptyHeight)
        .background(
            RoundedRectangle(cornerRadius: PopoverMetrics.cardRadius, style: .continuous)
                .fill(emptyCardFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: PopoverMetrics.cardRadius, style: .continuous)
                .strokeBorder(Color.borderDefault, lineWidth: 0.5)
        )
    }

    // MARK: - Footer

    private var footerBar: some View {
        HStack(spacing: 8) {
            if syncModeStore.mode == .manualOnly {
                Button {
                    ManualClipboardSender.sendCurrentClipboard()
                } label: {
                    Label("Send Clipboard", systemImage: "paperplane.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: PopoverMetrics.footerHeight)
                        .background(Color.accent)
                        .clipShape(Capsule())
                }
                .buttonStyle(FooterPressStyle())
            }

            Button {
                dismissWithAnimation {
                    NotificationCenter.default.post(name: .openMainWindow, object: nil)
                }
            } label: {
                Text(footerLabel)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(seeAllHovered ? Color.textPrimary : Color.textSubtle)
                    .frame(maxWidth: .infinity)
                    .frame(height: PopoverMetrics.footerHeight)
                    .background(footerButtonBg)
                    .clipShape(Capsule())
                    .animation(.easeOut(duration: 0.12), value: seeAllHovered)
            }
            .buttonStyle(FooterPressStyle())
            .onHover { h in
                seeAllHovered = h
                if h { NSCursor.pointingHand.set() } else { NSCursor.arrow.set() }
            }
        }
        .padding(.top, PopoverMetrics.footerTopPadding)
        .popoverListMotion(
            isVisible: contentIsVisible,
            index: min(recentItems.count, 5),
            reduceMotion: reduceMotion
        )
    }

    private var footerButtonBg: some View {
        Capsule()
            .fill(seeAllHovered ? Color.activeFill : Color.bgFloating)
            .overlay(Capsule().strokeBorder(seeAllHovered ? Color.borderFocus : Color.borderDefault, lineWidth: 0.5))
    }

    private var emptyCardFill: Color {
        Color.bgElevated
    }

    // MARK: - Toast

    private var toastView: some View {
        HStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(Color.encryptedGreen)
                    .frame(width: 14, height: 14)
                AirClipIcon(.checkCircle, size: 8)
                    .foregroundColor(.textPrimary)
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
        )
        .transition(.asymmetric(
            insertion: .offset(y: -10)
                .combined(with: .opacity)
                .combined(with: .scale(scale: 0.94, anchor: .top)),
            removal: .offset(y: -6)
                .combined(with: .opacity)
                .combined(with: .scale(scale: 0.96, anchor: .top))
        ))
    }

    // MARK: - Actions

    /// Animate cards out, optionally run an action, then close the panel.
    private func dismissWithAnimation(then action: (() -> Void)? = nil) {
        guard !isExiting else { return }
        withAnimation(contentAnimation) {
            isContentVisible = false
            isExiting = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + (reduceMotion ? 0.01 : PopoverMetrics.dismissDelay)) {
            action?()
            StatusBarController.shared.closePopover()
        }
    }

    private func handleCardTap(item: ClipboardItem) {
        copyFlowSession &+= 1
        let activeCopyFlow = copyFlowSession

        ClipboardMonitor.shared.suppressPacket(item.clipboardPacket)
        ClipboardCapture.write(item.clipboardPacket, to: NSPasteboard.general)

        withAnimation(reduceMotion ? .easeOut(duration: 0.01) : .airClipDefault) {
            showToast = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + (reduceMotion ? 0.01 : PopoverMetrics.copyExitDelay)) {
            guard activeCopyFlow == copyFlowSession else { return }
            withAnimation(contentAnimation) {
                isContentVisible = false
                isExiting = true
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + (reduceMotion ? 0.02 : PopoverMetrics.copyCloseDelay)) {
            guard activeCopyFlow == copyFlowSession else { return }
            StatusBarController.shared.closePopover()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                guard activeCopyFlow == copyFlowSession else { return }
                showToast = false
                isContentVisible = false
                isExiting = false
            }
        }
    }

    private var contentAnimation: Animation {
        reduceMotion
            ? .easeOut(duration: 0.01)
            : .airClipEntrance
    }

}

private struct PopoverListMotionModifier: ViewModifier {
    let isVisible: Bool
    let index: Int
    let reduceMotion: Bool

    private var delay: Double {
        guard !reduceMotion, isVisible else { return 0 }
        return min(Double(index) * 0.018, 0.08)
    }

    private var animation: Animation {
        if reduceMotion {
            return .easeOut(duration: 0.01)
        }
        return Animation.airClipEntrance
            .delay(delay)
    }

    func body(content: Content) -> some View {
        content
            .offset(y: isVisible ? 0 : -10)
            .scaleEffect(isVisible ? 1 : 0.975, anchor: .top)
            .opacity(isVisible ? 1 : 0)
            .animation(animation, value: isVisible)
    }
}

private extension View {
    func popoverListMotion(isVisible: Bool, index: Int, reduceMotion: Bool) -> some View {
        modifier(PopoverListMotionModifier(
            isVisible: isVisible,
            index: index,
            reduceMotion: reduceMotion
        ))
    }
}

// MARK: - Footer button press style (spring scale + brightness, no opacity change)

private struct FooterPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.965 : 1.0)
            .brightness(configuration.isPressed ? -0.08 : 0)
            .animation(.airClipInstant(0.10), value: configuration.isPressed)
    }
}

// MARK: - Clip Card

private struct ClipCard: View {
    let item: ClipboardItem
    let onTap: () -> Void

    @ObservedObject private var revealStore = SensitiveContentRevealStore.shared
    @State private var isHovered = false

    private var type: ClipType { item.clipType }
    private var shouldRedact: Bool {
        item.clipType != .image
            && SensitiveClipboardClassifier.classify(item.text).isSensitive
            && !revealStore.isRevealed(item.id)
    }

    var body: some View {
        Button(action: onTap) {
            contentView
                .padding(PopoverMetrics.cardPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background {
                    RoundedRectangle(cornerRadius: PopoverMetrics.cardRadius)
                        .fill(isHovered ? Color.hoverFill : Color.bgElevated)
                }
                .clipShape(RoundedRectangle(cornerRadius: PopoverMetrics.cardRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: PopoverMetrics.cardRadius)
                        .strokeBorder(
                            cardBorderColor,
                            lineWidth: 0.5
                        )
                        .animation(.easeOut(duration: 0.12), value: isHovered)
                )
                .animation(.easeOut(duration: 0.16), value: isHovered)
        }
        .buttonStyle(CardPressStyle())
        .accessibilityLabel("Copy \(type.rawValue) from \(deviceName)")
        .accessibilityHint("Copies this item and closes AirClip")
        .onHover { hovering in
            isHovered = hovering
            if hovering { NSCursor.pointingHand.set() } else { NSCursor.arrow.set() }
        }
    }

    private var cardBorderColor: Color {
        isHovered ? Color.accent.opacity(0.30) : Color.borderSubtle
    }

    private var primaryTextColor: Color {
        .textPrimary
    }

    private var metaTextColor: Color {
        .textSecondary
    }

    private var linkTextColor: Color {
        .textLink
    }

    private var codeTextColor: Color {
        .textSubtle
    }

    private var iconContainerBorderColor: Color {
        .borderSubtle
    }

    private var imageBorderColor: Color {
        .borderDefault
    }

    @ViewBuilder
    private var contentView: some View {
        switch type {
        case .url:
            HStack(alignment: .top, spacing: 12) {
                typeBadge(background: Color.accent.opacity(0.16)) {
                    AirClipIcon(.arrowUpRight, size: 14)
                        .foregroundColor(linkTextColor)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text(item.text)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(linkTextColor)
                        .underline()
                        .lineSpacing(4.5)
                        .lineLimit(2)
                        .truncationMode(.tail)
                        .blur(radius: shouldRedact ? 4 : 0)
                        .frame(minHeight: 19.5, alignment: .top)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    metaRowJustified
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

        case .code:
            HStack(alignment: .top, spacing: 12) {
                typeBadge(background: Color(hex: "#E5760E").opacity(0.16)) {
                    AirClipIcon(.code, size: 14)
                        .foregroundColor(Color(hex: "#E5760E"))
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text(item.text)
                        .font(.system(size: 13, weight: .regular, design: .monospaced))
                        .foregroundColor(codeTextColor)
                        .lineSpacing(4.5)
                        .lineLimit(2)
                        .truncationMode(.tail)
                        .blur(radius: shouldRedact ? 4 : 0)
                        .frame(minHeight: 19.5, alignment: .top)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    metaRowJustified
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

        case .color:
            HStack(alignment: .top, spacing: 12) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(parsedColor ?? Color.accent)
                    .frame(width: 54, height: 54)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.15), lineWidth: 0.5)
                    )
                VStack(alignment: .leading, spacing: 8) {
                    Text(colorDisplayText)
                        .font(.system(size: 20, weight: .regular))
                        .foregroundColor(primaryTextColor)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(minHeight: 30, alignment: .top)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    metaRowJustified
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

        case .image:
            HStack(alignment: .top, spacing: 14) {
                previewImageView
                VStack(alignment: .leading, spacing: 8) {
                    Text(imageDisplayName)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(primaryTextColor)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(minHeight: 19.5, alignment: .top)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Spacer(minLength: 0)
                    metaRowJustified
                }
                .frame(height: 80)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

        case .email:
            HStack(alignment: .top, spacing: 12) {
                typeBadge(background: Color(hex: "#70CBFF").opacity(0.16)) {
                    AirClipIcon(.mail, size: 14)
                        .foregroundColor(Color(hex: "#70CBFF"))
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text(item.text)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(primaryTextColor)
                        .lineSpacing(4.5)
                        .lineLimit(2)
                        .truncationMode(.tail)
                        .blur(radius: shouldRedact ? 4 : 0)
                        .frame(minHeight: 19.5, alignment: .top)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    metaRowJustified
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

        case .text:
            HStack(alignment: .top, spacing: 12) {
                typeBadge(background: Color(hex: "#78A57F").opacity(0.16)) {
                    AirClipIcon(.text, size: 14)
                        .foregroundColor(Color(hex: "#78A57F"))
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text(item.text)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(primaryTextColor)
                        .lineSpacing(4.5)
                        .lineLimit(2)
                        .truncationMode(.tail)
                        .blur(radius: shouldRedact ? 4 : 0)
                        .frame(minHeight: 19.5, alignment: .top)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    metaRowJustified
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var metaRowJustified: some View {
        HStack(spacing: 8) {
            Text(deviceName)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 8)
            Text(relativeTime)
                .lineLimit(1)
        }
        .font(.system(size: 12))
        .foregroundColor(metaTextColor)
        .frame(height: 16)
        .frame(maxWidth: .infinity)
    }

    private var metaRowInline: some View {
        HStack(spacing: 9) {
            Text(deviceName)
                .lineLimit(1)
                .truncationMode(.tail)
            Text("•")
            Text(relativeTime)
                .lineLimit(1)
        }
        .font(.system(size: 12))
        .foregroundColor(metaTextColor)
        .frame(height: 16)
    }

    @ViewBuilder
    private var previewImageView: some View {
        if let image = previewImage {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(imageBorderColor, lineWidth: 0.5)
                )
        } else {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.bgFloating)
                .frame(width: 80, height: 80)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(imageBorderColor, lineWidth: 0.5)
                )
        }
    }

    private var imageDisplayName: String {
        let trimmed = item.text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.lowercased().hasPrefix("image ") {
            let dimensions = trimmed
                .dropFirst("Image ".count)
                .replacingOccurrences(of: "×", with: "x")
                .split(separator: "x", maxSplits: 1)
            if dimensions.count == 2 {
                return "Image (\(dimensions[0].trimmingCharacters(in: .whitespaces)) × \(dimensions[1].trimmingCharacters(in: .whitespaces)))"
            }
            return trimmed
        }
        return "Image"
    }

    private var colorDisplayText: String {
        item.text.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    private var parsedColor: Color? { Color.parseHex(item.text) }
    private var previewImage: NSImage? {
        guard let data = item.imageData else { return nil }
        return NSImage(data: data)
    }

    private var deviceName: String {
        item.isLocal
            ? "This Mac"
            : (AirClipIdentity.shared.pairedDevices[item.fromDeviceId]?.deviceName ?? "Remote device")
    }

    private var relativeTime: String {
        let diff = Int(Date().timeIntervalSince(item.receivedAt))
        if diff < 60 { return "\(max(diff, 1))s ago" }
        let mins = diff / 60
        if mins < 60 { return "\(mins)m ago" }
        let hours = mins / 60
        if hours < 24 { return "\(hours)h ago" }
        let cal = Calendar.current
        if cal.isDateInYesterday(item.receivedAt) { return "Yesterday" }
        let fmt = DateFormatter()
        fmt.dateFormat = cal.isDate(item.receivedAt, equalTo: Date(), toGranularity: .year) ? "MMM d" : "MMM d, yyyy"
        return fmt.string(from: item.receivedAt)
    }

    private func typeBadge<Content: View>(background: Color, @ViewBuilder content: () -> Content) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(background)
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(iconContainerBorderColor, lineWidth: 0.5)
            content()
        }
        .frame(width: 28, height: 28)
    }

}

// MARK: - Card press style (spring scale + brightness, not opacity)

private struct CardPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.965 : 1.0)
            .brightness(configuration.isPressed ? -0.08 : 0)
            .animation(.airClipInstant(0.10), value: configuration.isPressed)
    }
}

// MARK: - Connection Badge (kept for future main window use)

struct ConnectionBadge: View {
    let isConnected: Bool
    @State private var dotOpacity: Double = 1.0

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(isConnected ? Color.syncBlue : Color.textSecondary)
                .frame(width: 6, height: 6)
                .opacity(dotOpacity)
                .onAppear { startPulseIfNeeded() }
                .onChange(of: isConnected) { _, _ in startPulseIfNeeded() }

            Text(isConnected ? "Live" : "Offline")
                .font(.airClipCaption)
                .foregroundColor(.textSecondary)
        }
    }

    private func startPulseIfNeeded() {
        dotOpacity = 1.0
        guard isConnected else { return }
        withAnimation(.airClipPulse.repeatForever(autoreverses: true)) {
            dotOpacity = 0.35
        }
    }
}

// MARK: - Notification names

extension Notification.Name {
    static let openMainWindow  = Notification.Name("com.airclip.openMainWindow")
    static let panelWillOpen   = Notification.Name("com.airclip.panelWillOpen")
    static let panelWillClose  = Notification.Name("com.airclip.panelWillClose")
    static let openSettingsTab = Notification.Name("com.airclip.openSettingsTab")
    static let openHomeTab     = Notification.Name("com.airclip.openHomeTab")
    static let openDevicesTab  = Notification.Name("com.airclip.openDevicesTab")
    static let toggleMainWindowSidebar = Notification.Name("com.airclip.toggleMainWindowSidebar")
    // authDidComplete is defined in OnboardingView.swift
}
