import SwiftUI
import SwiftData
import AppKit
import Quartz
import QuickLookUI
import Carbon
import UniformTypeIdentifiers

private struct DroppedFileCandidate: Identifiable {
    let url: URL
    let name: String
    let size: Int64
    let kindName: String

    var id: String { url.standardizedFileURL.path }

    init?(url: URL) {
        guard url.isFileURL,
              let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey, .contentTypeKey]),
              values.isRegularFile == true else { return nil }
        self.url = url
        self.name = url.lastPathComponent
        self.size = Int64(values.fileSize ?? 0)
        self.kindName = values.contentType?.localizedDescription ?? "File"
    }
}

private struct EmbeddedFileQuickLookPreview: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> QLPreviewView {
        let view = QLPreviewView(frame: .zero, style: .normal)!
        view.previewItem = url as NSURL
        return view
    }

    func updateNSView(_ view: QLPreviewView, context: Context) {
        guard (view.previewItem as? NSURL)?.path != url.path else { return }
        view.previewItem = url as NSURL
        view.refreshPreviewItem()
    }
}

private final class QuickLookImagePreviewer: NSObject, QLPreviewPanelDataSource {
    static let shared = QuickLookImagePreviewer()
    private var previewURL: URL?

    func show(imageData: Data, name: String) {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(name.isEmpty ? UUID().uuidString : name)
            .appendingPathExtension("png")
        try? imageData.write(to: url, options: .atomic)
        previewURL = url

        guard let panel = QLPreviewPanel.shared() else { return }
        panel.dataSource = self
        panel.reloadData()
        panel.makeKeyAndOrderFront(nil)
    }

    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int { previewURL == nil ? 0 : 1 }

    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! {
        previewURL as NSURL?
    }
}

private enum MainPage: String, CaseIterable {
    case home = "Home"
    case saved = "Saved Items"
    case devices = "Devices"
    case settings = "Settings"

    var icon: AirclipIconName {
        switch self {
        case .home: return .home
        case .devices: return .deviceSync
        case .saved: return .bookmark
        case .settings: return .settings
        }
    }
}

private enum MainWindowLayout {
    static let windowWidth: CGFloat = 940
    static let windowHeight: CGFloat = 674
    static let mainCardLeadingInset: CGFloat = 0
    static let mainCardTrailingInset: CGFloat = 0
    static let mainCardTopInset: CGFloat = 0
    static let mainCardBottomInset: CGFloat = 0
    static let mainCardCornerRadius: CGFloat = 0
    static let contentHeight: CGFloat = windowHeight
    static let contentWidth: CGFloat = windowWidth
    static let sidebarHorizontalPadding: CGFloat = 8
    static let sidebarWidth: CGFloat = navItemSize + (sidebarHorizontalPadding * 2)
    static let sidebarInnerWidth: CGFloat = navItemSize
    static let mainCardWidth: CGFloat = windowWidth - sidebarWidth
    static let listWidth: CGFloat = 362
    static let listSearchHorizontalInset: CGFloat = 16
    static let searchBarContentHorizontalInset: CGFloat = 16
    static let listHeaderHorizontalInset: CGFloat = 24
    static let listRowHorizontalInset: CGFloat = 16
    static let listSearchHeight: CGFloat = 60
    static let filterRowTopGap: CGFloat = 8
    static let filterScrollTargetSize: CGFloat = 40
    static let previewMinWidth: CGFloat = 240
    static let navIconSize: CGFloat = 20
    static let navItemPadding: CGFloat = 10
    static let navItemSize: CGFloat = navIconSize + (navItemPadding * 2)
    static let navCornerRadius: CGFloat = 10
    static let navTooltipGap: CGFloat = 8
    static let navTooltipFontSize: CGFloat = 12
    static let navTooltipHorizontalPadding: CGFloat = 8
    static let navTooltipVerticalPadding: CGFloat = 8
    static let navTooltipCornerRadius: CGFloat = 6
    static let rowWidth: CGFloat = 330
    static let rowHeight: CGFloat = 52
    static let rowIconWidth: CGFloat = 16
    static let actionBarWidth: CGFloat = 148
    static let actionBarHeight: CGFloat = 44
    static let previewTopInset: CGFloat = 32
    static let previewLeadingInset: CGFloat = 32
    static let previewTrailingInset: CGFloat = 32
    static let previewBottomInset: CGFloat = 108
    static let previewActionTrailingInset: CGFloat = 20
    static let previewActionBottomInset: CGFloat = 20
    static let settingsInset: CGFloat = 24
    static let settingsMaxWidth: CGFloat = 520
    static let devicesHorizontalInset: CGFloat = 24
    static let devicesTopInset: CGFloat = 24
    static let deviceOrbitHubSize: CGFloat = 48
    static let deviceOrbitNodeSize: CGFloat = 36
    static let deviceOrbitTooltipMinWidth: CGFloat = 121
    static let deviceOrbitTooltipMaxWidth: CGFloat = 320
    static let deviceOrbitTooltipHeight: CGFloat = 52
    static let deviceOrbitTooltipGap: CGFloat = 8
    static let deviceOrbitTooltipTextGap: CGFloat = 4
    static let deviceOrbitStroke: CGFloat = 1
    static let textBadgeFill = Color.encryptedGreen.opacity(0.12)
    static let textBadgeForeground = Color.encryptedGreen
    static let linkBadgeFill = Color.accent.opacity(0.12)
    static let linkBadgeForeground = Color.accent
    static let codeBadgeFill = Color.warningYellow.opacity(0.12)
    static let codeBadgeForeground = Color.warningYellow
    static let emailBadgeFill = Color.syncBlue.opacity(0.12)
    static let emailBadgeForeground = Color.syncBlue
    static let imageBadgeFill = Color(hex: "#DB438A").opacity(0.12)
    static let imageBadgeForeground = Color(hex: "#DB438A")
    static let imagePreviewBadgeFill = Color.white.opacity(0.50)
    static let fileIconFallbackColor = Color(hex: "#33A1FE")
    static let colorBadgeFill = Color.textSecondary.opacity(0.12)
    static let colorBadgeForeground = Color.textSecondary
    static let badgeBorder = Color(hex: "#808080").opacity(0.2)
    static let codeTitleText = Color.textSubtle
    static let searchBackground = MainWindowPalette.searchIdleFill
    static let searchBorder = MainWindowPalette.searchIdleBorder
    static let sectionHeaderText = MainWindowPalette.sectionHeaderText
    static let listTitleText = MainWindowPalette.listTitleText
    static let listMetaText = MainWindowPalette.listMetaText
}

private enum MainWindowPalette {
    static let shell = Color.mainWindowShell
    static let shellGlassTint = Color.glassTint.opacity(0.06)
    static let card = Color.bgElevated
    static let primaryText = Color.textPrimary
    static let secondaryText = Color.textSecondary
    static let tertiaryText = Color.textTertiary
    static let divider = Color.borderSubtle
    static let activeFill = Color.activeFill
    static let hoverFill = Color.hoverFill
    static let itemHoverFill = Color.listItemHover
    static let itemSelectedFill = Color.listItemSelected
    static let itemSelectedBorder = Color.listItemSelectedBorder
    static let pressedFill = Color.activeFill
    static let searchFill = Color.bgFloating
    static let focusStroke = Color.accent
    static let selectionStroke = Color.accent.opacity(0.65)
    static let rowStroke = Color.borderDefault
    static let saved = Color.encryptedGreen
    static let destructive = Color.destructiveRed
    static let sectionFill = Color.bgFloating
    static let dangerHoverFill = Color.destructiveRed.opacity(0.10)
    static let online = Color.encryptedGreen
    static let offline = Color.textTertiary
    static let sidebarText = Color.textSubtle
    static let sidebarHoverFill = Color.sidebarHover
    static let sidebarActiveFill = Color.sidebarSelected
    static let sidebarActiveBorder = Color.sidebarSelectedBorder
    static let sidebarItemBorder = Color.borderSubtle
    static let searchIdleFill = Color.mainWindowSearchFill
    static let searchIdleBorder = Color.borderDefault
    static let sectionHeaderText = Color.textSecondary
    static let listTitleText = Color.mainWindowBrand
    static let listMetaText = Color.mainWindowMeta
}

private enum MainWindowMotion {
    static let sidebarDuration: Double = 0.24
    static let hoverDuration: Double = 0.12
    static let pressDuration: Double = 0.08
    static let releaseDuration: Double = 0.12
    static let feedbackDuration: Double = 0.12
    static let feedbackResetDuration: Double = 0.14
    static let navPressScale: CGFloat = 0.985
    static let actionPressScale: CGFloat = 0.97
    static let rowPressScale: CGFloat = 0.992
}

private struct FilterArrowPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(reduceMotion || !configuration.isPressed ? 1 : 0.965)
            .animation(
                reduceMotion ? nil : .timingCurve(0.23, 1, 0.32, 1, duration: 0.12),
                value: configuration.isPressed
            )
    }
}

struct MainWindowView: View {
    @Query private var allItems: [ClipboardItem]
    @ObservedObject private var alertCenter = AirclipAlertCenter.shared
    @ObservedObject private var identity = AirclipIdentity.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @State private var activePage: MainPage = .home
    @State private var isFileDropTargeted = false
    @State private var droppedFiles: [DroppedFileCandidate] = []
    @State private var dropSpaceName = ""
    @State private var saveDroppedFiles = false
    @State private var showFileDropConfirmation = false
    @State private var showUnsupportedDropAlert = false

    private var savedCount: Int {
        allItems.filter(\.isSaved).count
    }

    private var currentDetailAreaWidth: CGFloat {
        MainWindowLayout.contentWidth - MainWindowLayout.sidebarWidth
    }

    private var currentMainCardWidth: CGFloat {
        currentDetailAreaWidth - MainWindowLayout.mainCardLeadingInset - MainWindowLayout.mainCardTrailingInset
    }

    private var currentMainCardHeight: CGFloat {
        MainWindowLayout.contentHeight - MainWindowLayout.mainCardTopInset - MainWindowLayout.mainCardBottomInset
    }

    private var fileDropIsEnabled: Bool {
        activePage == .home || activePage == .saved
    }

    private var showsFileDropOverlay: Bool {
        fileDropIsEnabled && isFileDropTargeted
    }

    private var fileDropTargetBinding: Binding<Bool> {
        Binding(
            get: { showsFileDropOverlay },
            set: { isFileDropTargeted = fileDropIsEnabled && $0 }
        )
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebarColumn
            detailContent
                .frame(width: currentDetailAreaWidth, height: MainWindowLayout.contentHeight, alignment: .topLeading)
                .blur(radius: showsFileDropOverlay ? 8 : 0, opaque: false)
                .clipped()
                .overlay {
                    if showsFileDropOverlay { fileDropOverlay }
                }
        }
        .frame(width: MainWindowLayout.contentWidth, height: MainWindowLayout.contentHeight, alignment: .topLeading)
        .background(MainWindowPalette.shell)
        .overlay(alignment: .bottom) {
            if let alert = alertCenter.current {
                AirclipBottomAlert(
                    item: alert,
                    onAction: alertCenter.performAction
                )
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
                .transition(reduceMotion ? .opacity : .airclipBottomAlert)
                .zIndex(100)
            }
        }
        .animation(
            reduceMotion ? .easeInOut(duration: 0.12) : .timingCurve(0.16, 1, 0.3, 1, duration: 0.22),
            value: alertCenter.current?.id
        )
        .onDrop(of: [UTType.fileURL], isTargeted: fileDropTargetBinding, perform: receiveFileDrop)
        .sheet(isPresented: $showFileDropConfirmation, onDismiss: { droppedFiles = [] }) {
            FileDropConfirmationSheet(
                files: droppedFiles,
                spaceName: dropSpaceName,
                saveAfterSharing: saveDroppedFiles,
                canShare: SyncModeStore.shared.mode.allowsOutboundSync,
                onCancel: { showFileDropConfirmation = false },
                onShare: shareDroppedFiles
            )
        }
        .alert("No supported files to share", isPresented: $showUnsupportedDropAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Airclip can share individual files. Folders and items without an accessible file are not added to your Space.")
        }
        .onReceive(NotificationCenter.default.publisher(for: .openSettingsTab)) { _ in
            activePage = .settings
        }
        .onReceive(NotificationCenter.default.publisher(for: .openHomeTab)) { _ in
            activePage = .home
        }
        .onReceive(NotificationCenter.default.publisher(for: .openDevicesTab)) { _ in
            activePage = .devices
        }
    }

    private var fileDropOverlay: some View {
        ZStack {
            RoundedRectangle(cornerRadius: MainWindowLayout.mainCardCornerRadius, style: .continuous)
                .fill(Color.accent.opacity(0.05))
            VStack(spacing: 10) {
                AirclipEmptyLogoMark(size: 32, color: .textPrimary)
                Text("Drop the file to share with your Space")
                    .font(.system(size: 14, weight: .medium))
                if activePage == .saved {
                    Text("It will also be added to Saved.")
                        .font(.system(size: 12))
                        .foregroundColor(.textSecondary)
                }
            }
            .foregroundColor(.textPrimary)
            .padding(20)
            RoundedRectangle(cornerRadius: MainWindowLayout.mainCardCornerRadius, style: .continuous)
                .strokeBorder(Color.syncBlue.opacity(0.72), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
        }
        .padding(8)
        .allowsHitTesting(false)
        .transition(.opacity)
    }

    private func receiveFileDrop(providers: [NSItemProvider]) -> Bool {
        guard fileDropIsEnabled else { return false }
        let fileProviders = providers.filter {
            $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier)
        }
        guard !fileProviders.isEmpty else { return false }

        let group = DispatchGroup()
        let lock = NSLock()
        var indexedURLs: [(Int, URL)] = []
        for (index, provider) in fileProviders.enumerated() {
            group.enter()
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                if let url = Self.fileURL(from: item) {
                    lock.lock()
                    indexedURLs.append((index, url))
                    lock.unlock()
                }
                group.leave()
            }
        }
        group.notify(queue: .global(qos: .userInitiated)) {
            lock.lock()
            let loadedURLs = indexedURLs.sorted { $0.0 < $1.0 }.map(\.1)
            lock.unlock()
            var seen = Set<String>()
            let candidates = loadedURLs
                .filter { seen.insert($0.standardizedFileURL.path).inserted }
                .compactMap(DroppedFileCandidate.init(url:))
            DispatchQueue.main.async {
                guard !candidates.isEmpty else {
                    showUnsupportedDropAlert = true
                    return
                }
                droppedFiles = candidates
                saveDroppedFiles = activePage == .saved
                dropSpaceName = identity.spaceName.trimmingCharacters(in: .whitespacesAndNewlines)
                if dropSpaceName.isEmpty || dropSpaceName == "?" {
                    dropSpaceName = "your Airclip Space"
                }
                showFileDropConfirmation = true
            }
        }
        return true
    }

    private static func fileURL(from item: NSSecureCoding?) -> URL? {
        if let url = item as? URL, url.isFileURL { return url }
        if let url = item as? NSURL, url.isFileURL { return url as URL }
        if let data = item as? Data {
            if let url = URL(dataRepresentation: data, relativeTo: nil), url.isFileURL { return url }
            if let string = String(data: data, encoding: .utf8),
               let url = URL(string: string), url.isFileURL { return url }
        }
        if let string = item as? String,
           let url = URL(string: string), url.isFileURL { return url }
        return nil
    }

    private func shareDroppedFiles() {
        guard SyncModeStore.shared.mode.allowsOutboundSync else { return }
        let files = droppedFiles
        showFileDropConfirmation = false
        let packets = files.compactMap { ClipboardCapture.packet(forDroppedFile: $0.url) }
        guard !packets.isEmpty else {
            showUnsupportedDropAlert = true
            return
        }
        packets.forEach { SyncEngine.shared.sendClipboard(packet: $0, isSaved: saveDroppedFiles) }
        let count = packets.count
        alertCenter.show(
            saveDroppedFiles
                ? (count == 1 ? "Shared and saved" : "Shared and saved \(count) items")
                : (count == 1 ? "Added to \(dropSpaceName)" : "Added \(count) items to \(dropSpaceName)"),
            kind: .success
        )
    }

    private var sidebarColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(spacing: 12) {
                ForEach([MainPage.home, .saved, .devices], id: \.self) { page in
                    SidebarNavItem(
                        page: page,
                        isActive: activePage == page,
                        count: page == .saved ? savedCount : nil
                    ) {
                        withAnimation(.easeOut(duration: 0.16)) {
                            activePage = page
                        }
                    }
                }
            }
            .padding(.top, 16)

            Spacer(minLength: 20)

            SidebarNavItem(page: .settings, isActive: activePage == .settings, count: nil) {
                activePage = .settings
            }
            .padding(.bottom, 8)
        }
        .frame(width: MainWindowLayout.sidebarInnerWidth, height: MainWindowLayout.contentHeight)
        .padding(.horizontal, MainWindowLayout.sidebarHorizontalPadding)
        .frame(width: MainWindowLayout.sidebarWidth, height: MainWindowLayout.contentHeight)
        .background(MainWindowPalette.shell)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(Color.black.opacity(0.05))
                .frame(width: 1)
        }
        // Sidebar tooltips extend into the detail column and must render above it.
        .zIndex(1)
    }

    @ViewBuilder
    private var detailContent: some View {
        ZStack(alignment: .topLeading) {
            Group {
                switch activePage {
                case .home:
                    ClipboardWorkspace(
                        filter: .all,
                        workspaceWidth: currentMainCardWidth,
                        workspaceHeight: currentMainCardHeight,
                    )
                case .saved:
                    ClipboardWorkspace(
                        filter: .saved,
                        workspaceWidth: currentMainCardWidth,
                        workspaceHeight: currentMainCardHeight,
                    )
                case .devices:
                    DevicesPanel()
                case .settings:
                    SettingsPanel()
                }
            }
            .id(activePage)
            .transition(.opacity)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: activePage)
            .frame(width: currentMainCardWidth, height: currentMainCardHeight)
            .background(MainWindowPalette.card)
            .overlay(alignment: .leading) {
                MainWindowPalette.divider.frame(width: 0.5)
            }
            .padding(.leading, MainWindowLayout.mainCardLeadingInset)
            .padding(.top, MainWindowLayout.mainCardTopInset)
        }
        .frame(width: currentDetailAreaWidth, height: MainWindowLayout.contentHeight, alignment: .topLeading)
    }
}

private struct SidebarNavItem: View {
    let page: MainPage
    let isActive: Bool
    let count: Int?
    let onSelect: () -> Void

    @State private var isHovered = false
    @State private var isPressed = false

    var body: some View {
        Button {
            onSelect()
        } label: {
            rowLabel
        }
        .buttonStyle(.plain)
        .overlay(alignment: .leading) {
            if isHovered {
                HStack(spacing: MainWindowLayout.navTooltipGap) {
                    // This spacer aligns the tooltip to the 40pt target's trailing edge.
                    Color.clear
                        .frame(width: (MainWindowLayout.sidebarInnerWidth + MainWindowLayout.navItemSize) / 2)

                    Text(page.rawValue)
                        .font(.system(size: MainWindowLayout.navTooltipFontSize, weight: .regular))
                        .foregroundStyle(.white)
                        .padding(.horizontal, MainWindowLayout.navTooltipHorizontalPadding)
                        .padding(.vertical, MainWindowLayout.navTooltipVerticalPadding)
                        .background(Color.black, in: RoundedRectangle(cornerRadius: MainWindowLayout.navTooltipCornerRadius))
                        .fixedSize()
                }
                .fixedSize()
                .transition(.opacity)
                .zIndex(10)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
        }
        .zIndex(isHovered ? 10 : 0)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(isActive ? "Selected" : "")
        .onHover { hovering in
            withAnimation(.easeOut(duration: MainWindowMotion.hoverDuration)) {
                isHovered = hovering
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed {
                        withAnimation(.easeOut(duration: MainWindowMotion.pressDuration)) {
                            isPressed = true
                        }
                    }
                }
                .onEnded { _ in
                    withAnimation(.easeOut(duration: MainWindowMotion.releaseDuration)) {
                        isPressed = false
                    }
                }
        )
    }

    private var rowLabel: some View {
        HStack(spacing: 0) {
            AirclipIcon(page.icon, size: MainWindowLayout.navIconSize, variant: isActive ? .automatic : .stroke)
                .foregroundColor(navForegroundColor)
                .frame(width: MainWindowLayout.navIconSize, height: MainWindowLayout.navIconSize)
        }
        .frame(width: MainWindowLayout.navItemSize, height: MainWindowLayout.navItemSize)
        .background(navBackground)
        .scaleEffect(isPressed ? MainWindowMotion.navPressScale : 1)
        .contentShape(RoundedRectangle(cornerRadius: MainWindowLayout.navCornerRadius, style: .continuous))
        .frame(width: MainWindowLayout.sidebarInnerWidth, height: MainWindowLayout.navItemSize)
    }

    private var navBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: MainWindowLayout.navCornerRadius, style: .continuous)
                .fill(backgroundColor)
        }
    }

    @ViewBuilder
    private var countBadge: some View {
        if let count, count > 0 {
            Text(countLabel(count))
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(countForegroundColor)
                .monospacedDigit()
                .lineLimit(1)
                .frame(minWidth: 16)
                .frame(height: 16)
                .padding(.horizontal, count > 9 ? 4 : 0)
                .background(Capsule(style: .continuous).fill(countBackgroundColor))
                .accessibilityHidden(true)
        }
    }

    private var backgroundColor: Color {
        if isPressed { return Color.black.opacity(0.10) }
        if isHovered { return Color.black.opacity(0.06) }
        return .clear
    }

    private var navForegroundColor: Color {
        if isActive { return MainWindowPalette.primaryText }
        if isHovered { return MainWindowPalette.primaryText }
        return MainWindowPalette.sidebarText
    }

    private var countForegroundColor: Color {
        navForegroundColor
    }

    private var countBackgroundColor: Color {
        isActive ? MainWindowPalette.sidebarActiveFill : MainWindowPalette.sidebarHoverFill
    }

    private var accessibilityLabel: String {
        if page == .saved, let count, count > 0 {
            return "\(page.rawValue), \(count) saved clips"
        }
        return page.rawValue
    }

    private func countLabel(_ count: Int) -> String {
        count > 99 ? "99+" : "\(count)"
    }
}

struct AirclipLogoMark: View {
    var body: some View {
        Image(nsImage: MacSplashSVG.image(from: MacSplashSVG.logo))
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .foregroundStyle(Color.accent)
        .frame(width: 97, height: 24, alignment: .leading)
    }
}

struct AirclipEmptyLogoMark: View {
    let size: CGFloat
    let color: Color

    var body: some View {
        Image("menubar-default")
            .renderingMode(.template)
            .resizable()
            .interpolation(.high)
            .antialiased(true)
            .scaledToFit()
            .foregroundColor(color)
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

struct AirclipFigmaEmptyState: View {
    let icon: AirclipIconName
    let title: String
    let message: String
    var badgeIcon: AirclipIconName? = nil
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil
    var compact = false

    var body: some View {
        VStack(spacing: compact ? 10 : 16) {
            ZStack(alignment: .bottomTrailing) {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(MainWindowPalette.searchFill)
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(MainWindowPalette.divider, lineWidth: 0.5)
                    }
                    .overlay {
                        AirclipIcon(icon, size: compact ? 20 : 28, variant: .stroke)
                            .foregroundColor(MainWindowPalette.secondaryText)
                    }
                    .frame(width: compact ? 40 : 56, height: compact ? 40 : 56)

                if let badgeIcon {
                    Circle()
                        .fill(MainWindowPalette.card)
                        .overlay {
                            Circle()
                                .strokeBorder(MainWindowPalette.divider, lineWidth: 0.5)
                        }
                        .overlay {
                            AirclipIcon(badgeIcon, size: 13, variant: .stroke)
                                .foregroundColor(MainWindowPalette.secondaryText)
                        }
                        .frame(width: 24, height: 24)
                        .offset(x: 4, y: 4)
                }
            }

            VStack(spacing: compact ? 4 : 6) {
                Text(title)
                    .font(.system(size: compact ? 13 : 15, weight: .semibold))
                    .foregroundColor(MainWindowPalette.primaryText)
                    .multilineTextAlignment(.center)

                Text(message)
                    .font(.system(size: compact ? 11 : 12))
                    .lineSpacing(compact ? 2 : 3)
                    .foregroundColor(MainWindowPalette.secondaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.system(size: 12, weight: .medium))
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
        .frame(maxWidth: compact ? 220 : 260)
        .padding(compact ? 10 : 20)
        .accessibilityElement(children: .contain)
    }
}

private enum ClipFilter {
    case all
    case saved
}

private enum ClipTypeFilter: String, CaseIterable {
    case all
    case text
    case links
    case images
    case files
    case colors

    var title: String {
        switch self {
        case .all: return "All"
        case .text: return "Text"
        case .links: return "Links"
        case .images: return "Images"
        case .files: return "Files"
        case .colors: return "Color"
        }
    }

    var clipType: ClipType? {
        switch self {
        case .all: return nil
        case .text: return .text
        case .links: return .url
        case .images: return .image
        case .files: return .file
        case .colors: return .color
        }
    }
}

private struct ClipboardItemGroup: Identifiable {
    let title: String
    let items: [ClipboardItem]

    var id: String { title }
}

private struct ClipboardWorkspace: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \ClipboardItem.receivedAt, order: .reverse) private var allItems: [ClipboardItem]
    @ObservedObject private var syncModeStore = SyncModeStore.shared
    @ObservedObject private var syncEngine = SyncEngine.shared

    let filter: ClipFilter
    let workspaceWidth: CGFloat
    let workspaceHeight: CGFloat
    @State private var selectedItem: ClipboardItem?
    @State private var selectedPreviewText = ""
    @State private var selectedPreviewItemID: UUID?
    @State private var searchQuery = ""
    @State private var selectedTypeFilter: ClipTypeFilter = .all
    @State private var filtersVisible = false
    @State private var typeFilterScrollTarget: ClipTypeFilter? = .all
    @State private var canScrollFiltersLeft = false
    @State private var canScrollFiltersRight = false
    @State private var hoveredFilterScrollDirection: Int?
    @State private var hoveredItemID: UUID?
    @State private var knownItemIDs = Set<UUID>()
    @State private var animateRemoteInsertion = false
    @FocusState private var searchFocused: Bool

    private var filteredItems: [ClipboardItem] {
        var items = allItems
        if filter == .saved {
            items = items.filter(\.isSaved)
        }
        if let clipType = selectedTypeFilter.clipType {
            items = items.filter { $0.displayType == clipType }
        }
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return items }
        return items.filter { item in
            item.text.localizedCaseInsensitiveContains(query) ||
                clipTypeLabel(for: item.displayType).localizedCaseInsensitiveContains(query) ||
                deviceLabel(for: item).localizedCaseInsensitiveContains(query)
        }
    }

    private var groupedItems: [ClipboardItemGroup] {
        let calendar = Calendar.current
        let today = filteredItems.filter { calendar.isDateInToday($0.receivedAt) }
        let yesterday = filteredItems.filter { calendar.isDateInYesterday($0.receivedAt) }
        let earlier = filteredItems.filter {
            !calendar.isDateInToday($0.receivedAt) && !calendar.isDateInYesterday($0.receivedAt)
        }

        return [
            ClipboardItemGroup(title: "Today", items: today),
            ClipboardItemGroup(title: "Yesterday", items: yesterday),
            ClipboardItemGroup(title: "Earlier", items: earlier)
        ].filter { !$0.items.isEmpty }
    }

    private var selectedItemIsValid: Bool {
        guard let selectedItem else { return false }
        return filteredItems.contains { $0.id == selectedItem.id }
    }

    var body: some View {
        HStack(spacing: 0) {
            listPane
            previewPane
        }
        .frame(width: workspaceWidth, height: workspaceHeight)
        .onAppear {
            knownItemIDs = Set(allItems.map(\.id))
            ensureSelection()
        }
        .onChange(of: allItems) { _, _ in
            let inserted = allItems.filter { !knownItemIDs.contains($0.id) }
            animateRemoteInsertion = !reduceMotion && inserted.contains { item in
                !item.isLocal && filteredItems.contains { $0.id == item.id }
            }
            knownItemIDs = Set(allItems.map(\.id))
            ensureSelection()
        }
        .onChange(of: filter) { _, _ in ensureSelection() }
        .onChange(of: searchQuery) { _, _ in ensureSelection() }
        .onChange(of: selectedTypeFilter) { _, _ in ensureSelection() }
        .onChange(of: selectedItem?.id) { _, _ in
            selectedPreviewText = ""
            selectedPreviewItemID = nil
        }
        .onReceive(NotificationCenter.default.publisher(for: NSTextView.didChangeSelectionNotification)) { notification in
            guard let item = selectedItem,
                  let textView = notification.object as? NSTextView,
                  textView.string == item.text else { return }
            let selection = textView.selectedRange()
            guard selection.length > 0,
                  NSMaxRange(selection) <= (textView.string as NSString).length else {
                selectedPreviewText = ""
                selectedPreviewItemID = nil
                return
            }
            selectedPreviewText = (textView.string as NSString).substring(with: selection)
            selectedPreviewItemID = item.id
        }
        .onKeyPress(.space) {
            guard !searchFocused,
                  let selectedItem,
                  selectedItem.clipType == .image,
                  let imageData = selectedItem.imageData else { return .ignored }
            QuickLookImagePreviewer.shared.show(imageData: imageData, name: selectedItem.text)
            return .handled
        }
    }

    private var listPane: some View {
        VStack(alignment: .leading, spacing: 0) {
            searchBar
            if filtersVisible {
                typeFilterRow
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .offset(y: -4)))
            }
            if syncModeStore.mode == .manualOnly {
                manualSendRow
            }
            if filteredItems.isEmpty {
                emptyListState
                    .transition(.opacity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8, pinnedViews: [.sectionHeaders]) {
                        ForEach(groupedItems) { group in
                            Section {
                                ForEach(group.items) { item in
                                    clipRow(item)
                                        .padding(.horizontal, MainWindowLayout.listRowHorizontalInset)
                                        .transition(remoteItemTransition)
                                }
                            } header: {
                                sectionHeader(group.title)
                            }
                        }
                    }
                    .padding(.bottom, 8)
                    .animation(animateRemoteInsertion ? .spring(response: 0.28, dampingFraction: 0.82) : nil, value: filteredItems.map(\.id))
                }
                .scrollIndicators(.never)
                .simultaneousGesture(TapGesture().onEnded { searchFocused = false })
                .transition(.opacity)
            }
        }
        .frame(width: MainWindowLayout.listWidth, height: workspaceHeight)
        .background(MainWindowPalette.card)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(MainWindowPalette.divider)
                .frame(width: 1)
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: filtersVisible)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: filteredItems.isEmpty)
    }

    private var remoteItemTransition: AnyTransition {
        reduceMotion ? .opacity : .asymmetric(
            insertion: .move(edge: .top).combined(with: .opacity),
            removal: .move(edge: .bottom).combined(with: .opacity)
        )
    }

    private var manualSendRow: some View {
        Button {
            searchFocused = false
            ManualClipboardSender.sendCurrentClipboard()
        } label: {
            Label("Send Clipboard", systemImage: "paperplane.fill")
                .font(.system(size: 11, weight: .medium))
                .frame(maxWidth: .infinity)
                .frame(height: 28)
        }
        .buttonStyle(.borderedProminent)
        .tint(.primaryButtonFill)
        .padding(.horizontal, MainWindowLayout.listSearchHorizontalInset)
        .padding(.bottom, 8)
    }

    private var searchBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                AirclipIcon(.search, size: 16, variant: .stroke)
                    .foregroundColor(MainWindowPalette.secondaryText)
                TextField(
                    "",
                    text: $searchQuery,
                    prompt: Text("Search words or type")
                        .foregroundColor(MainWindowPalette.tertiaryText)
                )
                    .font(.system(size: 14))
                    .foregroundColor(MainWindowPalette.primaryText)
                    .textFieldStyle(.plain)
                    .focused($searchFocused)
                searchTrailingControl
            }
            .padding(.horizontal, MainWindowLayout.searchBarContentHorizontalInset)
            .frame(maxWidth: .infinity, minHeight: 44, idealHeight: 44, maxHeight: 44)
            .background(searchBackground)
            .overlay(searchBorder)
            .contentShape(Capsule())
            .onTapGesture {
                searchFocused = true
            }
            .animation(.easeOut(duration: 0.12), value: searchFocused)
        }
        .padding(.horizontal, MainWindowLayout.listSearchHorizontalInset)
        .padding(.top, 16)
        .frame(width: MainWindowLayout.listWidth, height: MainWindowLayout.listSearchHeight, alignment: .topLeading)
    }

    private var searchBackground: some View {
        Capsule()
            .fill(searchFocused ? MainWindowPalette.card : MainWindowLayout.searchBackground)
    }

    private var searchBorder: some View {
        Capsule()
            .strokeBorder(searchFocused ? MainWindowPalette.focusStroke : MainWindowLayout.searchBorder, lineWidth: 1)
    }

    @ViewBuilder
    private var searchTrailingControl: some View {
        if !searchQuery.isEmpty {
            Button {
                searchQuery = ""
                searchFocused = true
            } label: {
                AirclipIcon(.close, size: 10)
                    .foregroundColor(MainWindowPalette.secondaryText)
                    .frame(width: 16, height: 16)
                    .background(
                        Circle()
                            .fill(MainWindowPalette.activeFill)
                    )
            }
            .buttonStyle(.plain)
            .help("Clear search")
            .accessibilityLabel("Clear search")
            .transition(.opacity)
        }
        Button {
            searchFocused = false
            filtersVisible.toggle()
        } label: {
            Group {
                if filtersVisible {
                    AirclipIcon(.filterActive, size: 18)
                        .foregroundColor(Color.textSecondary)
                } else {
                    AirclipIcon(.filter, size: 18)
                        .foregroundColor(MainWindowPalette.secondaryText)
                }
            }
                .frame(width: 24, height: 24)
        }
        .buttonStyle(.plain)
        .help(filtersVisible ? "Hide filters" : "Show filters")
        .accessibilityLabel(filtersVisible ? "Hide filters" : "Show filters")
        .accessibilityValue(selectedTypeFilter == .all ? "All clips" : selectedTypeFilter.title)
        .animation(.easeOut(duration: 0.10), value: searchQuery.isEmpty)
    }

    private var typeFilterRow: some View {
        ScrollViewReader { proxy in
            ZStack {
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(ClipTypeFilter.allCases, id: \.self) { typeFilter in
                            typeFilterButton(typeFilter)
                                .id(typeFilter)
                        }
                    }
                    // Match the search glyph's inset within the search field so
                    // the first filter starts on the same vertical guide.
                    .padding(.horizontal, MainWindowLayout.searchBarContentHorizontalInset)
                    .scrollTargetLayout()
                }
                .scrollIndicators(.never)
                .scrollPosition(id: $typeFilterScrollTarget, anchor: .center)
                .onScrollGeometryChange(for: Bool.self) { geometry in
                    geometry.contentOffset.x > 1
                } action: { _, canScroll in
                    canScrollFiltersLeft = canScroll
                }
                .onScrollGeometryChange(for: Bool.self) { geometry in
                    geometry.contentOffset.x + geometry.containerSize.width < geometry.contentSize.width - 1
                } action: { _, canScroll in
                    canScrollFiltersRight = canScroll
                }
                .simultaneousGesture(TapGesture().onEnded { searchFocused = false })

                HStack(spacing: 0) {
                    if canScrollFiltersLeft {
                        filterScrollButton(direction: -1, proxy: proxy)
                            .transition(.opacity)
                    }
                    Spacer()
                    if canScrollFiltersRight {
                        filterScrollButton(direction: 1, proxy: proxy)
                            .transition(.opacity)
                    }
                }
                .animation(.easeOut(duration: 0.12), value: canScrollFiltersLeft)
                .animation(.easeOut(duration: 0.12), value: canScrollFiltersRight)
            }
        }
        .frame(height: MainWindowLayout.filterScrollTargetSize)
        .padding(.horizontal, MainWindowLayout.listSearchHorizontalInset)
        .padding(.top, MainWindowLayout.filterRowTopGap)
        .padding(.bottom, 16)
    }

    private func filterScrollButton(direction: Int, proxy: ScrollViewProxy) -> some View {
        let filters = ClipTypeFilter.allCases
        return Button {
            searchFocused = false
            // Arrow controls are end stops, not paging controls. Direct
            // dragging remains free to stop anywhere between these endpoints.
            let target = direction < 0 ? filters[0] : filters[filters.count - 1]
            let anchor: UnitPoint = direction < 0 ? .leading : .trailing
            if reduceMotion {
                typeFilterScrollTarget = target
                proxy.scrollTo(target, anchor: anchor)
            } else {
                withAnimation(.timingCurve(0.77, 0, 0.175, 1, duration: 0.24)) {
                    typeFilterScrollTarget = target
                    proxy.scrollTo(target, anchor: anchor)
                }
            }
        } label: {
            Image(systemName: direction < 0 ? "chevron.left" : "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(MainWindowPalette.secondaryText)
                .frame(
                    width: MainWindowLayout.filterScrollTargetSize,
                    height: MainWindowLayout.filterScrollTargetSize
                )
                .background {
                    LinearGradient(
                        colors: [MainWindowPalette.card, MainWindowPalette.card.opacity(0)],
                        startPoint: direction < 0 ? .leading : .trailing,
                        endPoint: direction < 0 ? .trailing : .leading
                    )
                    if hoveredFilterScrollDirection == direction {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(MainWindowPalette.hoverFill)
                            .padding(4)
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(FilterArrowPressStyle())
        .onHover { hovering in
            withAnimation(.easeOut(duration: MainWindowMotion.hoverDuration)) {
                hoveredFilterScrollDirection = hovering ? direction : nil
            }
        }
        .help(direction < 0 ? "Previous filters" : "Next filters")
        .accessibilityLabel(direction < 0 ? "Previous filters" : "Next filters")
    }

    private func typeFilterButton(_ typeFilter: ClipTypeFilter) -> some View {
        let selected = selectedTypeFilter == typeFilter
        return Button {
            searchFocused = false
            selectedTypeFilter = typeFilter
            typeFilterScrollTarget = typeFilter
        } label: {
            Text(typeFilter.title)
                .font(.system(size: 11, weight: selected ? .semibold : .regular))
                .foregroundColor(selected ? MainWindowPalette.card : MainWindowPalette.secondaryText)
                .lineLimit(1)
                .padding(.horizontal, 12)
                .frame(height: 24)
                .background(
                    Capsule()
                        .fill(selected ? MainWindowPalette.primaryText : MainWindowPalette.card)
                )
                .overlay(
                    Capsule()
                        .strokeBorder(selected ? .clear : MainWindowPalette.rowStroke, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.12), value: selected)
        .help("Show \(typeFilter.title.lowercased()) clips")
        .accessibilityLabel("Show \(typeFilter.title.lowercased()) clips")
        .accessibilityValue(selected ? "Selected" : "")
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(MainWindowLayout.sectionHeaderText)
            .padding(.horizontal, MainWindowLayout.listHeaderHorizontalInset)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(MainWindowPalette.card)
            .contentShape(Rectangle())
            .onTapGesture { searchFocused = false }
    }

    private func clipRow(_ item: ClipboardItem) -> some View {
        let active = selectedItem?.id == item.id
        let hovered = hoveredItemID == item.id
        return Button {
            searchFocused = false
            selectedItem = item
        } label: {
            HStack(alignment: .center, spacing: 10) {
                clipTypeBadge(for: item)
                VStack(alignment: .leading, spacing: 4) {
                    if item.clipType == .url {
                        URLClipRowText(item: item)
                    } else {
                        Text(item.text)
                            .font(titleFont(for: item))
                            .foregroundColor(titleColor(for: item))
                            .lineSpacing(2.2)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    HStack(spacing: 0) {
                        Text(relativeTime(item.receivedAt))
                    }
                    .font(.system(size: 12))
                    .foregroundColor(MainWindowLayout.listMetaText)
                }
            }
            .padding(8)
            .frame(height: MainWindowLayout.rowHeight)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(rowBackground(active: active, hovered: hovered))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(rowStroke(active: active, hovered: hovered), lineWidth: rowStrokeWidth(active: active, hovered: hovered))
                    )
            )
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: MainWindowMotion.hoverDuration)) {
                if hovering {
                    hoveredItemID = item.id
                } else if hoveredItemID == item.id {
                    hoveredItemID = nil
                }
            }
        }
        .contextMenu {
            if item.clipType == .file {
                Button {
                    fileAction(item)
                } label: {
                    Label(fileActionLabel(item), systemImage: fileActionSystemImage(item))
                }
                .disabled(!fileActionIsEnabled(item))
                if syncEngine.availableFileURL(for: item) != nil {
                    Button {
                        copy(item)
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                }
            } else {
                Button {
                    copy(item)
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                Button {
                    toggleSaved(item)
                } label: {
                    Label(item.isSaved ? "Saved" : "Save", systemImage: item.isSaved ? "bookmark.fill" : "bookmark")
                }
            }
            Divider()
            Button(role: .destructive) {
                delete(item)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func rowBackground(active: Bool, hovered: Bool) -> Color {
        if active { return MainWindowPalette.itemSelectedFill }
        if hovered { return MainWindowPalette.itemHoverFill }
        return .clear
    }

    private func rowStroke(active: Bool, hovered: Bool) -> Color {
        if active { return MainWindowPalette.itemSelectedBorder }
        return .clear
    }

    private func rowStrokeWidth(active: Bool, hovered: Bool) -> CGFloat {
        active ? 0.5 : 0
    }

    private var emptyListState: some View {
        Group {
            if usesDefaultEmptyState {
                AirclipFigmaEmptyState(
                    icon: .clipboard,
                    title: "Nothing copied yet",
                    message: "Copy on this Mac or a connected device to get started.",
                    badgeIcon: .deviceSync
                )
            } else {
                AirclipFigmaEmptyState(
                    icon: emptyListIcon,
                    title: emptyListTitle,
                    message: emptyListSubtitle,
                    actionTitle: searchQuery.isEmpty ? nil : "Clear search and type filter",
                    action: searchQuery.isEmpty ? nil : clearSearchAndTypeFilter
                )
            }
        }
        .frame(width: MainWindowLayout.rowWidth)
        .padding(.horizontal, 8)
        .padding(.top, 76)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var usesDefaultEmptyState: Bool {
        searchQuery.isEmpty && selectedTypeFilter == .all && filter != .saved
    }

    private var emptyListIcon: AirclipIconName {
        filter == .saved ? .bookmark : .clipboard
    }

    private var emptyListTitle: String {
        if !searchQuery.isEmpty { return "No matches" }
        if selectedTypeFilter != .all { return "No \(selectedTypeFilter.title.lowercased()) clips yet" }
        return filter == .saved ? "Nothing saved yet" : "Nothing here yet"
    }

    private var emptyListSubtitle: String {
        if !searchQuery.isEmpty { return "Try another search, or clear the search and type filter." }
        if selectedTypeFilter != .all { return "Clips matching this type will appear here." }
        return filter == .saved ? "Save a clip to keep it here." : "Copy on this Mac or a connected device to get started."
    }

    private func clearSearchAndTypeFilter() {
        searchQuery = ""
        selectedTypeFilter = .all
        typeFilterScrollTarget = .all
    }

    @ViewBuilder
    private func clipTypeBadge(for item: ClipboardItem) -> some View {
        let type = item.clipType
        switch type {
        case .text:
            clipBadge(background: MainWindowLayout.textBadgeFill) {
                AirclipIcon(.text, size: MainWindowLayout.rowIconWidth)
                    .foregroundColor(MainWindowLayout.textBadgeForeground)
            }
        case .url:
            clipBadge(background: MainWindowLayout.linkBadgeFill) {
                AirclipIcon(.link, size: MainWindowLayout.rowIconWidth)
                    .foregroundColor(MainWindowLayout.linkBadgeForeground)
            }
        case .image:
            clipBadge(
                background: item.imageData == nil
                    ? MainWindowLayout.imageBadgeFill
                    : MainWindowLayout.imagePreviewBadgeFill
            ) {
                if let image = item.imageData.flatMap(NSImage.init(data:)) {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 27, height: 27)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                } else {
                    AirclipIcon(.image, size: MainWindowLayout.rowIconWidth)
                        .foregroundColor(MainWindowLayout.imageBadgeForeground)
                }
            }
        case .file:
            clipBadge(
                background: (item.fileMetadata?.iconAccentColor ?? MainWindowLayout.fileIconFallbackColor).opacity(0.07),
                showsBorder: false
            ) {
                if item.fileMetadata?.isImage == true,
                   let thumbnail = item.fileMetadata?.thumbnailImage {
                    Image(nsImage: thumbnail)
                        .resizable().aspectRatio(contentMode: .fill)
                        .frame(width: 27, height: 27).clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                } else if item.fileMetadata?.isImage == true {
                    AirclipIcon(.image, size: MainWindowLayout.rowIconWidth)
                        .foregroundColor(MainWindowLayout.imageBadgeForeground)
                } else {
                    Image(item.fileMetadata?.iconAssetName ?? "FileIconDocument")
                        .resizable().interpolation(.high).frame(width: 20, height: 20)
                }
            }
        case .email:
            clipBadge(background: MainWindowLayout.textBadgeFill) {
                AirclipIcon(.text, size: MainWindowLayout.rowIconWidth)
                    .foregroundColor(MainWindowLayout.textBadgeForeground)
            }
        case .color:
            clipBadge(background: MainWindowLayout.colorBadgeFill) {
                ColorCircleTypeIcon(color: parsedColor(for: item) ?? MainWindowLayout.colorBadgeForeground)
                    .frame(width: MainWindowLayout.rowIconWidth, height: MainWindowLayout.rowIconWidth)
            }
        }
    }

    private func clipBadge<Content: View>(
        background: Color,
        showsBorder: Bool = true,
        @ViewBuilder content: () -> Content
    ) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(background)
            if showsBorder {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(MainWindowLayout.badgeBorder, lineWidth: 0.5)
            }
            content()
        }
        .frame(width: 28, height: 28)
    }

    private func titleFont(for item: ClipboardItem) -> Font {
        .system(size: 13, weight: .regular)
    }

    private func titleColor(for item: ClipboardItem) -> Color {
        switch item.clipType {
        case .url:
            return MainWindowLayout.linkBadgeForeground
        case .email:
            return MainWindowLayout.listTitleText
        case .color:
            return MainWindowLayout.listTitleText
        case .image, .file:
            return MainWindowLayout.listTitleText
        case .text:
            return MainWindowLayout.listTitleText
        }
    }

    private func parsedColor(for item: ClipboardItem) -> Color? {
        Color.parseHex(item.text)
    }

    private var previewPane: some View {
        ZStack(alignment: .bottomTrailing) {
            if let selectedItem {
                ScrollView {
                    PreviewContent(
                        item: selectedItem,
                        sourceLabel: deviceLabel(for: selectedItem),
                        minimumHeight: max(
                            workspaceHeight
                                - MainWindowLayout.previewTopInset
                                - MainWindowLayout.previewBottomInset,
                            0
                        )
                        , onQuickLook: { imageData, name in
                            QuickLookImagePreviewer.shared.show(imageData: imageData, name: name)
                        }
                    )
                        .padding(.top, MainWindowLayout.previewTopInset)
                        .padding(.leading, MainWindowLayout.previewLeadingInset)
                        .padding(.trailing, MainWindowLayout.previewTrailingInset)
                        .padding(.bottom, MainWindowLayout.previewBottomInset)
                }
                .scrollIndicators(.never)
                .id(selectedItem.id)
                .transition(.opacity)
                .background(MainWindowPalette.card)
                .overlay(alignment: .bottom) {
                    LinearGradient(
                        colors: [
                            MainWindowPalette.card.opacity(0.0),
                            MainWindowPalette.card.opacity(0.92),
                            MainWindowPalette.card
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 144)
                    .allowsHitTesting(false)
                }

                FloatingActions(
                    isSaved: selectedItem.isSaved,
                    isFile: selectedItem.clipType == .file,
                    fileIsAvailable: selectedItem.clipType == .file && syncEngine.availableFileURL(for: selectedItem) != nil,
                    onOpenBrowser: selectedItem.clipType == .url ? { openInBrowser(selectedItem) } : nil,
                    onCopy: { copy(selectedItem) },
                    onFileAction: selectedItem.clipType == .file ? { fileAction(selectedItem) } : nil,
                    fileActionLabel: selectedItem.clipType == .file ? fileActionLabel(selectedItem) : nil,
                    fileActionIcon: selectedItem.clipType == .file ? fileActionIcon(selectedItem) : nil,
                    fileActionIsEnabled: selectedItem.clipType != .file || fileActionIsEnabled(selectedItem),
                    onSave: { toggleSaved(selectedItem) },
                    onDelete: { delete(selectedItem) }
                )
                .padding(.trailing, MainWindowLayout.previewActionTrailingInset)
                .padding(.bottom, MainWindowLayout.previewActionBottomInset)
                .zIndex(1)
            } else {
                emptyPreviewState
                    .transition(.opacity)
            }
        }
        .frame(width: previewWidth, height: workspaceHeight)
        .background(MainWindowPalette.card)
        .onTapGesture { searchFocused = false }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: selectedItem?.id)
    }

    private var previewWidth: CGFloat {
        max(workspaceWidth - MainWindowLayout.listWidth, MainWindowLayout.previewMinWidth)
    }

    private var emptyPreviewState: some View {
        AirclipFigmaEmptyState(
            icon: .document,
            title: "Choose a clip",
            message: "Select an item in your history to preview its content."
        )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func ensureSelection() {
        if !selectedItemIsValid {
            selectedItem = filteredItems.first
        }
    }

    private func copy(_ item: ClipboardItem) {
        if let selectedText = selectedText(for: item) {
            ClipboardMonitor.shared.suppressNextChange()
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(selectedText, forType: .string)
            AirclipAlertCenter.shared.show("Selection copied", kind: .success)
            return
        }

        if item.clipType == .file {
            let copied = syncEngine.withAvailableFileURL(for: item) { url in
                ClipboardMonitor.shared.suppressNextChange()
                NSPasteboard.general.clearContents()
                return NSPasteboard.general.writeObjects([url as NSURL])
            } ?? false
            if copied { AirclipAlertCenter.shared.show("Copied", kind: .success) }
            return
        }
        ClipboardMonitor.shared.suppressPacket(item.clipboardPacket)
        ClipboardCapture.write(item.clipboardPacket, to: NSPasteboard.general)
        AirclipAlertCenter.shared.show("Copied", kind: .success)
    }

    private func selectedText(for item: ClipboardItem) -> String? {
        if selectedPreviewItemID == item.id, !selectedPreviewText.isEmpty {
            return selectedPreviewText
        }
        guard let textView = NSApp.keyWindow?.firstResponder as? NSTextView,
              textView.string == item.text else { return nil }
        let selection = textView.selectedRange()
        guard selection.length > 0,
              NSMaxRange(selection) <= (textView.string as NSString).length else { return nil }
        return (textView.string as NSString).substring(with: selection)
    }

    private func fileAction(_ item: ClipboardItem) {
        if syncEngine.availableFileURL(for: item) != nil {
            _ = syncEngine.withAvailableFileURL(for: item) { NSWorkspace.shared.open($0) }
        } else {
            syncEngine.downloadFile(item)
        }
    }

    private func fileActionLabel(_ item: ClipboardItem) -> String {
        if syncEngine.availableFileURL(for: item) != nil {
            return item.fileMetadata?.isPlayableMedia == true ? "Play" : "Open"
        }
        if let id = item.fileMetadata?.id, let transfer = syncEngine.fileTransfers[id] {
            switch transfer.phase {
            case .checking: return "Checking…"
            case .downloading: return "Downloading…"
            case .failed: return "Try Again"
            case .downloaded: break
            }
        }
        return "Download"
    }

    private func fileActionIcon(_ item: ClipboardItem) -> AirclipIconName {
        guard syncEngine.availableFileURL(for: item) != nil else { return .fileDownload }
        return item.fileMetadata?.isPlayableMedia == true ? .filePlay : .fileOpen
    }

    private func fileActionSystemImage(_ item: ClipboardItem) -> String {
        switch fileActionIcon(item) {
        case .filePlay: return "play"
        case .fileOpen: return "arrow.up.right.square"
        default: return "arrow.down.to.line"
        }
    }

    private func fileActionIsEnabled(_ item: ClipboardItem) -> Bool {
        guard let id = item.fileMetadata?.id else { return true }
        guard let transfer = syncEngine.fileTransfers[id] else { return true }
        return transfer.phase != .checking && transfer.phase != .downloading
    }

    private func openInBrowser(_ item: ClipboardItem) {
        let trimmed = item.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed) ?? URL(string: "https://\(trimmed)") else { return }
        NSWorkspace.shared.open(url)
    }

    private func toggleSaved(_ item: ClipboardItem) {
        item.isSaved.toggle()
        try? modelContext.save()
        if item.isSaved {
            AirclipAlertCenter.shared.show("Saved", kind: .success)
        } else {
            AirclipAlertCenter.shared.show("Removed from Saved")
        }
        if filter == .saved && !item.isSaved {
            selectedItem = filteredItems.first { $0.id != item.id }
        }
    }

    private func delete(_ item: ClipboardItem) {
        if selectedItem?.id == item.id {
            selectedItem = filteredItems.first { $0.id != item.id }
        }
        SyncEngine.shared.deleteHistoryItem(item)
        AirclipAlertCenter.shared.show("Clip deleted", kind: .success)
    }

    private func deviceLabel(for item: ClipboardItem) -> String {
        if item.isLocal {
            let name = AirclipIdentity.shared.deviceName
            return name.isEmpty ? "This Mac" : name
        }
        return AirclipIdentity.shared.pairedDevices[item.fromDeviceId]?.deviceName ?? "Unknown device"
    }

    private func clipTypeLabel(for type: ClipType) -> String {
        switch type {
        case .url: return "Link"
        case .color: return "Color"
        case .email: return "Email"
        case .image: return "Image"
        case .file: return "File"
        case .text: return "Text"
        }
    }

    private func relativeTime(_ date: Date) -> String {
        let diff = Int(Date().timeIntervalSince(date))
        if diff < 60  { return "\(max(diff, 1))s ago" }
        let mins = diff / 60
        if mins < 60  { return "\(mins)m ago" }
        let hours = mins / 60
        if hours < 24 { return "\(hours)h ago" }
        let cal = Calendar.current
        if cal.isDateInYesterday(date) { return "Yesterday" }
        let days = hours / 24
        if days < 7   { return "\(days)d ago" }
        let fmt = DateFormatter()
        fmt.dateFormat = cal.isDate(date, equalTo: Date(), toGranularity: .year) ? "MMM d" : "MMM d, yyyy"
        return fmt.string(from: date)
    }

}

private struct URLClipRowText: View {
    let item: ClipboardItem
    @State private var metadata: LinkPreviewMetadata?

    private var url: String {
        LinkPreviewLoader.urls(in: item.text).first?.absoluteString
            ?? item.text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        Text(hasTitle ? metadata!.title : url)
            .font(.system(size: 14, weight: .regular))
            .lineSpacing(2.6)
            .foregroundColor(.accent)
            .underline(hasTitle)
            .lineLimit(1)
            .truncationMode(.middle)
            .frame(maxWidth: .infinity, alignment: .leading)
        .task(id: item.id) {
            metadata = await LinkPreviewLoader.preview(for: url, includeImage: false)
        }
    }

    private var hasTitle: Bool { metadata?.hasExplicitTitle == true }
}

private struct ColorCircleTypeIcon: View {
    let color: Color

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 16, height: 16)
    }
}

private struct FileAvailabilityShimmer: View {
    @State private var phase: CGFloat = -0.8

    var body: some View {
        GeometryReader { geometry in
            LinearGradient(
                colors: [.clear, Color.primary.opacity(0.10), .clear],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: geometry.size.width * 0.55)
            .offset(x: phase * geometry.size.width)
            .onAppear {
                withAnimation(.linear(duration: 1.25).repeatForever(autoreverses: false)) {
                    phase = 1.8
                }
            }
        }
    }
}

private struct PreviewContent: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let item: ClipboardItem
    let sourceLabel: String
    let minimumHeight: CGFloat
    let onQuickLook: (Data, String) -> Void
    @State private var isURLHovered = false
    @State private var linkPreview: LinkPreviewMetadata?
    @State private var isLoadedPreviewVisible = false
    @ObservedObject private var syncEngine = SyncEngine.shared

    private var type: ClipType { item.clipType }
    private var parsedColor: Color? { Color.parseHex(item.text) }
    private var fileTransfer: FileTransferProgress? {
        guard let id = item.fileMetadata?.id else { return nil }
        return syncEngine.fileTransfers[id]
    }
    private var isCheckingFileAvailability: Bool {
        guard let transfer = fileTransfer else { return false }
        if case .checking = transfer.phase { return true }
        return false
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: previewSpacing) {
                if type == .file {
                    filePreview
                } else if type == .image, let image = previewImage {
                    imagePreview(image)
                } else if type == .url, let linkPreview {
                    linkPreviewCard(linkPreview)
                        .opacity(isLoadedPreviewVisible ? 1 : 0)
                } else if type == .text, let image = linkPreview?.image {
                    imagePreview(image)
                        .opacity(isLoadedPreviewVisible ? 1 : 0)
                } else if type == .color, let parsedColor {
                    colorCard(color: parsedColor)
                }

                if type == .image || type == .file {
                    EmptyView()
                } else if type == .url {
                    Button {
                        openURL()
                    } label: {
                        previewText(
                            foregroundColor: isURLHovered ? previewColor.opacity(0.84) : previewColor,
                            underline: false
                        )
                    }
                    .buttonStyle(.plain)
                    .textSelection(.enabled)
                    .onHover { hovering in
                        withAnimation(.easeOut(duration: MainWindowMotion.hoverDuration)) {
                            isURLHovered = hovering
                        }
                    }
                } else if type != .color {
                    previewText(foregroundColor: previewColor)
                        .textSelection(.enabled)
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)

            Spacer(minLength: 80)

            informationTable
        }
        .frame(maxWidth: .infinity, minHeight: minimumHeight, alignment: .topLeading)
        .task(id: item.id) {
            linkPreview = nil
            isLoadedPreviewVisible = false
            if type == .url {
                linkPreview = await LinkPreviewLoader.preview(for: item.text)
                guard linkPreview != nil else { return }
                await Task.yield()
                withAnimation(reduceMotion
                    ? .easeOut(duration: 0.10)
                    : .timingCurve(0.23, 1, 0.32, 1, duration: 0.15)) {
                    isLoadedPreviewVisible = true
                }
            } else if type == .text {
                for url in LinkPreviewLoader.urls(in: item.text) {
                    guard let preview = await LinkPreviewLoader.preview(for: url.absoluteString), preview.image != nil else { continue }
                    linkPreview = preview
                    await Task.yield()
                    withAnimation(reduceMotion
                        ? .easeOut(duration: 0.10)
                        : .timingCurve(0.23, 1, 0.32, 1, duration: 0.15)) {
                        isLoadedPreviewVisible = true
                    }
                    break
                }
            }
        }
    }

    private func linkPreviewCard(_ preview: LinkPreviewMetadata) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if let image = preview.image {
                imagePreview(image)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(preview.title)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(MainWindowPalette.primaryText)
                    .lineLimit(2)
                Text(preview.site)
                    .font(.system(size: 14))
                    .foregroundColor(MainWindowPalette.secondaryText)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func imagePreview(_ image: NSImage) -> some View {
        Button {
            if let imageData = item.imageData { onQuickLook(imageData, item.text) }
        } label: {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: 420, maxHeight: 320)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(MainWindowPalette.divider, lineWidth: 1)
                )
                .shadow(color: MainWindowPalette.divider.opacity(0.55), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var filePreview: some View {
        VStack(spacing: 16) {
            fileArtwork
            Text(item.fileMetadata?.name ?? item.text)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(MainWindowPalette.primaryText)
                .lineLimit(2)
            if let transfer = fileTransfer {
                switch transfer.phase {
                case .checking:
                    Text("Checking file availability…")
                        .foregroundColor(MainWindowPalette.secondaryText)
                case .downloading:
                    ProgressView(value: Double(transfer.received), total: Double(max(transfer.total, 1)))
                    Text("\(transfer.temporaryPreview ? "Preparing preview" : "Downloading") \(Int(Double(transfer.received) / Double(max(transfer.total, 1)) * 100))%")
                        .foregroundColor(MainWindowPalette.secondaryText)
                case .failed(let reason):
                    VStack(spacing: 8) {
                        Label(reason, systemImage: "exclamationmark.triangle")
                            .font(.system(size: 13))
                            .foregroundColor(MainWindowPalette.secondaryText)
                            .multilineTextAlignment(.center)
                        Button("Try Again") { syncEngine.downloadFile(item) }
                            .buttonStyle(.plain)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.accent)
                    }
                case .downloaded:
                    EmptyView()
                }
            }
        }
        .frame(maxWidth: .infinity)
        .onDisappear {
            syncEngine.clearPreviewFile(for: item)
        }
    }

    @ViewBuilder
    private var fileArtwork: some View {
        if let url = syncEngine.availablePreviewURL(for: item) {
            EmbeddedFileQuickLookPreview(url: url)
                .frame(maxWidth: 520)
                .frame(height: 420)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(MainWindowPalette.divider, lineWidth: 0.5))
                .overlay { fileAvailabilityShimmer }
        } else if let image = item.fileMetadata?.thumbnailImage {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 320, maxHeight: 220)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay { fileAvailabilityShimmer }
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill((item.fileMetadata?.iconAccentColor ?? MainWindowLayout.fileIconFallbackColor).opacity(0.05))
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(MainWindowLayout.badgeBorder, lineWidth: 0.5)
                Image(item.fileMetadata?.iconAssetName ?? "FileIconDocument")
                    .resizable().interpolation(.high).frame(width: 104, height: 104)
            }
            .frame(width: 136, height: 136)
            .frame(height: 160)
            .overlay { fileAvailabilityShimmer }
        }
    }

    @ViewBuilder
    private var fileAvailabilityShimmer: some View {
        if isCheckingFileAvailability && !reduceMotion {
            FileAvailabilityShimmer()
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private func colorCard(color: Color) -> some View {
        if let components = colorComponents {
            VStack(alignment: .leading, spacing: 16) {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(color)
                    .frame(height: 140)
                    .overlay(Text(components.hex)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Color.black.opacity(0.75), in: RoundedRectangle(cornerRadius: 8)))
                    .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(Color(hex: "#808080").opacity(0.5), lineWidth: 1))

                VStack(alignment: .leading, spacing: 2) {
                    colorCardRow(components.title, highlighted: true)
                    colorCardRow("Hex: \(components.hex)")
                    colorCardRow("RGB: \(components.red), \(components.green), \(components.blue)", highlighted: true)
                    colorCardRow("HSL: \(components.hsl)")
                }
                .padding(.horizontal, 10)
            }
            .padding(16)
            .frame(width: 286)
            .background(Color.bgFloating)
            .clipShape(RoundedRectangle(cornerRadius: 40, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 40, style: .continuous)
                .strokeBorder(Color.borderDefault, lineWidth: 1))
            .frame(maxWidth: .infinity)
        }
    }

    private func colorCardRow(_ value: String, highlighted: Bool = false) -> some View {
        Text(value)
            .font(.system(size: 14))
            .foregroundColor(Color.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(highlighted ? Color.activeFill : .clear)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    private var informationTable: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Information")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(MainWindowPalette.tertiaryText)

            VStack(spacing: 0) {
                ForEach(Array(informationRows.enumerated()), id: \.offset) { index, row in
                    HStack(spacing: 16) {
                        Text(row.label)
                            .foregroundColor(MainWindowPalette.secondaryText)
                        Spacer(minLength: 16)
                        Text(row.value)
                            .foregroundColor(MainWindowPalette.primaryText.opacity(0.72))
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .font(.airClipCaption)
                    .padding(.horizontal, 12)
                    .frame(height: 28)
                    .background(index.isMultiple(of: 2) ? MainWindowPalette.activeFill.opacity(0.5) : .clear)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
    }

    private var informationRows: [(label: String, value: String)] {
        var rows: [(label: String, value: String)] = [
            ("Source", sourceLabel),
            ("Type", typeLabel)
        ]

        switch type {
        case .file:
            if let file = item.fileMetadata {
                rows.append(("Name", file.name))
                rows.append(("Size", ByteCountFormatter.string(fromByteCount: file.size, countStyle: .file)))
                rows.append(("Format", file.mimeType))
                if let durationMs = file.durationMs { rows.append(("Duration", "\(durationMs / 1000)s")) }
                if let width = file.width, let height = file.height { rows.append(("Dimensions", "\(width)×\(height)")) }
                if let artist = file.artist { rows.append(("Artist", artist)) }
                if let album = file.album { rows.append(("Album", album)) }
            }
        case .image:
            if let imageDimensions { rows.append(("Dimensions", imageDimensions)) }
            if let imageData = item.imageData {
                rows.append(("Size", ByteCountFormatter.string(fromByteCount: Int64(imageData.count), countStyle: .file)))
            }
            if !item.text.isEmpty, !item.text.hasPrefix("Image "), item.text != "Image" {
                rows.append(("Name", item.text))
            }
        case .url:
            if let host = URL(string: item.text.trimmingCharacters(in: .whitespacesAndNewlines))?.host {
                rows.append(("Domain", host))
            }
        case .text:
            rows.append(("Characters", item.text.count.formatted()))
        case .color:
            if let colorComponents {
                rows.append(("Title", colorComponents.title))
                rows.append(("Hex", colorComponents.hex))
                rows.append(("RGB", "\(colorComponents.red), \(colorComponents.green), \(colorComponents.blue)"))
                rows.append(("CSS", colorComponents.css))
            }
        case .email:
            break
        }

        rows.append(("Copied", copiedDate))
        return rows
    }

    private var typeLabel: String {
        if type == .file, item.fileMetadata?.isImage == true { return "Image" }
        switch type {
        case .url: return "Link"
        case .color: return "Color"
        case .email: return "Email"
        case .image: return "Image"
        case .file: return "File"
        case .text: return "Text"
        }
    }

    private var imageDimensions: String? {
        guard let data = item.imageData, let representation = NSBitmapImageRep(data: data) else { return nil }
        return "\(representation.pixelsWide)×\(representation.pixelsHigh)"
    }

    private var colorComponents: ColorComponents? {
        ColorComponents(hex: item.text)
    }

    private var copiedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.doesRelativeDateFormatting = true
        return formatter.string(from: item.receivedAt)
    }

    private struct ColorComponents {
        let red: Int
        let green: Int
        let blue: Int
        let alpha: Int
        let hex: String

        init?(hex: String) {
            var digits = hex.trimmingCharacters(in: .whitespacesAndNewlines)
            guard digits.hasPrefix("#") else { return nil }
            digits.removeFirst()
            if digits.count == 3 || digits.count == 4 {
                digits = digits.map { "\($0)\($0)" }.joined()
            }
            guard digits.count == 6 || digits.count == 8,
                  let value = UInt32(digits, radix: 16) else { return nil }

            red = Int((value >> (digits.count == 8 ? 24 : 16)) & 0xFF)
            green = Int((value >> (digits.count == 8 ? 16 : 8)) & 0xFF)
            blue = Int((value >> (digits.count == 8 ? 8 : 0)) & 0xFF)
            alpha = digits.count == 8 ? Int(value & 0xFF) : 255
            self.hex = "#\(digits.uppercased())"
        }

        var css: String {
            let opacity = alpha == 255 ? "1" : String(format: "%.2f", Double(alpha) / 255)
            return "rgba(\(red), \(green), \(blue), \(opacity))"
        }

        var hsl: String {
            let r = Double(red) / 255, g = Double(green) / 255, b = Double(blue) / 255
            let maximum = max(r, g, b), minimum = min(r, g, b), delta = maximum - minimum
            let lightness = (maximum + minimum) / 2
            let saturation = delta == 0 ? 0 : delta / (1 - abs(2 * lightness - 1))
            let hue: Double
            if delta == 0 { hue = 0 }
            else if maximum == r { hue = 60 * ((g - b) / delta).truncatingRemainder(dividingBy: 6) }
            else if maximum == g { hue = 60 * ((b - r) / delta + 2) }
            else { hue = 60 * ((r - g) / delta + 4) }
            return "\(Int(hue < 0 ? hue + 360 : hue).formatted()), \(Int((saturation * 100).rounded()))%, \(Int((lightness * 100).rounded()))%"
        }

        var title: String {
            let r = Double(red) / 255
            let g = Double(green) / 255
            let b = Double(blue) / 255
            let maximum = max(r, g, b)
            let minimum = min(r, g, b)
            let difference = maximum - minimum

            if maximum < 0.12 { return "Black" }
            if difference < 0.12 { return maximum > 0.88 ? "White" : "Gray" }

            let hue: Double
            if maximum == r {
                hue = 60 * ((g - b) / difference).truncatingRemainder(dividingBy: 6)
            } else if maximum == g {
                hue = 60 * ((b - r) / difference + 2)
            } else {
                hue = 60 * ((r - g) / difference + 4)
            }
            let normalizedHue = hue < 0 ? hue + 360 : hue

            switch normalizedHue {
            case 0..<15, 345...: return maximum < 0.6 ? "Maroon" : "Red"
            case 15..<45: return "Orange"
            case 45..<70: return "Yellow"
            case 70..<165: return "Green"
            case 165..<200: return "Teal"
            case 200..<255: return "Blue"
            case 255..<310: return "Purple"
            default: return "Pink"
            }
        }
    }

    private func previewText(
        foregroundColor: Color,
        underline: Bool = false
    ) -> some View {
        Text(item.text)
            .font(previewFont)
            .foregroundColor(foregroundColor)
            .underline(underline, color: foregroundColor)
            .lineSpacing(previewLineSpacing)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var previewImage: NSImage? {
        guard let data = item.imageData else { return nil }
        return NSImage(data: data)
    }

    private var previewFont: Font {
        let size: CGFloat = item.text.count > 260 ? 20 : previewBaseSize
        switch type {
        case .url:
            return .system(size: size.clamped(to: 12...12), weight: .regular)
        case .email:
            return .system(size: size.clamped(to: 18...18), weight: .regular, design: .monospaced)
        case .color:
            return .system(size: size.clamped(to: 20...20), weight: .medium, design: .monospaced)
        case .image:
            return .system(size: size.clamped(to: 18...18), weight: .regular)
        case .file:
            return .system(size: 18, weight: .regular)
        case .text:
            return .system(size: size, weight: .regular)
        }
    }

    private var previewBaseSize: CGFloat {
        switch type {
        case .url:
            return 12
        case .email:
            return 18
        case .color:
            return 20
        case .image:
            return 18
        case .file:
            return 18
        case .text:
            return 24
        }
    }

    private var previewColor: Color {
        switch type {
        case .url:
            return MainWindowPalette.secondaryText
        case .email:
            return Color.syncBlue
        case .color:
            return MainWindowPalette.primaryText
        case .text:
            return MainWindowPalette.primaryText
        case .image, .file:
            return MainWindowPalette.primaryText
        }
    }

    private var previewLineSpacing: CGFloat {
        switch type {
        case .image, .file:
            return 5
        case .text:
            return item.text.count > 480 ? 5 : 7
        default:
            return 5
        }
    }

    private var previewSpacing: CGFloat {
        type == .color || type == .url || (type == .text && linkPreview?.image != nil) ? 12 : 0
    }

    private func openURL() {
        let trimmed = item.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed) ?? URL(string: "https://\(trimmed)") else { return }
        NSWorkspace.shared.open(url)
    }
}

struct LinkPreviewMetadata {
    let title: String
    let site: String
    let image: NSImage?
    let hasExplicitTitle: Bool
}

enum LinkPreviewLoader {
    private static let maxHTMLBytes = 512 * 1024
    private static let maxImageBytes = 10 * 1024 * 1024

    static func preview(for text: String, includeImage: Bool = true) async -> LinkPreviewMetadata? {
        guard let pageURL = normalizedURL(from: text), isRemoteURL(pageURL) else { return nil }

        var request = URLRequest(url: pageURL)
        request.timeoutInterval = 6
        request.setValue("Airclip/1.0 link preview", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode),
                  httpResponse.mimeType?.lowercased() == "text/html" else { return nil }

            let resolvedURL = response.url ?? pageURL
            let metadata = metadata(in: data.prefix(maxHTMLBytes), baseURL: resolvedURL)
            let host = resolvedURL.host.map { $0.hasPrefix("www.") ? String($0.dropFirst(4)) : $0 }
            let title = metadata.title ?? host ?? resolvedURL.absoluteString
            let site = metadata.site ?? host ?? resolvedURL.absoluteString
            let image = includeImage ? await loadImage(from: metadata.imageURL) : nil
            return LinkPreviewMetadata(
                title: title,
                site: site,
                image: image,
                hasExplicitTitle: metadata.title != nil
            )
        } catch {
            return nil
        }
    }

    private static func loadImage(from url: URL?) async -> NSImage? {
        guard let url, isRemoteURL(url) else { return nil }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard data.count <= maxImageBytes,
                  response.mimeType?.lowercased().hasPrefix("image/") == true else { return nil }
            return NSImage(data: data)
        } catch {
            return nil
        }
    }

    private static func normalizedURL(from text: String) -> URL? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return URL(string: trimmed) ?? URL(string: "https://\(trimmed)")
    }

    static func urls(in text: String) -> [URL] {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        return detector.matches(in: text, range: range).compactMap(\.url).filter(isRemoteURL)
    }

    private static func isRemoteURL(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased(),
              url.scheme == "http" || url.scheme == "https",
              host != "localhost",
              !host.hasSuffix(".local") else { return false }
        if host == "::1" || host.hasPrefix("fe80:") || host.hasPrefix("fc") || host.hasPrefix("fd") { return false }
        let octets = host.split(separator: ".").compactMap { UInt8($0) }
        guard octets.count == 4 else { return true }
        return octets[0] != 0
            && octets[0] != 10
            && octets[0] != 127
            && !(octets[0] == 169 && octets[1] == 254)
            && !(octets[0] == 172 && (16...31).contains(octets[1]))
            && !(octets[0] == 192 && octets[1] == 168)
    }

    private static func metadata(in data: Data.SubSequence, baseURL: URL) -> (title: String?, site: String?, imageURL: URL?) {
        let html = String(decoding: data, as: UTF8.self)
        guard let tagRegex = try? NSRegularExpression(pattern: "<meta\\b[^>]*>", options: [.caseInsensitive]) else {
            return (nil, nil, nil)
        }
        let range = NSRange(html.startIndex..., in: html)
        var title: String?
        var site: String?
        var imageURL: URL?

        for match in tagRegex.matches(in: html, range: range) {
            guard let matchRange = Range(match.range, in: html) else { continue }
            let tag = String(html[matchRange])
            let property = attribute(named: "property", in: tag)?.lowercased()
            guard let value = attribute(named: "content", in: tag)?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !value.isEmpty else { continue }
            switch property {
            case "og:title" where title == nil:
                title = value
            case "og:site_name" where site == nil:
                site = value
            case "og:image" where imageURL == nil:
                imageURL = URL(string: value, relativeTo: baseURL)?.absoluteURL
            default:
                break
            }
        }

        if title == nil,
           let titleRegex = try? NSRegularExpression(pattern: "<title[^>]*>(.*?)</title>", options: [.caseInsensitive, .dotMatchesLineSeparators]),
           let match = titleRegex.firstMatch(in: html, range: range),
           let titleRange = Range(match.range(at: 1), in: html) {
            title = String(html[titleRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return (title?.prefix(180).description, site?.prefix(80).description, imageURL)
    }

    private static func attribute(named name: String, in tag: String) -> String? {
        let pattern = "\\b\(name)\\s*=\\s*([\"'])(.*?)\\1"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]),
              let match = regex.firstMatch(in: tag, range: NSRange(tag.startIndex..., in: tag)),
              let range = Range(match.range(at: 2), in: tag) else { return nil }
        return String(tag[range]).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        min(max(self, limits.lowerBound), limits.upperBound)
    }
}

private struct FloatingActions: View {
    let isSaved: Bool
    let isFile: Bool
    let fileIsAvailable: Bool
    let onOpenBrowser: (() -> Void)?
    let onCopy: () -> Void
    let onFileAction: (() -> Void)?
    let fileActionLabel: String?
    let fileActionIcon: AirclipIconName?
    let fileActionIsEnabled: Bool
    let onSave: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            if let onOpenBrowser {
                ActionIconButton(
                    icon: .arrowUpRight,
                    foregroundColor: MainWindowPalette.secondaryText,
                    help: "Open in browser",
                    action: onOpenBrowser
                )
            }
            if let onFileAction, let fileActionLabel, let fileActionIcon {
                ActionIconButton(
                    icon: fileActionIcon,
                    foregroundColor: MainWindowPalette.secondaryText,
                    help: fileActionLabel,
                    isEnabled: fileActionIsEnabled,
                    action: onFileAction
                )
            }
            if !isFile || fileIsAvailable {
                CopyActionIconButton(action: onCopy)
                    .keyboardShortcut("c", modifiers: .command)
            }
            if !isFile {
                ActionIconButton(
                    icon: isSaved ? .bookmarkCheck : .bookmarkAdd,
                    foregroundColor: isSaved ? MainWindowPalette.saved : MainWindowPalette.secondaryText,
                    help: isSaved ? "Saved" : "Save",
                    action: onSave
                )
                .contentTransition(.opacity)
                .animation(.easeOut(duration: 0.12), value: isSaved)
            }
            ActionIconButton(
                icon: .delete,
                foregroundColor: MainWindowPalette.secondaryText,
                hoverForegroundColor: MainWindowPalette.destructive,
                help: "Delete",
                action: onDelete
            )
            .keyboardShortcut(.delete, modifiers: [])
        }
        .padding(6)
        .frame(minWidth: actionBarWidth)
        .frame(height: MainWindowLayout.actionBarHeight)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(MainWindowPalette.card)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(MainWindowPalette.divider, lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 1)
                .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 4)
        )
    }

    private var actionBarWidth: CGFloat {
        let buttonCount = (isFile ? 2 : 3)
            + (onOpenBrowser == nil ? 0 : 1)
        return CGFloat(12 + (40 * buttonCount) + (8 * max(buttonCount - 1, 0)))
    }
}

private struct CopyActionIconButton: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let action: () -> Void

    @State private var didCopy = false
    @State private var isHovered = false
    @State private var isPressed = false
    @State private var feedbackVersion = 0

    var body: some View {
        Button {
            action()
            feedbackVersion += 1
            setCopied(true)
        } label: {
            ZStack {
                AirclipIcon(.copy, size: 16)
                    .foregroundColor(MainWindowPalette.secondaryText)
                    .opacity(didCopy ? 0 : 1)
                    .scaleEffect(didCopy ? 0.96 : 1)

                CopyConfirmationCheckmark()
                    .trim(from: 0, to: didCopy ? 1 : 0)
                    .stroke(
                        MainWindowPalette.saved,
                        style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round)
                    )
                    .frame(width: 16, height: 16)
            }
            .frame(width: 40, height: 32)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(backgroundColor)
            )
            .scaleEffect(isPressed ? MainWindowMotion.actionPressScale : 1)
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(didCopy ? "Copied" : "Copy")
        .accessibilityLabel(didCopy ? "Copied" : "Copy")
        .onHover { hovering in
            withAnimation(.easeOut(duration: MainWindowMotion.hoverDuration)) {
                isHovered = hovering
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard !isPressed else { return }
                    withAnimation(.easeOut(duration: MainWindowMotion.pressDuration)) {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    withAnimation(.easeOut(duration: MainWindowMotion.releaseDuration)) {
                        isPressed = false
                    }
                }
        )
        .task(id: feedbackVersion) {
            guard feedbackVersion > 0 else { return }
            try? await Task.sleep(for: .milliseconds(1_400))
            guard !Task.isCancelled else { return }
            setCopied(false)
        }
    }

    private var backgroundColor: Color {
        if isPressed { return MainWindowPalette.pressedFill }
        if isHovered { return MainWindowPalette.hoverFill }
        return .clear
    }

    private func setCopied(_ copied: Bool) {
        guard reduceMotion else {
            withAnimation(.timingCurve(0.25, 0.46, 0.45, 0.94, duration: copied ? 0.18 : 0.14)) {
                didCopy = copied
            }
            return
        }
        didCopy = copied
    }
}

private struct CopyConfirmationCheckmark: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.22, y: rect.minY + rect.height * 0.53))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.43, y: rect.minY + rect.height * 0.74))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.80, y: rect.minY + rect.height * 0.30))
        return path
    }
}

private struct ActionIconButton: View {
    let icon: AirclipIconName
    var foregroundColor: Color = MainWindowPalette.secondaryText
    var hoverForegroundColor: Color?
    let help: String
    var isEnabled: Bool = true
    let action: () -> Void

    @State private var isHovered = false
    @State private var isPressed = false

    var body: some View {
        Button {
            action()
        } label: {
            AirclipIcon(icon, size: 16)
                .foregroundColor(currentForegroundColor)
                .frame(width: 40, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(backgroundColor)
                )
                .scaleEffect(isPressed ? MainWindowMotion.actionPressScale : 1)
                .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.45)
        .help(help)
        .accessibilityLabel(help)
        .onHover { hovering in
            guard isEnabled else { return }
            withAnimation(.easeOut(duration: MainWindowMotion.hoverDuration)) {
                isHovered = hovering
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed {
                        withAnimation(.easeOut(duration: MainWindowMotion.pressDuration)) {
                            isPressed = true
                        }
                    }
                }
                .onEnded { _ in
                    withAnimation(.easeOut(duration: MainWindowMotion.releaseDuration)) {
                        isPressed = false
                    }
                }
        )
    }

    private var backgroundColor: Color {
        if isPressed { return MainWindowPalette.pressedFill }
        if isHovered { return MainWindowPalette.hoverFill }
        return .clear
    }

    private var currentForegroundColor: Color {
        if isHovered, let hoverForegroundColor {
            return hoverForegroundColor
        }
        return foregroundColor
    }
}

private struct CodeGridIcon: View {
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.fixed(7.5), spacing: 1), count: 2), spacing: 1) {
            ForEach(0..<4, id: \.self) { _ in
                Rectangle()
                    .fill(MainWindowPalette.tertiaryText)
                    .frame(width: 7.5, height: 7.5)
            }
        }
        .frame(width: 16, height: 16)
    }
}

private struct DeviceEmptyActionButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(reduceMotion || !configuration.isPressed ? 1 : 0.98)
            .animation(
                reduceMotion ? nil : .timingCurve(0.25, 0.46, 0.45, 0.94, duration: 0.10),
                value: configuration.isPressed
            )
    }
}

private struct DeviceMenuButtonStyle: ButtonStyle {
    let isHovered: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(configuration.isPressed
                        ? MainWindowPalette.pressedFill
                        : (isHovered ? MainWindowPalette.hoverFill : .clear))
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(
                .timingCurve(0.25, 0.46, 0.45, 0.94, duration: 0.10),
                value: configuration.isPressed
            )
    }
}

private struct DevicesPanel: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var identity = AirclipIdentity.shared
    @ObservedObject private var peerManager = PeerManager.shared
    @ObservedObject private var syncModeStore = SyncModeStore.shared
    @ObservedObject private var lanDiagnostics = LanRuntimeDiagnostics.shared
    @StateObject private var currentWiFiNetwork = CurrentWiFiNetwork.shared

    @State private var hoveredDeviceID: String?
    @State private var hoveredDeviceMenuID: String?
    @State private var pinnedDeviceID: String?
    @State private var deviceToRemove: PairedDevice?
    @State private var isShowingPairingSheet = false
    @State private var refreshRotation: Double = 0
    private var devices: [PairedDevice] {
        identity.pairedDevices.values.sorted { lhs, rhs in
            deviceSortKey(lhs) < deviceSortKey(rhs)
        }
    }

    private var orbitItems: [OrbitDeviceItem] {
        devices.map { device in
            OrbitDeviceItem(
                device: device,
                isOnline: peerManager.connectedDeviceIds.contains(device.deviceId),
                visual: orbitVisual(for: device)
            )
        }
    }

    private var activeTooltipID: String? {
        pinnedDeviceID ?? hoveredDeviceID
    }

    private var remoteOnlineCount: Int {
        orbitItems.filter(\.isOnline).count
    }

    private var hubWiFiStatus: WiFiNetworkNameStatus {
        if case .available = currentWiFiNetwork.status {
            return currentWiFiNetwork.status
        }
        let names = orbitItems
            .filter(\.isOnline)
            .compactMap { $0.device.wifiNetwork }
            .filter { !$0.isEmpty }
        if let first = names.first, names.allSatisfy({ $0 == first }) {
            return .available(first)
        }
        return currentWiFiNetwork.status
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Text("Devices")
                    .font(.airClipTitle1)
                    .foregroundColor(MainWindowPalette.primaryText)

                Spacer()

                DeviceAddButton {
                    isShowingPairingSheet = true
                }
            }
            .frame(height: 30, alignment: .topLeading)

            VStack(spacing: 16) {
                connectionSummary

                ZStack {
                    if devices.isEmpty {
                        VStack(spacing: 0) {
                            AirclipIcon(.deviceSync, size: 68)
                                .foregroundColor(
                                    colorScheme == .dark
                                        ? MainWindowPalette.tertiaryText
                                        : Color(hex: "#D0D3DA")
                                )

                            Text("Your space is ready. Connect a device to start syncing.")
                                .font(.system(size: 16))
                                .foregroundColor(
                                    colorScheme == .dark
                                        ? MainWindowPalette.secondaryText
                                        : Color(hex: "#A0A6B1")
                                )
                                .lineSpacing(4)
                                .multilineTextAlignment(.center)
                                .frame(width: 308)
                                .padding(.top, 20)

                            Button {
                                isShowingPairingSheet = true
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "qrcode")
                                        .font(.system(size: 12, weight: .medium))
                                        .frame(width: 16, height: 16)
                                    Text("Add a device")
                                        .font(.system(size: 14, weight: .medium))
                                }
                                .foregroundColor(MainWindowPalette.card)
                                .padding(.horizontal, 16)
                                .frame(height: 40)
                                .background(Capsule().fill(MainWindowPalette.primaryText))
                                .shadow(color: .black.opacity(0.06), radius: 2, y: 4)
                            }
                            .buttonStyle(DeviceEmptyActionButtonStyle())
                            .padding(.top, 24)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .accessibilityElement(children: .combine)
                        .transition(.asymmetric(
                            insertion: .opacity.animation(reduceMotion
                                ? .easeOut(duration: 0.12)
                                : .timingCurve(0.23, 1, 0.32, 1, duration: 0.18)),
                            removal: .opacity.animation(.easeOut(duration: 0.12))
                        ))
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                ForEach(Array(devices.enumerated()), id: \.element.deviceId) { index, device in
                                    deviceRow(device)
                                        .transition(reduceMotion ? .opacity : .opacity.combined(with: .offset(y: 4)))
                                    if index < devices.count - 1 {
                                        Rectangle()
                                            .fill(MainWindowPalette.divider)
                                            .frame(height: 1)
                                    }
                                }
                            }
                            .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: devices.map(\.deviceId))
                        }
                        .transition(.asymmetric(
                            insertion: .opacity.animation(reduceMotion
                                ? .easeOut(duration: 0.12)
                                : .timingCurve(0.23, 1, 0.32, 1, duration: 0.18)),
                            removal: .opacity.animation(.easeOut(duration: 0.12))
                        ))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(.top, 20)
        }
        .padding(.top, 16)
        .padding(.horizontal, MainWindowLayout.devicesHorizontalInset)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(MainWindowPalette.card)
        .alert(
            "Remove \(deviceToRemove?.deviceName ?? "device")?",
            isPresented: Binding(
                get: { deviceToRemove != nil },
                set: { if !$0 { deviceToRemove = nil } }
            )
        ) {
            Button("Remove", role: .destructive) {
                if let deviceToRemove {
                    identity.removeDevice(deviceToRemove.deviceId)
                    if pinnedDeviceID == deviceToRemove.deviceId { pinnedDeviceID = nil }
                    if hoveredDeviceID == deviceToRemove.deviceId { hoveredDeviceID = nil }
                    AirclipAlertCenter.shared.show("Device removed", kind: .success)
                }
                deviceToRemove = nil
            }
            Button("Cancel", role: .cancel) { deviceToRemove = nil }
        } message: {
            Text("This device will no longer sync with your Airclip space.")
        }
        .sheet(isPresented: $isShowingPairingSheet) {
            AddDevicePairingSheet()
        }
        .onAppear {
            currentWiFiNetwork.requestAccessAndRefresh()
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 30_000_000_000)
                currentWiFiNetwork.refresh()
            }
        }
    }

    private var connectionSummary: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: colorScheme == .dark
                        ? [Color.bgFloating, Color.bgElevated]
                        : [.white, Color(hex: "#F5F5F5")], startPoint: .top, endPoint: .bottom))
                    .overlay(Circle().strokeBorder(colorScheme == .dark ? Color.borderDefault : Color(hex: "#E6E7EB"), lineWidth: 1))
                Image("Devicewifi").renderingMode(.template).resizable()
                    .frame(width: 22, height: 15.5)
                    .foregroundColor(colorScheme == .dark ? Color(hex: "#64D99A") : Color(hex: "#669C6C"))
            }
            .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 4) {
                Text(identity.spaceName.isEmpty ? "My Space" : identity.spaceName)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(colorScheme == .dark ? MainWindowPalette.primaryText : Color(hex: "#232E43"))
                    .lineLimit(1)
                    .contentTransition(.opacity)
                Text(hubWiFiStatus.displayName)
                    .font(.airClipBody)
                    .foregroundColor(colorScheme == .dark ? MainWindowPalette.secondaryText : Color(hex: "#232E43").opacity(0.5))
                    .lineLimit(1)
                    .contentTransition(.opacity)
            }
            Spacer()
            Button {
                SyncEngine.shared.reconnect()
                currentWiFiNetwork.requestAccessAndRefresh()
                guard !reduceMotion else { return }
                withAnimation(.interpolatingSpring(stiffness: 220, damping: 18)) {
                    refreshRotation += 360
                }
            } label: {
                Image("Devicereconnect").renderingMode(.template).resizable()
                    .frame(width: 13.667, height: 15.667)
                    .foregroundColor(MainWindowPalette.primaryText)
                    .rotationEffect(.degrees(refreshRotation))
                    .frame(width: 40, height: 28)
                    .background(Capsule().fill(colorScheme == .dark ? Color.bgFloating : .white))
                    .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
            }
            .buttonStyle(IconButtonStyle())
            .help("Reconnect devices")
            .accessibilityLabel("Reconnect devices")
        }
        .padding(.leading, 16)
        .padding(.trailing, 24)
        .frame(maxWidth: .infinity, minHeight: 80, maxHeight: 80, alignment: .leading)
        .background(alignment: .topLeading) {
            Image("Devicerings").resizable().frame(width: 1032, height: 1032)
                .offset(x: -476, y: -476)
                .opacity(colorScheme == .dark ? 0.15 : 1)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        .background(colorScheme == .dark ? MainWindowPalette.sectionFill : Color(hex: "#F7F7F7"))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: hubWiFiStatus.displayName)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: identity.spaceName)
    }

    private func deviceRow(_ device: PairedDevice) -> some View {
        let isOnline = peerManager.connectedDeviceIds.contains(device.deviceId)
        return HStack(spacing: 16) {
            Image(deviceIcon(for: device) == .laptop ? "Devicelaptop" : "Devicephone")
                .resizable().scaledToFit()
                .frame(width: deviceIcon(for: device) == .laptop ? 25.083 : 18.083, height: 25.083)
                .frame(width: 28, height: 28)
                .opacity(isOnline ? 1 : 0.5)

            VStack(alignment: .leading, spacing: 4) {
                Text(device.deviceName)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(MainWindowPalette.primaryText)
                    .lineLimit(1)
                Text(deviceStatusText(device, isOnline: isOnline))
                    .font(.system(size: 14))
                    .foregroundColor(MainWindowPalette.secondaryText)
                    .lineLimit(1)
                    .contentTransition(.opacity)
            }

            Spacer()

            Menu {
                Button("Reconnect") { SyncEngine.shared.reconnect() }
                Button("Remove device", role: .destructive) { deviceToRemove = device }
            } label: {
                Image("Devicemore").renderingMode(.template).resizable()
                    .frame(width: 2.104, height: 12.083)
                    .foregroundColor(MainWindowPalette.secondaryText)
                    .frame(width: 28, height: 28)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .buttonStyle(DeviceMenuButtonStyle(isHovered: hoveredDeviceMenuID == device.deviceId))
            .onHover { isHovered in
                hoveredDeviceMenuID = isHovered ? device.deviceId : nil
            }
            .accessibilityLabel("Actions for \(device.deviceName)")
        }
        .padding(12)
        .frame(minHeight: 68)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: isOnline)
        .accessibilityElement(children: .contain)
    }

    private func deviceDetail(_ device: PairedDevice) -> String {
        device.platform.isEmpty ? "Device" : device.platform.capitalized
    }

    private func lastSeenText(_ device: PairedDevice) -> String {
        guard device.lastSeenMs > 0 else { return "" }
        let date = Date(timeIntervalSince1970: TimeInterval(device.lastSeenMs) / 1_000)
        return RelativeDateTimeFormatter().localizedString(for: date, relativeTo: Date())
    }

    private func deviceStatusText(_ device: PairedDevice, isOnline: Bool) -> String {
        guard !isOnline else { return "Online" }
        let lastSeen = lastSeenText(device)
        return DeviceConnectionStatusText.offlineDevice(lastSeen: lastSeen.isEmpty ? nil : lastSeen)
    }

    private func deviceIcon(for device: PairedDevice) -> AirclipDeviceIconName {
        let value = "\(device.platform) \(device.deviceModel ?? "") \(device.deviceName)".lowercased()
        if value.contains("mac") || value.contains("laptop") { return .laptop }
        if value.contains("desktop") || value.contains("windows") || value.contains("linux") { return .tv }
        return .smartPhone
    }

    private func orbitPlacements(in size: CGSize) -> [OrbitDevicePlacement] {
        guard !orbitItems.isEmpty else { return [] }

        let items = orbitItems

        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let referenceSlots: [CGPoint] = [
            CGPoint(x: -132, y: -127),
            CGPoint(x: 92, y: -159),
            CGPoint(x: -199, y: -18),
            CGPoint(x: 172, y: 17),
            CGPoint(x: -1, y: -67),
            CGPoint(x: 0, y: 161),
            CGPoint(x: 157, y: 140)
        ]

        return items.enumerated().map { index, item in
            let slot = index < referenceSlots.count
                ? referenceSlots[index]
                : overflowSlot(index: index, size: size)
            let position = CGPoint(
                x: clamp(center.x + slot.x, min: 28, max: size.width - 28),
                y: clamp(center.y + slot.y, min: 28, max: size.height - 28)
            )
            return OrbitDevicePlacement(
                item: item,
                position: position,
                tooltipPlacement: slot.y >= 0 ? .above : .below
            )
        }
    }

    private func orbitFade(edge: VerticalEdge) -> some View {
        LinearGradient(
            colors: [
                MainWindowPalette.card,
                MainWindowPalette.card.opacity(0)
            ],
            startPoint: edge == .top ? .top : .bottom,
            endPoint: edge == .top ? .bottom : .top
        )
        .allowsHitTesting(false)
    }

    private func overflowSlot(index: Int, size: CGSize) -> CGPoint {
        let angle = (Double(index) / 8.0) * 2 * .pi - .pi / 2
        let radius = min(size.width - 104, size.height + 24) / 2
        return CGPoint(x: cos(angle) * radius, y: sin(angle) * radius)
    }

    private func clamp(_ value: CGFloat, min lower: CGFloat, max upper: CGFloat) -> CGFloat {
        Swift.min(Swift.max(value, lower), upper)
    }

    private func deviceSortKey(_ device: PairedDevice) -> String {
        "\(device.deviceName.lowercased())-\(device.deviceId)"
    }

    private func orbitVisual(for device: PairedDevice) -> OrbitDeviceVisual {
        let raw = orbitMatchText(device.deviceModel ?? device.deviceName)
        let platform = orbitMatchText(device.platform)

        if raw.contains("iphone 15 pro") {
            return .iphone15Pro
        }
        if raw.contains("samsung s25 plus") || raw.contains("samsung s25") {
            return .samsungS25Plus
        }
        if raw.contains("oneplus 6") || raw.contains("one plus 6") {
            return .onePlus6
        }
        if raw.contains("mac mini") {
            return .macMini
        }
        if raw.contains("macbook") || raw.contains("mac book") {
            return .macBook
        }

        if platform.contains("windows") || platform.contains("linux") {
            return .genericMonitor
        }
        if platform.contains("mac") {
            return raw.contains("mini") ? .macMini : .macBook
        }
        if platform.contains("android") || platform.contains("phone") || platform.contains("ios") {
            return .genericPhone
        }

        if raw.contains("monitor") || raw.contains("desktop") || raw.contains("pc") {
            return .genericMonitor
        }
        if raw.contains("laptop") {
            return .macBook
        }
        if raw.contains("phone") || raw.contains("mobile") {
            return .genericPhone
        }

        return .genericPhone
    }

    private func orbitMatchText(_ text: String) -> String {
        text.lowercased()
            .replacingOccurrences(of: "+", with: " plus ")
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private func updateHoveredDevice(_ id: String, hovering: Bool) {
        withAnimation(.easeOut(duration: MainWindowMotion.hoverDuration)) {
            if hovering {
                hoveredDeviceID = id
            } else if hoveredDeviceID == id {
                hoveredDeviceID = nil
            }
        }
    }

    private func togglePinned(_ id: String) {
        withAnimation(.easeOut(duration: MainWindowMotion.hoverDuration)) {
            pinnedDeviceID = (pinnedDeviceID == id) ? nil : id
            hoveredDeviceID = id
        }
    }

    private func clearTooltip() {
        withAnimation(.easeOut(duration: MainWindowMotion.hoverDuration)) {
            pinnedDeviceID = nil
            hoveredDeviceID = nil
        }
    }
}

private struct OrbitDeviceItem: Identifiable {
    let device: PairedDevice
    let isOnline: Bool
    let visual: OrbitDeviceVisual

    var id: String { device.deviceId }
}

private struct OrbitDevicePlacement: Identifiable {
    let item: OrbitDeviceItem
    let position: CGPoint
    let tooltipPlacement: OrbitTooltipPlacement

    var id: String { item.device.deviceId }
}

private enum OrbitTooltipPlacement {
    case above
    case below
}

private enum OrbitDeviceVisual {
    case iphone15Pro
    case genericPhone
    case macBook
    case macMini
    case samsungS25Plus
    case onePlus6
    case genericMonitor
}

private struct OrbitBackdrop: View {
    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width - 104, proxy.size.height + 24)
            let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
            let rings: [CGFloat] = [0.16, 0.27, 0.39, 0.50].map { (size * $0) + 20 }

            ZStack {
                ForEach(Array(rings.enumerated()), id: \.offset) { _, radius in
                    Circle()
                        .strokeBorder(MainWindowPalette.divider.opacity(0.88), lineWidth: 1)
                        .frame(width: radius * 2, height: radius * 2)
                        .position(center)
                }
            }
        }
    }
}

private struct NetworkHubView: View {
    let wiFiStatus: WiFiNetworkNameStatus
    let remoteOnlineCount: Int
    let isPaused: Bool
    let diagnostic: LanRuntimeDiagnostic
    let hasDevices: Bool
    let onRefresh: () -> Void

    @State private var isHoveringIcon = false
    @State private var refreshRotation: Double = 0

    var body: some View {
        VStack(spacing: 10) {
            Button(action: refreshWiFiName) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(MainWindowPalette.searchFill)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(MainWindowPalette.divider.opacity(0.72), lineWidth: 0.5)
                        )
                    AirclipIcon(.wifi, size: 28, variant: .stroke)
                        .foregroundColor(Color(hex: "#669C6C"))
                        .opacity(isHoveringIcon ? 0 : 1)
                        .scaleEffect(isHoveringIcon ? 0.92 : 1)
                    AirclipIcon(.refresh, size: 24)
                        .foregroundColor(.accent)
                        .rotationEffect(.degrees(refreshRotation))
                        .opacity(isHoveringIcon ? 1 : 0)
                        .scaleEffect(isHoveringIcon ? 1 : 0.92)
                }
                .frame(width: 60, height: 60)
                .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
            .help("Refresh Wi-Fi name")
            .onHover { hovering in
                withAnimation(.easeOut(duration: 0.14)) {
                    isHoveringIcon = hovering
                }
            }

            VStack(spacing: 4) {
                Text(wiFiStatus.displayName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(MainWindowPalette.primaryText)
                    .lineLimit(1)
                Text(statusText)
                    .font(.system(size: 11))
                    .foregroundColor(MainWindowPalette.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
        }
        .frame(width: 168)
        .opacity(hasDevices ? 1 : 0.92)
    }

    private func refreshWiFiName() {
        onRefresh()
        withAnimation(.interpolatingSpring(stiffness: 220, damping: 18)) {
            refreshRotation += 360
        }
    }

    private var statusText: String {
        if let helperText = wiFiStatus.helperText {
            return helperText
        }
        if !hasDevices {
            return "Waiting for the device to pair."
        }
        if isPaused {
            return "Sync paused · resume to sync"
        }
        switch diagnostic.issue {
        case .serverFailed:
            return "Listener blocked · restart Airclip"
        case .discoveryFailed:
            return "Discovery blocked · check network access"
        case .none:
            break
        }
        return DeviceConnectionStatusText.onlineRemoteDevices(remoteOnlineCount)
    }
}

private struct DeviceAddButton: View {
    let action: () -> Void

    @State private var isHovered = false
    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image("Deviceadd").renderingMode(.template).resizable()
                    .frame(width: 14.334, height: 14.334)
                    .frame(width: 16, height: 16)
                Text("Add Device")
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(MainWindowPalette.primaryText)
            .padding(.horizontal, 8.5)
            .frame(height: 30)
            .background(
                Capsule()
                    .fill(buttonFill)
                    .overlay(
                        Capsule()
                            .strokeBorder(MainWindowPalette.rowStroke, lineWidth: 0.5)
                    )
            )
            .scaleEffect(isPressed ? MainWindowMotion.actionPressScale : 1)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: MainWindowMotion.hoverDuration)) {
                isHovered = hovering
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed {
                        withAnimation(.easeOut(duration: MainWindowMotion.pressDuration)) {
                            isPressed = true
                        }
                    }
                }
                .onEnded { _ in
                    withAnimation(.easeOut(duration: MainWindowMotion.releaseDuration)) {
                        isPressed = false
                    }
                }
        )
    }

    private var buttonFill: Color {
        if isPressed { return MainWindowPalette.pressedFill }
        if isHovered { return MainWindowPalette.hoverFill }
        return MainWindowPalette.searchFill
    }
}

private struct AddDevicePairingSheet: View {
    @ObservedObject private var pairing = PairingSession.shared
    @StateObject private var pairingSheet = AddDevicePairingSheetController()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(MainWindowPalette.searchFill)
                    AirclipIcon(.deviceSync, size: 22)
                        .foregroundColor(MainWindowPalette.secondaryText)
                }
                .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 5) {
                    Text(pairingSheet.didPairDevice ? "Device added" : "Add a device")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(MainWindowPalette.primaryText)
                        .contentTransition(.opacity)
                        .animation(reduceMotion
                            ? .easeOut(duration: 0.12)
                            : .timingCurve(0.23, 1, 0.32, 1, duration: 0.20),
                            value: pairingSheet.didPairDevice)

                    Text(pairingSheet.didPairDevice ? "Anything you copy will now appear on both devices." : "On your other device, open Airclip → Devices → Scan QR code.")
                        .font(.system(size: 12))
                        .foregroundColor(MainWindowPalette.secondaryText)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .contentTransition(.opacity)
                        .animation(reduceMotion
                            ? .easeOut(duration: 0.12)
                            : .timingCurve(0.23, 1, 0.32, 1, duration: 0.20),
                            value: pairingSheet.didPairDevice)
                }

                Spacer()

                Button {
                    dismiss()
                } label: {
                    AirclipIcon(.remove, size: 14)
                        .foregroundColor(MainWindowPalette.secondaryText)
                        .frame(width: 28, height: 28)
                        .background(
                            Circle()
                                .fill(MainWindowPalette.searchFill)
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 24)

            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(Color.black.opacity(0.06), lineWidth: 0.5)
                    )

                if let qrImage = pairing.qrImage {
                    Image(nsImage: qrImage)
                        .resizable()
                        .interpolation(.none)
                        .frame(width: 204, height: 204)
                        .transition(.opacity)
                } else {
                    ProgressView()
                        .scaleEffect(0.8)
                        .transition(.opacity)
                }
            }
            .animation(reduceMotion
                ? .easeOut(duration: 0.12)
                : .timingCurve(0.23, 1, 0.32, 1, duration: 0.18),
                value: pairing.qrImage != nil)
            .frame(width: 224, height: 224)
            .padding(.bottom, 18)

            if let code = pairing.currentCode {
                VStack(spacing: 6) {
                    Text("Numeric code")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(MainWindowPalette.secondaryText)
                        .textCase(.uppercase)

                    Text(formattedCode(code))
                        .font(.system(size: 28, weight: .semibold, design: .monospaced))
                        .foregroundColor(MainWindowPalette.primaryText)
                        .tracking(4)
                }
                .padding(.bottom, 20)
            }

            HStack(spacing: 10) {
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(MainWindowPalette.saved)

                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(28)
        .frame(width: 420)
        .background(MainWindowPalette.card)
        .onAppear {
            pairingSheet.reset()
            PairingSession.shared.onPairSuccess = {
                withAnimation(.easeOut(duration: 0.18)) {
                    pairingSheet.handlePairSuccess()
                }
            }
            LanServer.shared.start()
            LanBrowser.shared.start()
            PairingSession.shared.start()
        }
        .onChange(of: pairingSheet.shouldDismiss) { _, shouldDismiss in
            if shouldDismiss {
                dismiss()
            }
        }
        .onDisappear {
            PairingSession.shared.onPairSuccess = nil
            PairingSession.shared.stop()
            SyncModeStore.shared.applyRuntimePolicy()
        }
    }

    private func formattedCode(_ code: String) -> String {
        guard code.count == 6 else { return code }
        return "\(code.prefix(3)) \(code.suffix(3))"
    }
}

private struct OrbitDeviceNode: View {
    let item: OrbitDeviceItem
    let isVisible: Bool
    let isActive: Bool
    let tooltipPlacement: OrbitTooltipPlacement
    let onTap: () -> Void
    let onHover: (Bool) -> Void
    let onRemove: () -> Void

    @State private var isPressed = false

    private var tooltipVisible: Bool {
        isActive || isVisible
    }

    private var tooltipOffset: CGFloat {
        (MainWindowLayout.deviceOrbitNodeSize / 2)
            + MainWindowLayout.deviceOrbitTooltipGap
            + (MainWindowLayout.deviceOrbitTooltipHeight / 2)
    }

    var body: some View {
        ZStack {
            if tooltipVisible {
                OrbitDeviceTooltip(
                    device: item.device,
                    isOnline: item.isOnline,
                    onRemove: onRemove
                )
                .offset(y: tooltipPlacement == .above ? -tooltipOffset : tooltipOffset)
                .opacity(isActive || isVisible ? 1 : 0)
                .scaleEffect(isActive || isVisible ? 1 : 0.98)
                .animation(.easeOut(duration: MainWindowMotion.hoverDuration), value: isActive || isVisible)
            }

            Button(action: onTap) {
                OrbitDeviceArtwork(
                    visual: item.visual,
                    isOnline: item.isOnline
                )
                .scaleEffect(isPressed ? 0.97 : (isActive ? 1.03 : 1))
            }
            .buttonStyle(.plain)
            .contextMenu {
                Button(role: .destructive) {
                    onRemove()
                } label: {
                    Label("Remove device", systemImage: "trash")
                }
            }
        }
        .frame(
            width: max(MainWindowLayout.deviceOrbitNodeSize + 24, MainWindowLayout.deviceOrbitTooltipMaxWidth),
            height: MainWindowLayout.deviceOrbitNodeSize + MainWindowLayout.deviceOrbitTooltipHeight + 18
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            onHover(hovering)
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed {
                        withAnimation(.easeOut(duration: MainWindowMotion.pressDuration)) {
                            isPressed = true
                        }
                    }
                }
                .onEnded { _ in
                    withAnimation(.easeOut(duration: MainWindowMotion.releaseDuration)) {
                        isPressed = false
                    }
                }
        )
    }
}

private struct OrbitDeviceTooltip: View {
    let device: PairedDevice
    let isOnline: Bool
    let onRemove: () -> Void

    private var statusText: String {
        isOnline ? "Online" : "Offline"
    }

    private var tooltipWidth: CGFloat {
        let font = NSFont.systemFont(ofSize: 10, weight: .medium)
        let textWidth = (device.deviceName as NSString).size(withAttributes: [.font: font]).width
        return min(
            max(MainWindowLayout.deviceOrbitTooltipMinWidth, ceil(textWidth) + 44),
            MainWindowLayout.deviceOrbitTooltipMaxWidth
        )
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: MainWindowLayout.deviceOrbitTooltipTextGap) {
                Text(device.deviceName)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(MainWindowPalette.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .allowsTightening(true)
                    .help(device.deviceName)

                Text(statusText)
                    .font(.system(size: 10))
                    .foregroundColor(MainWindowPalette.secondaryText)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: onRemove) {
                AirclipIcon(.close, size: 16)
                    .foregroundColor(MainWindowPalette.secondaryText)
                    .frame(width: 16, height: 16)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .frame(width: tooltipWidth, height: MainWindowLayout.deviceOrbitTooltipHeight, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(MainWindowPalette.card)
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(MainWindowPalette.tertiaryText.opacity(0.10), lineWidth: 1)
                )
                .shadow(color: MainWindowPalette.divider.opacity(0.70), radius: 4, x: 0, y: 2)
        )
    }
}

private struct OrbitDeviceArtwork: View {
    let visual: OrbitDeviceVisual
    let isOnline: Bool

    var body: some View {
        AirclipDeviceIcon(deviceIcon, size: MainWindowLayout.deviceOrbitNodeSize, tint: tint)
        .frame(width: MainWindowLayout.deviceOrbitNodeSize, height: MainWindowLayout.deviceOrbitNodeSize)
        .opacity(isOnline ? 1 : 0.50)
    }

    private var deviceIcon: AirclipDeviceIconName {
        switch visual {
        case .iphone15Pro, .genericPhone, .samsungS25Plus, .onePlus6:
            return .smartPhone
        case .macBook:
            return .laptop
        case .macMini:
            return .computer
        case .genericMonitor:
            return .tv
        }
    }

    private var tint: Color {
        switch visual {
        case .iphone15Pro:
            return Color(hex: "#31343B")
        case .genericPhone:
            return Color(hex: "#8A909A")
        case .samsungS25Plus:
            return Color(hex: "#8B7AE6")
        case .onePlus6:
            return Color(hex: "#4B5563")
        case .macBook:
            return Color(hex: "#0A7F9A")
        case .macMini:
            return Color(hex: "#3A9B47")
        case .genericMonitor:
            return Color(hex: "#8A8F20")
        }
    }
}

private struct MiniPhoneOrbitArtwork: View {
    let shell: [Color]
    let screen: [Color]
    let accent: Color

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(LinearGradient(colors: shell, startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .strokeBorder(Color.black.opacity(0.14), lineWidth: 0.5)
                )
                .frame(width: 25, height: 56)

            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(LinearGradient(colors: screen, startPoint: .top, endPoint: .bottom))
                .frame(width: 19, height: 46)

            Capsule(style: .continuous)
                .fill(Color.black.opacity(0.72))
                .frame(width: 8, height: 2.5)
                .offset(y: -21)

            Circle()
                .fill(accent.opacity(0.9))
                .frame(width: 2.5, height: 2.5)
                .offset(y: 22)
        }
        .shadow(color: Color.black.opacity(0.14), radius: 4, x: 0, y: 2)
    }
}

private struct MiniLaptopOrbitArtwork: View {
    var body: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: "#1E293B"), Color(hex: "#2563EB")], startPoint: .top, endPoint: .bottom))
                .overlay(
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .strokeBorder(Color(hex: "#111827").opacity(0.35), lineWidth: 0.5)
                )
                .frame(width: 40, height: 26)

            RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                .fill(Color(hex: "#3F4652"))
                .frame(width: 8, height: 8)

            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(Color(hex: "#232E43"))
                .frame(width: 28, height: 4)
        }
        .shadow(color: Color.black.opacity(0.12), radius: 3, x: 0, y: 2)
    }
}

private struct MiniDesktopOrbitArtwork: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(LinearGradient(colors: [Color(hex: "#60646C"), Color(hex: "#1F232A")], startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay(
                Circle()
                    .fill(Color.black.opacity(0.68))
                    .frame(width: 5, height: 5)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5)
            )
            .frame(width: 45, height: 45)
            .shadow(color: Color.black.opacity(0.14), radius: 4, x: 0, y: 2)
    }
}

private struct MiniMonitorOrbitArtwork: View {
    var body: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: "#03111F"), Color(hex: "#1673C8")], startPoint: .top, endPoint: .bottom))
                .overlay(
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .strokeBorder(Color(hex: "#111827").opacity(0.35), lineWidth: 0.5)
                )
                .frame(width: 42, height: 28)

            RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                .fill(Color(hex: "#515A68"))
                .frame(width: 6, height: 8)

            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(Color(hex: "#232E43"))
                .frame(width: 24, height: 4)
        }
        .shadow(color: Color.black.opacity(0.12), radius: 3, x: 0, y: 2)
    }
}

private struct PhoneArtwork: View {
    let shell: LinearGradient
    let screen: LinearGradient
    let accent: Color
    let hasDynamicIsland: Bool
    var cameraCluster: Bool = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(shell)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.14), lineWidth: 0.75)
                )

            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(screen)
                .padding(6)
                .overlay(alignment: .top) {
                    if hasDynamicIsland {
                        Capsule(style: .continuous)
                            .fill(Color.black.opacity(0.82))
                            .frame(width: 32, height: 10)
                            .padding(.top, 8)
                    }
                }
                .overlay(alignment: .topTrailing) {
                    if cameraCluster {
                        VStack(spacing: 2) {
                            Circle().fill(accent).frame(width: 4, height: 4)
                            Circle().fill(Color.white.opacity(0.60)).frame(width: 3, height: 3)
                        }
                        .padding(.top, 12)
                        .padding(.trailing, 10)
                    }
                }

            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.16))
                .frame(width: 10, height: 54)
                .offset(x: 36, y: 0)

            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(accent.opacity(0.85))
                .frame(width: 8, height: 8)
                .offset(y: 44)
        }
        .frame(width: 112, height: 132)
    }
}

private struct LaptopArtwork: View {
    let shell: LinearGradient
    let screen: LinearGradient
    let accent: Color

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(shell)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.14), lineWidth: 0.8)
                    )
                    .frame(width: 106, height: 70)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(screen)
                            .padding(6)
                    )

                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(LinearGradient(colors: [Color(hex: "#C7CCD3"), Color(hex: "#8E97A3")], startPoint: .top, endPoint: .bottom))
                    .frame(width: 114, height: 12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.14), lineWidth: 0.6)
                    )
                    .offset(y: -2)
            }

            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(accent.opacity(0.9))
                .frame(width: 9, height: 3)
                .offset(y: 9)
        }
        .frame(width: 112, height: 132)
    }
}

private struct MiniArtwork: View {
    let shell: LinearGradient
    let accent: Color

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(shell)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.14), lineWidth: 0.8)
                )
                .frame(width: 76, height: 76)
                .overlay(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(LinearGradient(colors: [Color(hex: "#111827"), Color(hex: "#374151")], startPoint: .top, endPoint: .bottom))
                        .padding(8)
                )

            Circle()
                .fill(accent.opacity(0.92))
                .frame(width: 6, height: 6)
                .offset(x: -14, y: 16)
        }
        .frame(width: 112, height: 132)
    }
}

private struct MonitorArtwork: View {
    let shell: LinearGradient
    let screen: LinearGradient
    let accent: Color

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(shell)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.14), lineWidth: 0.8)
                )
                .frame(width: 92, height: 66)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(screen)
                        .padding(6)
                )
                .offset(y: -8)

            Capsule(style: .continuous)
                .fill(accent.opacity(0.95))
                .frame(width: 16, height: 5)
                .offset(y: 26)

            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: "#9CA3AF"), Color(hex: "#6B7280")], startPoint: .top, endPoint: .bottom))
                .frame(width: 34, height: 6)
                .offset(y: 36)
        }
        .frame(width: 112, height: 132)
    }
}

private struct SettingsPanel: View {
    @ObservedObject private var identity = AirclipIdentity.shared
    @ObservedObject private var appearanceStore = AppAppearanceStore.shared
    @ObservedObject private var syncModeStore = SyncModeStore.shared
    @ObservedObject private var pasteShortcutStore = PasteShortcutStore.shared
    @ObservedObject private var popoverShortcutStore = PasteShortcutStore.popover
    @ObservedObject private var analytics = PrivacyAnalytics.shared
    @ObservedObject private var updateController = AppUpdateController.shared
    @ObservedObject private var downloadLocation = DownloadLocationStore.shared

    @State private var historyDepth: Int = HistoryRetentionPolicy.selectedIndex()
    @State private var showResetAlert = false
    @State private var showClearHistoryAlert = false

    private let historyOptions = HistoryRetentionPolicy.labels
    private let historyDays = HistoryRetentionPolicy.days

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Settings")
                    .font(.airClipTitle1)
                    .foregroundColor(MainWindowPalette.primaryText)
                    .padding(.bottom, 24)

                settingsSection("Appearance") {
                    settingsGroup {
                        settingsRow(
                            icon: .sun,
                            iconTint: MainWindowPalette.secondaryText,
                            iconFill: MainWindowPalette.activeFill,
                            title: "Theme"
                        ) {
                            appearanceChooser
                                .frame(width: 220)
                        }
                    }
                }

                settingsSection("Files") {
                    settingsGroup {
                        downloadLocationMenuRow
                    }
                }

                settingsSection("Privacy & Sync") {
                    settingsGroup {
                        locationServicesRow
                        settingsDivider
                        encryptionRow
                        settingsDivider
                        historyMenuRow
                        settingsDivider
                        settingsRow(
                            icon: .deviceSync,
                            iconTint: Color.syncBlue,
                            iconFill: Color.syncBlue.opacity(0.12),
                            title: "Sync"
                        ) {
                            syncModeChooser
                                .frame(width: 172)
                        }
                    }
                }

                settingsSection("Keyboard Shortcuts") {
                    settingsGroup {
                        popoverShortcutRow
                        settingsDivider
                        pasteLatestShortcutRow
                        settingsDivider
                        shortcutRow("Copy item", keys: ["⌘", "C"])
                        settingsDivider
                        shortcutRow("Delete item", keys: ["⌫"])
                    }
                }

                settingsSection("About") {
                    settingsGroup {
                        infoRow(
                            "Version",
                            value: "\(bundleValue("CFBundleShortVersionString")) (\(bundleValue("CFBundleVersion")))"
                        )
                        settingsDivider
                        SettingsActionRow(
                            icon: .refresh,
                            title: "Check for Updates",
                            subtitle: updateController.updateStatus ?? "Checks automatically at most once daily.",
                            tint: MainWindowPalette.primaryText,
                            iconFill: MainWindowPalette.activeFill,
                            hoverFill: MainWindowPalette.hoverFill
                        ) {
                            AppUpdateController.shared.checkForUpdates()
                        }
                        settingsDivider
                        Menu {
                            Button {
                                analytics.isEnabled = true
                                analytics.flushIfDue()
                            } label: {
                                if analytics.isEnabled { Label("Allow", systemImage: "checkmark") }
                                else { Text("Allow") }
                            }
                            Button {
                                analytics.isEnabled = false
                            } label: {
                                if !analytics.isEnabled { Label("Don't allow", systemImage: "checkmark") }
                                else { Text("Don't allow") }
                            }
                        } label: {
                            settingsRow(
                                icon: .shield,
                                iconTint: MainWindowPalette.secondaryText,
                                iconFill: MainWindowPalette.activeFill,
                                title: "Help improve Airclip",
                                subtitle: "Anonymous feature counts help us improve Airclip. Clipboard content is never shared."
                            ) {
                                HStack(spacing: 6) {
                                    Text(analytics.isEnabled ? "Allowed" : "Not allowed")
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 9, weight: .semibold))
                                }
                                .font(.system(size: 11.5, weight: .medium))
                                .foregroundColor(MainWindowPalette.secondaryText)
                                .frame(width: 180, alignment: .trailing)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .buttonStyle(.plain)
                        .accessibilityLabel("Anonymous analytics")
                        .accessibilityValue(analytics.isEnabled ? "Allowed" : "Not allowed")
                        .accessibilityHint("Choose whether to share anonymous feature counts")
                    }
                }

                settingsSection("Data & Space") {
                    settingsGroup {
                        SettingsActionRow(
                            icon: .delete,
                            title: "Clear History",
                            subtitle: "Removes clips and saved items from every device in this space.",
                            tint: MainWindowPalette.destructive,
                            iconFill: MainWindowPalette.destructive.opacity(0.12),
                            hoverFill: MainWindowPalette.hoverFill
                        ) {
                            showClearHistoryAlert = true
                        }
                        settingsDivider
                        SettingsActionRow(
                            icon: .logout,
                            title: "Leave Space",
                            subtitle: "Disconnects this Mac and clears Airclip data.",
                            tint: MainWindowPalette.destructive,
                            iconFill: MainWindowPalette.destructive.opacity(0.12),
                            hoverFill: MainWindowPalette.hoverFill
                        ) {
                            showResetAlert = true
                        }
                    }
                }
            }
            .padding(MainWindowLayout.settingsInset)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.never)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(MainWindowPalette.card)
        .sheet(isPresented: $showResetAlert) {
            SettingsDestructiveConfirmationSheet(
                icon: .logout,
                title: "Leave this space?",
                message: identity.pairedDevices.isEmpty
                    ? "This is the last device. Leaving permanently clears this space and its data."
                    : "This Mac will disconnect and its history, pairing data, settings, and encryption keys will be removed. Other devices stay connected.",
                actionTitle: "Leave Space",
                onCancel: { showResetAlert = false },
                onConfirm: {
                    showResetAlert = false
                    identity.leaveNetwork()
                }
            )
        }
        .sheet(isPresented: $showClearHistoryAlert) {
            SettingsDestructiveConfirmationSheet(
                icon: .delete,
                title: "Clear history?",
                message: "This permanently removes all clipboard history and saved items from every device in this space, including devices that are currently offline.",
                actionTitle: "Clear History",
                onCancel: { showClearHistoryAlert = false },
                onConfirm: {
                    showClearHistoryAlert = false
                    SyncEngine.shared.clearHistory()
                    AirclipAlertCenter.shared.show("History cleared", kind: .success)
                }
            )
        }
    }

    private var settingsHeader: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                MainWindowPalette.saved.opacity(0.92),
                                MainWindowPalette.activeFill.opacity(0.96)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(MainWindowPalette.divider.opacity(0.8), lineWidth: 1)
                    )
                    .frame(width: 58, height: 58)
                AirclipLogoMark()
                    .foregroundColor(MainWindowPalette.primaryText)
                    .scaleEffect(1.55)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text("Settings")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(MainWindowPalette.primaryText)
                    Text("macOS 26")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(MainWindowPalette.saved)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(
                            Capsule(style: .continuous)
                                .fill(MainWindowPalette.saved.opacity(0.12))
                        )
                }
                Text("Tune Airclip for this Mac, keep the UI readable, and keep the behavior predictable.")
                    .font(.system(size: 12))
                    .foregroundColor(MainWindowPalette.secondaryText)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    settingsPill(text: identity.deviceName.isEmpty ? "This Mac" : identity.deviceName)
                    settingsPill(text: identity.deviceId.map { "ID \($0.prefix(8))…" } ?? "Unpaired")
                    settingsPill(text: identity.pairedDevices.count == 1 ? "1 paired device" : "\(identity.pairedDevices.count) paired devices")
                }
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .background(cardBackground(cornerRadius: 16))
    }

    private var settingsMetricRow: some View {
        HStack(spacing: 12) {
            metricCard(
                icon: .deviceSync,
                value: "\(identity.pairedDevices.count)",
                label: "Devices",
                tint: MainWindowPalette.saved
            )
            metricCard(
                icon: .clock,
                value: historyOptions[historyDepth],
                label: "History",
                tint: Color.syncBlue
            )
            metricCard(
                icon: .eye,
                value: appearanceStore.setting.label,
                label: "Theme",
                tint: MainWindowPalette.secondaryText
            )
            metricCard(
                icon: .deviceSync,
                value: syncModeStore.mode.label,
                label: "Sync",
                tint: syncModeStore.mode == .paused ? MainWindowPalette.secondaryText : Color.syncBlue
            )
        }
    }

    private func settingsPill(text: String) -> some View {
        Text(text)
            .font(.system(size: 10.5, weight: .medium))
            .foregroundColor(MainWindowPalette.secondaryText)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule(style: .continuous)
                    .fill(MainWindowPalette.activeFill)
                    .overlay(
                        Capsule(style: .continuous)
                            .strokeBorder(MainWindowPalette.divider.opacity(0.8), lineWidth: 0.5)
                    )
            )
    }

    private func metricCard(icon: AirclipIconName, value: String, label: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                AirclipIcon(icon, size: 13)
                    .foregroundColor(tint)
                Spacer()
            }
            Text(value)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(MainWindowPalette.primaryText)
                .lineLimit(1)
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(MainWindowPalette.secondaryText)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
        .background(cardBackground(cornerRadius: 14))
    }

    private func settingsPanelCard<Content: View>(
        title: String,
        icon: AirclipIconName,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(MainWindowPalette.activeFill)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(MainWindowPalette.divider.opacity(0.8), lineWidth: 0.5)
                        )
                    AirclipIcon(icon, size: 14)
                        .foregroundColor(MainWindowPalette.secondaryText)
                }
                .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(MainWindowPalette.primaryText)
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(MainWindowPalette.secondaryText)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
            }

            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground(cornerRadius: 16))
    }

    private func cardBackground(cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color.bgElevated)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.borderSubtle, lineWidth: 0.5)
            )
    }

    private func settingsSection<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.airClipCaptionMed)
                .foregroundColor(MainWindowPalette.secondaryText)
                .padding(.leading, 8)

            content()
        }
        .padding(.bottom, 24)
    }

    private func settingsGroup<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .background(cardBackground(cornerRadius: 14))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func settingsRow<Accessory: View>(
        icon: AirclipIconName,
        iconTint: Color,
        iconFill: Color,
        title: String,
        subtitle: String? = nil,
        @ViewBuilder accessory: () -> Accessory
    ) -> some View {
        HStack(spacing: 12) {
            settingsIcon(icon, tint: iconTint, fill: iconFill)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(MainWindowPalette.primaryText)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(MainWindowPalette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 12)
            accessory()
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 60)
    }

    private func settingsIcon(_ icon: AirclipIconName, tint: Color, fill: Color) -> some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(fill)
            .frame(width: 34, height: 34)
            .overlay(
                AirclipIcon(icon, size: 16)
                    .foregroundColor(tint)
            )
    }

    private var appearanceChooser: some View {
        HStack(spacing: 4) {
            ForEach(AppAppearanceSetting.allCases, id: \.rawValue) { option in
                Button {
                    appearanceStore.rawValue = option.rawValue
                } label: {
                    Text(option.label)
                        .font(.system(size: 11.5, weight: appearanceStore.rawValue == option.rawValue ? .semibold : .regular))
                        .foregroundColor(appearanceStore.rawValue == option.rawValue ? MainWindowPalette.primaryText : MainWindowPalette.secondaryText)
                        .frame(maxWidth: .infinity)
                        .frame(height: 26)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(appearanceStore.rawValue == option.rawValue ? Color.segmentSelected : .clear)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .strokeBorder(appearanceStore.rawValue == option.rawValue ? MainWindowPalette.divider : .clear, lineWidth: 0.5)
                                )
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.borderDefault, lineWidth: 0.5)
                )
        )
        .animation(.easeOut(duration: 0.12), value: appearanceStore.rawValue)
    }

    private var downloadLocationMenuRow: some View {
        Menu {
            Button {
                downloadLocation.resetToDownloads()
            } label: {
                if downloadLocation.usesDefaultDownloadsFolder {
                    Label("Downloads", systemImage: "checkmark")
                } else {
                    Text("Downloads")
                }
            }
            Divider()
            Button("Choose Folder…") {
                chooseDownloadFolder()
            }
        } label: {
            settingsRow(
                icon: .fileDownload,
                iconTint: MainWindowPalette.secondaryText,
                iconFill: MainWindowPalette.activeFill,
                title: "Download location",
                subtitle: downloadLocation.displayPath
            ) {
                HStack(spacing: 8) {
                    Text(downloadLocation.folderURL.lastPathComponent)
                        .font(.system(size: 13))
                        .foregroundColor(MainWindowPalette.secondaryText)
                        .lineLimit(1)
                    AirclipIcon(.chevronDown, size: 12)
                        .foregroundColor(MainWindowPalette.secondaryText)
                }
                .frame(width: 180, alignment: .trailing)
            }
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .buttonStyle(.plain)
    }

    private func chooseDownloadFolder() {
        let panel = NSOpenPanel()
        panel.title = "Choose Download Folder"
        panel.message = "Airclip will save future downloaded files in this folder."
        panel.prompt = "Choose"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.directoryURL = downloadLocation.folderURL
        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try downloadLocation.setFolder(url)
        } catch {
            AirclipAlertCenter.shared.show("Folder unavailable", kind: .danger)
        }
    }

    private var syncModeChooser: some View {
        HStack(spacing: 4) {
            ForEach(SyncMode.allCases, id: \.rawValue) { mode in
                Button {
                    syncModeStore.setMode(mode)
                } label: {
                    Text(mode.label)
                        .font(.system(size: 11.5, weight: syncModeStore.mode == mode ? .semibold : .regular))
                        .foregroundColor(syncModeStore.mode == mode ? MainWindowPalette.primaryText : MainWindowPalette.secondaryText)
                        .frame(maxWidth: .infinity)
                        .frame(height: 26)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(syncModeStore.mode == mode ? Color.segmentSelected : .clear)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .strokeBorder(syncModeStore.mode == mode ? MainWindowPalette.divider : .clear, lineWidth: 0.5)
                                )
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.borderDefault, lineWidth: 0.5)
                )
        )
        .animation(.easeOut(duration: 0.12), value: syncModeStore.mode)
    }

    private var encryptionRow: some View {
        settingsRow(
            icon: .encryption,
            iconTint: MainWindowPalette.saved,
            iconFill: MainWindowPalette.saved.opacity(0.12),
            title: "End-to-end encrypted",
            subtitle: "Clipboard data is encrypted before leaving this device."
        ) {
            Text("Always on")
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundColor(MainWindowPalette.saved)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule(style: .continuous).fill(MainWindowPalette.saved.opacity(0.08)))
        }
    }

    private var locationServicesRow: some View {
        settingsRow(
            icon: .wifi,
            iconTint: Color(hex: "#669C6C"),
            iconFill: Color(hex: "#669C6C").opacity(0.12),
            title: "Wi-Fi network name",
            subtitle: "Allow Location Services so Airclip can show your current Wi-Fi."
        ) {
            Button("Open Settings") {
                openLocationServicesSettings()
            }
            .buttonStyle(.plain)
            .font(.system(size: 11.5, weight: .semibold))
            .foregroundColor(MainWindowPalette.primaryText)
            .padding(.horizontal, 10)
            .frame(height: 28)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Color.borderDefault, lineWidth: 0.5)
                    )
            )
        }
    }

    // ── Section label ─────────────────────────────────────────────────────────

    private func settingsLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(MainWindowPalette.tertiaryText)
            .padding(.leading, 2)
            .padding(.bottom, 6)
    }

    // ── Card container ────────────────────────────────────────────────────────

    @ViewBuilder
    private func settingsCard<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .background(MainWindowPalette.sectionFill)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(MainWindowPalette.divider, lineWidth: 1)
        )
    }

    @ViewBuilder
    private var historyMenuRow: some View {
        Menu {
            ForEach(historyOptions.indices, id: \.self) { index in
                Button {
                    updateHistoryDepth(index)
                } label: {
                    HStack {
                        Text(historyOptions[index])
                            .frame(width: 104, alignment: .leading)
                        Spacer(minLength: 12)
                        if historyDepth == index {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .semibold))
                        }
                    }
                }
            }
        } label: {
            settingsRow(
                icon: .clock,
                iconTint: MainWindowPalette.secondaryText,
                iconFill: MainWindowPalette.activeFill,
                title: "Keep history for"
            ) {
                HStack(spacing: 8) {
                    Text(historyOptions[historyDepth])
                        .font(.system(size: 13))
                        .foregroundColor(MainWindowPalette.secondaryText)
                    AirclipIcon(.chevronDown, size: 12)
                        .foregroundColor(MainWindowPalette.secondaryText)
                }
                .frame(width: 140, alignment: .trailing)
            }
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .buttonStyle(.plain)
    }

    private func updateHistoryDepth(_ value: Int) {
        historyDepth = value
        HistoryRetentionPolicy.setSelectedIndex(value)
        if historyDays[value] > 0 {
            LocalHistoryStore.shared.pruneToRetention(days: historyDays[value])
        }
    }

    private func bundleValue(_ key: String) -> String {
        Bundle.main.object(forInfoDictionaryKey: key) as? String ?? "—"
    }

    private func openLocationServicesSettings() {
        CurrentWiFiNetwork.shared.requestAccessAndRefresh()
        let urls = [
            "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices",
            "x-apple.systempreferences:com.apple.preference.security"
        ]
        for rawURL in urls {
            guard let url = URL(string: rawURL), NSWorkspace.shared.open(url) else { continue }
            return
        }
    }

    // ── Row helpers ───────────────────────────────────────────────────────────

    private var settingsDivider: some View {
        Rectangle()
            .fill(Color.borderSubtle)
            .frame(height: 0.5)
            .padding(.horizontal, 16)
    }

    private var pasteLatestShortcutRow: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Paste latest item")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(MainWindowPalette.primaryText)
                Text("Click and press a 2–3 key shortcut.")
                    .font(.system(size: 11))
                    .foregroundColor(MainWindowPalette.secondaryText)
            }

            Spacer(minLength: 12)

            PasteShortcutRecorder(store: pasteShortcutStore)
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 60)
    }

    private var popoverShortcutRow: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Toggle menu bar list")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(MainWindowPalette.primaryText)
                Text("Press Control + ~ by default, or record a replacement.")
                    .font(.system(size: 11))
                    .foregroundColor(MainWindowPalette.secondaryText)
            }
            Spacer(minLength: 12)
            PasteShortcutRecorder(store: popoverShortcutStore)
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 60)
    }

    private func shortcutRow(_ label: String, keys: [String]) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(MainWindowPalette.primaryText)
            Spacer()
            HStack(spacing: 3) {
                ForEach(keys, id: \.self) { key in
                    Text(key)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(MainWindowPalette.secondaryText)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(MainWindowPalette.activeFill)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                                        .strokeBorder(MainWindowPalette.divider, lineWidth: 0.5)
                                )
                        )
                }
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 44)
    }

    private func infoRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(MainWindowPalette.primaryText)
            Spacer()
            Text(value)
                .font(.system(size: 13))
                .foregroundColor(MainWindowPalette.secondaryText)
        }
        .padding(.horizontal, 16)
        .frame(height: 44)
    }
}

private struct FileDropConfirmationSheet: View {
    let files: [DroppedFileCandidate]
    let spaceName: String
    let saveAfterSharing: Bool
    let canShare: Bool
    let onCancel: () -> Void
    let onShare: () -> Void

    private var visibleFiles: [DroppedFileCandidate] { Array(files.prefix(5)) }

    private var title: String {
        files.count == 1
            ? "Share this file with Your Space?"
            : "Share \(files.count) files with Your Space?"
    }

    private var message: String {
        let transferCopy = files.count == 1
            ? "The original stays on this Mac. Other devices download it only when needed."
            : "The originals stay on this Mac. Other devices download them only when needed."
        return saveAfterSharing ? "\(transferCopy) \(files.count == 1 ? "It’ll" : "They’ll") also be added to Saved." : transferCopy
    }

    private var shareButtonTitle: String {
        if saveAfterSharing { return files.count == 1 ? "Share & Save" : "Share & Save \(files.count) Files" }
        return files.count == 1 ? "Share File" : "Share \(files.count) Files"
    }

    var body: some View {
        VStack(spacing: 0) {
            Image("ShareModalIcon")
                .renderingMode(.original)
                .resizable()
                .frame(width: 28, height: 28)
                .padding(14)
                .background(Color(hex: "#E8E3F6"), in: Circle())
                .padding(.bottom, 16)

            Text(title)
                .font(.custom("Beary", size: 19))
                .foregroundStyle(Color.textPrimary)
                .padding(.bottom, 6)

            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 8)
                .padding(.bottom, 18)

            VStack(spacing: 0) {
                ForEach(visibleFiles) { file in
                    HStack(spacing: 10) {
                        Image(systemName: "doc")
                            .font(.system(size: 16))
                            .foregroundStyle(Color.accent)
                            .frame(width: 28, height: 32)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(file.name)
                                .font(.system(size: 12, weight: .medium))
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .foregroundStyle(Color.textPrimary)
                            Text("\(file.kindName) · \(ByteCountFormatter.string(fromByteCount: file.size, countStyle: .file))")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.textSecondary)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 6)
                }
                if files.count > visibleFiles.count {
                    Text("and \(files.count - visibleFiles.count) more")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 4)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.bgElevated, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.borderSubtle, lineWidth: 1)
            }
            .padding(.bottom, canShare ? 18 : 10)

            if !canShare {
                Text("Sharing is paused. Resume sync in Settings to share files.")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.destructiveRed)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 12)
            }

            VStack(spacing: 8) {
                SettingsConfirmationButton(
                    title: shareButtonTitle,
                    fill: canShare ? .primaryButtonFill : .textTertiary,
                    hoverFill: canShare ? Color.primaryButtonFill.opacity(0.86) : .textTertiary,
                    foreground: .white,
                    action: onShare
                )
                .disabled(!canShare)
                .keyboardShortcut(.defaultAction)

                SettingsConfirmationButton(
                    title: "Cancel",
                    fill: .activeFill,
                    hoverFill: Color.textPrimary.opacity(0.10),
                    foreground: .textSecondary,
                    action: onCancel
                )
                .keyboardShortcut(.cancelAction)
            }
        }
        .padding(.horizontal, 26)
        .padding(.top, 24)
        .padding(.bottom, 20)
        .frame(width: 410)
        .background(Color.bgFloating)
    }
}

private struct SettingsDestructiveConfirmationSheet: View {
    let icon: AirclipIconName
    let title: String
    let message: String
    let actionTitle: String
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle()
                    .fill(Color.destructiveRed.opacity(0.10))
                    .frame(width: 60, height: 60)
                AirclipIcon(icon, size: 26, variant: .stroke)
                    .foregroundColor(.destructiveRed)
            }
            .padding(.bottom, 20)

            Text(title)
                .font(.custom("Beary", size: 20))
                .foregroundColor(.textPrimary)
                .padding(.bottom, 8)

            Text(message)
                .font(.system(size: 14))
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 8)
                .padding(.bottom, 24)

            VStack(spacing: 8) {
                SettingsConfirmationButton(
                    title: actionTitle,
                    fill: .destructiveRed,
                    hoverFill: Color.destructiveRed.opacity(0.86),
                    foreground: Color.onDestructive,
                    action: onConfirm
                )

                SettingsConfirmationButton(
                    title: "Cancel",
                    fill: .activeFill,
                    hoverFill: Color.textPrimary.opacity(0.10),
                    foreground: .textSecondary,
                    action: onCancel
                )
                .keyboardShortcut(.cancelAction)
            }
        }
        .padding(.horizontal, 28)
        .padding(.top, 28)
        .padding(.bottom, 20)
        .frame(width: 400)
        .background(Color.bgFloating)
    }
}

private struct SettingsConfirmationButton: View {
    let title: String
    let fill: Color
    let hoverFill: Color
    let foreground: Color
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(title, action: action)
            .buttonStyle(SettingsConfirmationButtonStyle(
                fill: isHovered ? hoverFill : fill,
                foreground: foreground
            ))
            .onHover { isHovered = $0 }
    }
}

private struct SettingsConfirmationButtonStyle: ButtonStyle {
    let fill: Color
    let foreground: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.custom("Beary", size: 15))
            .foregroundColor(foreground)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(fill)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
            .animation(.easeOut(duration: 0.12), value: fill)
    }
}

private struct PasteShortcutRecorder: View {
    @ObservedObject var store: PasteShortcutStore
    @State private var isRecording = false

    var body: some View {
        HStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isRecording ? Color.selectionFill : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(
                                isRecording ? Color.accent : MainWindowPalette.divider,
                                lineWidth: isRecording ? 1 : 0.5
                            )
                    )

                if isRecording {
                    Text("Press ⌘ or ⌃ + key")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(MainWindowPalette.primaryText)
                } else if let shortcut = store.shortcut {
                    HStack(spacing: 3) {
                        ForEach(shortcut.displayKeys, id: \.self) { key in
                            Text(key)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(MainWindowPalette.secondaryText)
                        }
                    }
                } else {
                    Text("Set shortcut")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(MainWindowPalette.secondaryText)
                }

                ShortcutCaptureView(isRecording: $isRecording) { keyCode, modifiers, label in
                    store.set(keyCode: keyCode, modifiers: modifiers, keyLabel: label)
                }
            }
            .frame(width: 128, height: 28)
            .animation(.easeOut(duration: 0.12), value: isRecording)

            if store.shortcut != nil {
                Button { store.clear() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(MainWindowPalette.secondaryText)
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
                .help("Clear shortcut")
                .accessibilityLabel("Clear paste shortcut")
                .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.10), value: store.shortcut != nil)
    }
}

private struct ShortcutCaptureView: NSViewRepresentable {
    @Binding var isRecording: Bool
    let onCapture: (UInt16, NSEvent.ModifierFlags, String) -> Bool

    func makeNSView(context: Context) -> CaptureView {
        let view = CaptureView()
        view.onRecordingChange = { isRecording = $0 }
        view.onCapture = onCapture
        return view
    }

    func updateNSView(_ view: CaptureView, context: Context) {
        view.onRecordingChange = { isRecording = $0 }
        view.onCapture = onCapture
        view.isRecording = isRecording
    }

    final class CaptureView: NSView {
        var isRecording = false
        var onRecordingChange: ((Bool) -> Void)?
        var onCapture: ((UInt16, NSEvent.ModifierFlags, String) -> Bool)?

        override var acceptsFirstResponder: Bool { true }

        override func mouseDown(with event: NSEvent) {
            window?.makeFirstResponder(self)
            isRecording = true
            onRecordingChange?(true)
        }

        override func keyDown(with event: NSEvent) {
            guard event.keyCode != 53 else {
                isRecording = false
                onRecordingChange?(false)
                return
            }
            guard let label = Self.label(for: event) else {
                NSSound.beep()
                return
            }
            if onCapture?(event.keyCode, event.modifierFlags, label) == true {
                isRecording = false
                onRecordingChange?(false)
            } else {
                NSSound.beep()
            }
        }

        override func resignFirstResponder() -> Bool {
            isRecording = false
            onRecordingChange?(false)
            return true
        }

        private static func label(for event: NSEvent) -> String? {
            if event.keyCode == kVK_ANSI_Grave { return "~" }
            guard let character = event.charactersIgnoringModifiers, !character.isEmpty else { return nil }
            switch character {
            case " ": return "Space"
            case "\t": return "⇥"
            case "\r": return "↩"
            case "\u{7F}": return "⌫"
            default: return character.uppercased()
            }
        }
    }
}

private struct SettingsActionRow: View {
    let icon: AirclipIconName
    let title: String
    let subtitle: String
    let tint: Color
    let iconFill: Color
    let hoverFill: Color
    let action: () -> Void

    @State private var isHovered = false
    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(iconFill)
                    .frame(width: 34, height: 34)
                    .overlay(
                        AirclipIcon(icon, size: 16)
                            .foregroundColor(tint)
                    )
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13))
                        .foregroundColor(tint)
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(MainWindowPalette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 60)
            .background(
                Rectangle()
                    .fill(isHovered || isPressed ? hoverFill : .clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: MainWindowMotion.hoverDuration)) {
                isHovered = hovering
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed {
                        withAnimation(.easeOut(duration: MainWindowMotion.pressDuration)) {
                            isPressed = true
                        }
                    }
                }
                .onEnded { _ in
                    withAnimation(.easeOut(duration: MainWindowMotion.releaseDuration)) {
                        isPressed = false
                    }
                }
        )
    }
}
