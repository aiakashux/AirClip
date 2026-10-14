import SwiftUI
import SwiftData
import AppKit

// ClipType is defined in ClipTypeDetector.swift

// MARK: - Popover View

private enum PopoverMetrics {
    static let width: CGFloat = 372
    static let outerPadding: CGFloat = 24
    static let topPadding: CGFloat = 8
    static let cardSpacing: CGFloat = 8
    static let cardRadius: CGFloat = 16
    static let cardPaddingHorizontal: CGFloat = 12.5
    static let cardPaddingVertical: CGFloat = 12.5
    static let footerTopPadding: CGFloat = 8
    static let footerHeight: CGFloat = 36
    static let emptyHeight: CGFloat = 132
    static let toastTopPadding: CGFloat = 8
    static let dismissDelay: Double = 0.24
    static let copyExitDelay: Double = 0.65
    static let copyCloseDelay: Double = 0.82
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
    @State private var keyboardSelection = 0
    @State private var knownItemIDs = Set<UUID>()
    @State private var animateRemoteInsertion = false
    @FocusState private var isKeyboardFocused: Bool

    @State private var openAirclipHovered = false

    private var recentItems: [ClipboardItem] { Array(allItems.prefix(5)) }
    private var contentIsVisible: Bool { isContentVisible && !isExiting }

    var body: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                cardSection
                footerBar
            }
            .padding(.horizontal, PopoverMetrics.outerPadding)
            .padding(.bottom, PopoverMetrics.outerPadding)
            .padding(.top, PopoverMetrics.topPadding)
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
        .focusable()
        .focused($isKeyboardFocused)
        .focusEffectDisabled()
        .onKeyPress(.downArrow) {
            guard !recentItems.isEmpty else { return .ignored }
            keyboardSelection = min(keyboardSelection + 1, recentItems.count - 1)
            return .handled
        }
        .onKeyPress(.upArrow) {
            guard !recentItems.isEmpty else { return .ignored }
            keyboardSelection = max(keyboardSelection - 1, 0)
            return .handled
        }
        .onKeyPress(.return) {
            guard recentItems.indices.contains(keyboardSelection) else { return .ignored }
            handleCardTap(item: recentItems[keyboardSelection])
            return .handled
        }
        .onReceive(NotificationCenter.default.publisher(for: .panelWillOpen)) { _ in
            copyFlowSession &+= 1
            isExiting = false
            isContentVisible = false
            showToast = false
            keyboardSelection = 0
            knownItemIDs = Set(allItems.map(\.id))
            animateRemoteInsertion = false
            animationSession &+= 1
            DispatchQueue.main.async {
                isKeyboardFocused = true
                withAnimation(contentAnimation) {
                    isContentVisible = true
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .panelWillClose)) { _ in
            copyFlowSession &+= 1
            dismissWithAnimation()
        }
        .onChange(of: allItems.map(\.id)) { _, _ in
            let inserted = allItems.filter { !knownItemIDs.contains($0.id) }
            animateRemoteInsertion = contentIsVisible && !reduceMotion && inserted.contains { !$0.isLocal }
            knownItemIDs = Set(allItems.map(\.id))
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
                        item: item,
                        isKeyboardSelected: keyboardSelection == index,
                        onCopy: { handleCardCopy(item) },
                        onTap: { handleCardTap(item: item) }
                    )
                    .id("\(item.id)-\(animationSession)")
                    .popoverListMotion(
                        isVisible: contentIsVisible,
                        index: index,
                        reduceMotion: reduceMotion
                    )
                    .transition(remoteItemTransition)
                }
            }
        }
        .animation(animateRemoteInsertion ? .spring(response: 0.28, dampingFraction: 0.82) : nil, value: recentItems.map(\.id))
    }

    private var remoteItemTransition: AnyTransition {
        reduceMotion ? .opacity : .asymmetric(
            insertion: .move(edge: .top).combined(with: .opacity),
            removal: .move(edge: .bottom).combined(with: .opacity)
        )
    }

    // MARK: - Empty State

    private var emptyState: some View {
        AirclipFigmaEmptyState(text: "Your recent clips will appear here. Copy something on this Mac or a connected device.")
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
                        .background(Color.accentDeep)
                        .clipShape(Capsule())
                }
                .buttonStyle(FooterPressStyle())
            }

            Button {
                dismissWithAnimation {
                    NotificationCenter.default.post(name: .openMainWindow, object: nil)
                }
            } label: {
                Text("Open Airclip")
                    .font(.system(size: 13, weight: .medium))
                    .frame(maxWidth: .infinity)
                    .frame(height: PopoverMetrics.footerHeight)
            }
            .buttonStyle(OpenAirclipFooterButtonStyle(isHovered: openAirclipHovered))
            .onHover { h in
                openAirclipHovered = h
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

    private var emptyCardFill: Color {
        Color.bgElevated
    }

    // MARK: - Toast

    private var toastView: some View {
        HStack(spacing: 5) {
            AirclipIcon(.tick, size: 11)
                .foregroundColor(.encryptedGreen)
            Text("Copied to clipboard")
                .font(.airClipCaption)
                .foregroundColor(.textSecondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(Color.bgFloating)
                .overlay(Capsule().strokeBorder(Color.borderSubtle, lineWidth: 0.5))
        )
        .shadow(color: .black.opacity(0.10), radius: 6, x: 0, y: 2)
        .allowsHitTesting(false)
        .transition(.asymmetric(
            insertion: .offset(y: -4).combined(with: .opacity),
            removal: .opacity
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
        if item.clipType == .file {
            dismissWithAnimation { NotificationCenter.default.post(name: .openMainWindow, object: nil) }
            return
        }
        if item.clipType == .url {
            guard let url = URL(string: item.text.trimmingCharacters(in: .whitespacesAndNewlines)) else { return }
            dismissWithAnimation { NSWorkspace.shared.open(url) }
            return
        }

        handleCardCopy(item)
    }

    private func handleCardCopy(_ item: ClipboardItem) {
        guard item.clipType != .file else { handleCardTap(item: item); return }

        copyFlowSession &+= 1
        let activeCopyFlow = copyFlowSession

        ClipboardMonitor.shared.suppressPacket(item.clipboardPacket)
        ClipboardCapture.write(item.clipboardPacket, to: NSPasteboard.general)

        withAnimation(
            reduceMotion
                ? .easeOut(duration: 0.01)
                : .timingCurve(0.25, 0.46, 0.45, 0.94, duration: Duration.micro)
        ) {
            showToast = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + (reduceMotion ? 0.01 : PopoverMetrics.copyExitDelay)) {
            guard activeCopyFlow == copyFlowSession else { return }
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.12)) {
                showToast = false
            }
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

private struct OpenAirclipFooterButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let isHovered: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(isHovered || configuration.isPressed ? Color.accent : Color.textPrimary)
            .background(
                Capsule()
                    .fill(Color.bgElevated)
                    .overlay(
                        Capsule().fill(
                            configuration.isPressed
                                ? Color.accent.opacity(0.14)
                                : isHovered ? Color.accent.opacity(0.08) : .clear
                        )
                    )
            )
            .overlay(
                Capsule().strokeBorder(
                    isHovered || configuration.isPressed
                        ? Color.accent.opacity(0.24)
                        : Color.borderSubtle,
                    lineWidth: 0.5
                )
            )
            .scaleEffect(reduceMotion || !configuration.isPressed ? 1 : 0.98)
            .animation(.airClipInstant(0.12), value: isHovered)
            .animation(.airClipInstant(0.10), value: configuration.isPressed)
    }
}

// MARK: - Clip Card

private struct ClipCard: View {
    let item: ClipboardItem
    let isKeyboardSelected: Bool
    let onCopy: () -> Void
    let onTap: () -> Void

    @ObservedObject private var syncEngine = SyncEngine.shared
    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovered = false
    @State private var isOpenActionHovered = false
    @State private var isCopyActionHovered = false
    @State private var linkPreview: LinkPreviewMetadata?

    private var type: ClipType { item.clipType }
    private var isFileDownloaded: Bool { syncEngine.availableFileURL(for: item) != nil }
    private var isFileDownloading: Bool {
        guard let id = item.fileMetadata?.id else { return false }
        return syncEngine.fileTransfers[id]?.phase == .downloading
    }

    var body: some View {
        Button(action: onTap) {
            contentView
                .padding(.horizontal, PopoverMetrics.cardPaddingHorizontal)
                .padding(.vertical, PopoverMetrics.cardPaddingVertical)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background {
                    RoundedRectangle(cornerRadius: PopoverMetrics.cardRadius)
                        .fill(Color.bgElevated)
                }
                .clipShape(RoundedRectangle(cornerRadius: PopoverMetrics.cardRadius))
                .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
                .overlay(
                    RoundedRectangle(cornerRadius: PopoverMetrics.cardRadius)
                        .strokeBorder(
                            cardBorderColor,
                            lineWidth: 0.5
                        )
                        .animation(.easeOut(duration: 0.12), value: isHovered)
                )
        }
        .buttonStyle(CardPressStyle())
        .overlay {
            if isHovered { actionOverlay }
        }
        .animation(.easeOut(duration: 0.16), value: isHovered)
        .accessibilityLabel(type == .file ? "Open file in Airclip" : type == .url ? "Open link from \(deviceName)" : "Copy \(type.rawValue) from \(deviceName)")
        .accessibilityHint(type == .url ? "Opens this link in your browser" : "Copies this item and closes Airclip")
        .onHover { hovering in
            isHovered = hovering
            if hovering { NSCursor.pointingHand.set() } else { NSCursor.arrow.set() }
        }
    }

    private var cardBorderColor: Color {
        isKeyboardSelected ? Color.borderFocus : Color.borderSubtle
    }

    private var actionOverlay: some View {
        ZStack {
            RoundedRectangle(cornerRadius: PopoverMetrics.cardRadius, style: .continuous)
                .fill(.ultraThinMaterial)
            RoundedRectangle(cornerRadius: PopoverMetrics.cardRadius, style: .continuous)
                .fill(colorScheme == .dark ? Color.bgElevated.opacity(0.76) : Color.white.opacity(0.65))
                HStack(spacing: 0) {
                    if type == .url {
                        Button(action: onTap) {
                            actionLabel(
                                icon: .openBrowser,
                                title: "Open",
                                iconSize: 18,
                                color: isOpenActionHovered ? .accentDeep : .accent,
                                shimmer: isOpenActionHovered
                            )
                        }
                        .buttonStyle(PopoverActionButtonStyle(isHovered: isOpenActionHovered))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .onHover { isOpenActionHovered = $0 }
                    }
                    Button(action: type == .file ? performFileAction : onCopy) {
                        if type == .file {
                            fileActionLabel
                        } else {
                            actionLabel(
                                icon: .copy,
                                title: "Click to Copy",
                                color: isCopyActionHovered ? .accentDeep : .accent,
                                shimmer: isCopyActionHovered
                            )
                        }
                    }
                    .buttonStyle(PopoverActionButtonStyle(isHovered: isCopyActionHovered))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .disabled(type == .file && isFileDownloading)
                    .onHover { isCopyActionHovered = $0 }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .padding(1)
        }
            .clipShape(RoundedRectangle(cornerRadius: PopoverMetrics.cardRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: PopoverMetrics.cardRadius, style: .continuous)
                    .strokeBorder(
                        colorScheme == .dark ? Color.borderDefault : Color(hex: "#E1E4EA"),
                        lineWidth: 1
                    )
            }
        .transition(.opacity)
    }

    private func actionLabel(
        icon: AirclipIconName,
        title: String,
        iconSize: CGFloat = 18,
        color: Color = .accent,
        shimmer: Bool
    ) -> some View {
        HStack(spacing: 8) {
            AirclipIcon(icon, size: iconSize)
            Text(title)
        }
        .font(.system(size: 13, weight: .medium))
        .foregroundColor(color)
        .singleShimmer(isActive: shimmer)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
    }

    private var fileActionLabel: some View {
        HStack(spacing: 8) {
            if isFileDownloaded {
                AirclipIcon(.arrowUpRight, size: 16)
            } else if isFileDownloading {
                ProgressView().controlSize(.small)
            } else {
                Image(systemName: "arrow.down.to.line")
                    .font(.system(size: 16, weight: .medium))
            }
            Text(isFileDownloaded ? "Open" : isFileDownloading ? "Downloading…" : "Download")
        }
        .font(.system(size: 13, weight: .medium))
        .foregroundColor(isCopyActionHovered ? .accentDeep : .accent)
        .singleShimmer(isActive: isCopyActionHovered && !isFileDownloading)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
    }

    private func performFileAction() {
        if let url = syncEngine.availableFileURL(for: item) {
            NSWorkspace.shared.open(url)
        } else if !isFileDownloading {
            syncEngine.downloadFile(item)
        }
    }

    private var primaryTextColor: Color {
        colorScheme == .dark ? .textPrimary : Color(hex: "#232E43")
    }

    private var metaTextColor: Color {
        colorScheme == .dark ? .textSecondary : Color(hex: "#6A7282")
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
        Color(hex: "#DADDDF")
    }

    @ViewBuilder
    private var contentView: some View {
        switch type {
        case .file:
            HStack(spacing: 10) {
                if item.fileMetadata?.isImage == true,
                   let thumbnail = item.fileMetadata?.thumbnailImage {
                    Image(nsImage: thumbnail)
                        .resizable().aspectRatio(contentMode: .fill)
                        .frame(width: 24, height: 24)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .frame(width: 28, height: 28)
                } else if item.fileMetadata?.isImage == true {
                    AirclipIcon(.image, size: 16)
                        .foregroundColor(Color.textSecondary)
                        .frame(width: 28, height: 28)
                } else {
                    fileTypeIconBadge(
                        iconName: item.fileMetadata?.iconAssetName ?? "FileIconDocument",
                        accent: item.fileMetadata?.iconAccentColor ?? Color(hex: "#33A1FE"),
                        iconSize: 16,
                        containerSize: 28
                    )
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.fileMetadata?.name ?? item.text)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(primaryTextColor)
                        .lineLimit(1)
                    metaRowJustified
                }
            }
        case .url:
            HStack(alignment: .top, spacing: 12) {
                typeBadge(background: Color.accent.opacity(0.16)) {
                    AirclipIcon(.link, size: 14)
                        .foregroundColor(linkTextColor)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text(linkPreview?.hasExplicitTitle == true ? linkPreview!.title : item.text)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(linkTextColor)
                        .underline()
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(minHeight: 19.5, alignment: .top)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    metaRowJustified
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .task(id: item.id) {
                    linkPreview = await LinkPreviewLoader.preview(for: item.text, includeImage: false)
                }
            }

        case .code:
            HStack(alignment: .center, spacing: 12) {
                typeBadge(background: Color.warningYellow.opacity(0.16)) {
                    AirclipIcon(.text, size: 14)
                        .foregroundColor(Color.warningYellow)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.text)
                        .font(.system(size: 13, weight: .regular, design: .monospaced))
                        .foregroundColor(codeTextColor)
                        .lineSpacing(4.5)
                        .lineLimit(2)
                        .truncationMode(.tail)
                        .frame(minHeight: 19.5, alignment: .top)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    metaRowJustified
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

        case .color:
            HStack(alignment: .center, spacing: 12) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(parsedColor ?? Color.accent)
                    .frame(width: 54, height: 54)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.15), lineWidth: 0.5)
                    )
                VStack(alignment: .leading, spacing: 6) {
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
                VStack(alignment: .leading, spacing: 6) {
                    Text(imageDisplayName)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(primaryTextColor)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(minHeight: 19.5, alignment: .top)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    metaRowJustified
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

        case .email:
            HStack(alignment: .center, spacing: 12) {
                typeBadge(background: Color.syncBlue.opacity(0.16)) {
                    AirclipIcon(.text, size: 14)
                        .foregroundColor(Color.syncBlue)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.text)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(primaryTextColor)
                        .lineSpacing(4.5)
                        .lineLimit(2)
                        .truncationMode(.tail)
                        .frame(minHeight: 19.5, alignment: .top)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    metaRowJustified
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

        case .text:
            HStack(alignment: .center, spacing: 12) {
                typeBadge(background: Color.encryptedGreen.opacity(0.10)) {
                    AirclipIcon(.text, size: 14)
                        .foregroundColor(Color.encryptedGreen)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.text)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(primaryTextColor)
                        .lineSpacing(4.5)
                        .lineLimit(2)
                        .truncationMode(.tail)
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
            Text(relativeTime)
                .lineLimit(1)
        }
        .font(.system(size: 12))
        .foregroundColor(metaTextColor)
        .frame(height: 16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var metaRowInline: some View {
        HStack(spacing: 9) {
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
            : (AirclipIdentity.shared.pairedDevices[item.fromDeviceId]?.deviceName ?? "Remote device")
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

    private func fileTypeIconBadge(
        iconName: String,
        accent: Color,
        iconSize: CGFloat,
        containerSize: CGFloat
    ) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(accent.opacity(0.07))
            Image(iconName)
                .resizable()
                .interpolation(.high)
                .frame(width: iconSize, height: iconSize)
        }
        .frame(width: containerSize, height: containerSize)
    }

}

private struct PopoverActionButtonStyle: ButtonStyle {
    let isHovered: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                Color(hex: "#6C3EC6").opacity(
                    configuration.isPressed ? 0.08 : isHovered ? 0.05 : 0
                )
            )
            .contentShape(Rectangle())
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

private struct SingleShimmer: ViewModifier {
    let isActive: Bool
    @State private var phase: CGFloat = -0.6

    func body(content: Content) -> some View {
        content
            .overlay {
                GeometryReader { proxy in
                    LinearGradient(
                        colors: [.clear, .white.opacity(0.5), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: proxy.size.width * 0.65)
                    .offset(x: phase * proxy.size.width)
                    .mask(content)
                }
                .allowsHitTesting(false)
            }
            .onChange(of: isActive) { _, active in
                guard active else { return }
                phase = -0.6
                withAnimation(.easeOut(duration: 0.32)) { phase = 1.6 }
            }
    }
}

private extension View {
    func singleShimmer(isActive: Bool) -> some View {
        modifier(SingleShimmer(isActive: isActive))
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
