import SwiftUI
import SwiftData
import AppKit

private enum MainPage: String, CaseIterable {
    case home = "Home"
    case devices = "Devices"
    case saved = "Saved"
    case settings = "Settings"

    var icon: AirClipIconName {
        switch self {
        case .home: return .home
        case .devices: return .deviceSync
        case .saved: return .bookmark
        case .settings: return .settings
        }
    }
}

private enum MainWindowLayout {
    static let windowWidth: CGFloat = 860
    static let windowHeight: CGFloat = 608
    static let sidebarLeadingPadding: CGFloat = 12
    static let sidebarTrailingPadding: CGFloat = 0
    static let mainCardLeadingInset: CGFloat = 12
    static let mainCardTrailingInset: CGFloat = 12
    static let mainCardTopInset: CGFloat = 8
    static let mainCardBottomInset: CGFloat = 12
    static let mainCardCornerRadius: CGFloat = 10
    static let contentHeight: CGFloat = windowHeight
    static let contentWidth: CGFloat = windowWidth
    static let sidebarWidth: CGFloat = 140
    static let sidebarInnerWidth: CGFloat = sidebarWidth - sidebarLeadingPadding - sidebarTrailingPadding
    static let mainCardWidth: CGFloat = windowWidth - sidebarWidth
    static let listWidth: CGFloat = 256
    static let listSearchHorizontalInset: CGFloat = 12
    static let listHeaderHorizontalInset: CGFloat = 12
    static let listRowHorizontalInset: CGFloat = 12
    static let listSearchHeight: CGFloat = 60
    static let previewMinWidth: CGFloat = 240
    static let navItemHeight: CGFloat = 32
    static let navCornerRadius: CGFloat = 10
    static let rowWidth: CGFloat = 232
    static let rowHeight: CGFloat = 70
    static let rowIconWidth: CGFloat = 18
    static let actionBarWidth: CGFloat = 154
    static let actionBarHeight: CGFloat = 50
    static let previewTopInset: CGFloat = 32
    static let previewLeadingInset: CGFloat = 32
    static let previewTrailingInset: CGFloat = 40
    static let previewBottomInset: CGFloat = 84
    static let previewActionTrailingInset: CGFloat = 16
    static let previewActionBottomInset: CGFloat = 16
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
    static let textBadgeFill = Color(hex: "#76A57F").opacity(0.12)
    static let textBadgeForeground = Color(hex: "#76A57F")
    static let linkBadgeFill = Color(hex: "#695DF3").opacity(0.12)
    static let linkBadgeForeground = Color(hex: "#695DF3")
    static let codeBadgeFill = Color(hex: "#E5760E").opacity(0.12)
    static let codeBadgeForeground = Color(hex: "#E5760E")
    static let emailBadgeFill = Color(hex: "#70CBFF").opacity(0.12)
    static let emailBadgeForeground = Color(hex: "#70CBFF")
    static let imageBadgeFill = Color(hex: "#DB438A").opacity(0.12)
    static let imageBadgeForeground = Color(hex: "#DB438A")
    static let imagePreviewBadgeFill = Color.white.opacity(0.50)
    static let colorBadgeFill = Color(hex: "#4D4D4D").opacity(0.12)
    static let colorBadgeForeground = Color(hex: "#4D4D4D")
    static let badgeBorder = Color(hex: "#808080").opacity(0.2)
    static let codeTitleText = Color(hex: "#525F7A")
    static let searchBackground = MainWindowPalette.searchIdleFill
    static let searchBorder = MainWindowPalette.searchIdleBorder
    static let sectionHeaderText = MainWindowPalette.sectionHeaderText
    static let listTitleText = MainWindowPalette.listTitleText
    static let listMetaText = MainWindowPalette.listMetaText
}

private enum MainWindowPalette {
    static let shell = Color.bgBase.opacity(0.88)
    static let shellGlassTint = Color.glassTint.opacity(0.06)
    static let card = Color.bgElevated
    static let primaryText = Color.textPrimary
    static let secondaryText = Color.textSecondary
    static let tertiaryText = Color.textTertiary
    static let divider = Color.borderSubtle
    static let activeFill = Color.activeFill
    static let hoverFill = Color.hoverFill
    static let pressedFill = Color.activeFill
    static let searchFill = Color.bgFloating
    static let focusStroke = Color.accent.opacity(0.44)
    static let selectionStroke = Color.accent.opacity(0.30)
    static let rowStroke = Color.borderDefault
    static let saved = Color.encryptedGreen
    static let destructive = Color.destructiveRed
    static let sectionFill = Color.bgFloating
    static let dangerHoverFill = Color.destructiveRed.opacity(0.10)
    static let online = Color.encryptedGreen
    static let offline = Color.textTertiary
    static let sidebarText = Color.textSubtle
    static let sidebarHoverFill = Color.hoverFill
    static let sidebarActiveFill = Color.selectionFill
    static let sidebarActiveBorder = Color.accent.opacity(0.30)
    static let sidebarItemBorder = Color.borderSubtle
    static let searchIdleFill = Color.bgFloating.opacity(0.40)
    static let searchIdleBorder = Color.borderDefault
    static let sectionHeaderText = Color.textSecondary
    static let listTitleText = Color.textPrimary
    static let listMetaText = Color.textSecondary
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

struct MainWindowView: View {
    @Query private var allItems: [ClipboardItem]
    @State private var activePage: MainPage = .home
    @State private var isNavigationCollapsed = false

    private var savedCount: Int {
        allItems.filter(\.isSaved).count
    }

    private var currentSidebarWidth: CGFloat {
        isNavigationCollapsed ? 0 : MainWindowLayout.sidebarWidth
    }

    private var currentDetailAreaWidth: CGFloat {
        MainWindowLayout.contentWidth - currentSidebarWidth
    }

    private var currentMainCardWidth: CGFloat {
        currentDetailAreaWidth - MainWindowLayout.mainCardLeadingInset - MainWindowLayout.mainCardTrailingInset
    }

    private var currentMainCardHeight: CGFloat {
        MainWindowLayout.contentHeight - MainWindowLayout.mainCardTopInset - MainWindowLayout.mainCardBottomInset
    }

    private var navigationCollapsedBinding: Binding<Bool> {
        Binding(
            get: { isNavigationCollapsed },
            set: { collapsed in
                withAnimation(.timingCurve(0.25, 0.46, 0.45, 0.94, duration: MainWindowMotion.sidebarDuration)) {
                    isNavigationCollapsed = collapsed
                }
            }
        )
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebarColumn
                .frame(width: currentSidebarWidth)
                .opacity(isNavigationCollapsed ? 0 : 1)
                .clipped()
                .allowsHitTesting(!isNavigationCollapsed)

            detailContent
        }
        .frame(width: MainWindowLayout.contentWidth, height: MainWindowLayout.contentHeight, alignment: .topLeading)
        .frame(width: MainWindowLayout.windowWidth, height: MainWindowLayout.windowHeight, alignment: .topLeading)
        .background(MainWindowPalette.shell)
        .animation(
            .timingCurve(0.25, 0.46, 0.45, 0.94, duration: MainWindowMotion.sidebarDuration),
            value: isNavigationCollapsed
        )
        .onReceive(NotificationCenter.default.publisher(for: .openSettingsTab)) { _ in
            withAnimation(.timingCurve(0.25, 0.46, 0.45, 0.94, duration: MainWindowMotion.sidebarDuration)) {
                activePage = .settings
                isNavigationCollapsed = false
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openHomeTab)) { _ in
            withAnimation(.timingCurve(0.25, 0.46, 0.45, 0.94, duration: MainWindowMotion.sidebarDuration)) {
                activePage = .home
                isNavigationCollapsed = false
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openDevicesTab)) { _ in
            withAnimation(.timingCurve(0.25, 0.46, 0.45, 0.94, duration: MainWindowMotion.sidebarDuration)) {
                activePage = .devices
                isNavigationCollapsed = false
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleMainWindowSidebar)) { _ in
            withAnimation(.timingCurve(0.25, 0.46, 0.45, 0.94, duration: MainWindowMotion.sidebarDuration)) {
                isNavigationCollapsed.toggle()
            }
        }
    }

    private var sidebarColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(spacing: 6) {
                ForEach(MainPage.allCases, id: \.self) { page in
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

            Spacer()

            SidebarBrandMark()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 10)
                .padding(.bottom, 24)
        }
        .frame(width: MainWindowLayout.sidebarInnerWidth, height: MainWindowLayout.contentHeight)
        .padding(.leading, MainWindowLayout.sidebarLeadingPadding)
        .padding(.trailing, MainWindowLayout.sidebarTrailingPadding)
        .frame(width: MainWindowLayout.sidebarWidth, height: MainWindowLayout.contentHeight)
        .background(MainWindowPalette.shell)
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
                        isNavigationCollapsed: navigationCollapsedBinding
                    )
                case .saved:
                    ClipboardWorkspace(
                        filter: .saved,
                        workspaceWidth: currentMainCardWidth,
                        workspaceHeight: currentMainCardHeight,
                        isNavigationCollapsed: navigationCollapsedBinding
                    )
                case .devices:
                    DevicesPanel()
                case .settings:
                    SettingsPanel()
                }
            }
            .frame(width: currentMainCardWidth, height: currentMainCardHeight)
            .background(MainWindowPalette.card)
            .clipShape(RoundedRectangle(cornerRadius: MainWindowLayout.mainCardCornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: MainWindowLayout.mainCardCornerRadius, style: .continuous)
                    .strokeBorder(MainWindowPalette.divider.opacity(0.72), lineWidth: 0.5)
            }
            .shadow(color: Color.black.opacity(0.10), radius: 24, x: 0, y: 8)
            .padding(.leading, MainWindowLayout.mainCardLeadingInset)
            .padding(.top, MainWindowLayout.mainCardTopInset)
        }
        .frame(width: currentDetailAreaWidth, height: MainWindowLayout.contentHeight, alignment: .topLeading)
        .animation(
            .timingCurve(0.25, 0.46, 0.45, 0.94, duration: MainWindowMotion.sidebarDuration),
            value: isNavigationCollapsed
        )
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
        .help(page.rawValue)
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
        HStack(spacing: 8) {
            AirClipIcon(page.icon, size: 18, variant: .stroke)
                .foregroundColor(navForegroundColor)
                .frame(width: 18, height: 18)
            Text(page.rawValue)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(navForegroundColor)
            Spacer(minLength: 0)
            countBadge
        }
        .padding(.horizontal, 8)
        .frame(width: MainWindowLayout.sidebarInnerWidth, height: MainWindowLayout.navItemHeight)
        .background(navBackground)
        .scaleEffect(isPressed ? MainWindowMotion.navPressScale : 1)
        .contentShape(RoundedRectangle(cornerRadius: MainWindowLayout.navCornerRadius, style: .continuous))
    }

    private var navBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: MainWindowLayout.navCornerRadius, style: .continuous)
                .fill(backgroundColor)
            if isActive {
                RoundedRectangle(cornerRadius: MainWindowLayout.navCornerRadius, style: .continuous)
                    .strokeBorder(MainWindowPalette.sidebarActiveBorder, lineWidth: 0.8)
            }
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
        if isPressed { return MainWindowPalette.pressedFill }
        if isActive { return MainWindowPalette.sidebarActiveFill }
        if isHovered { return MainWindowPalette.sidebarHoverFill }
        return .clear
    }

    private var navForegroundColor: Color {
        if isActive || isHovered { return MainWindowPalette.primaryText }
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

private struct SidebarBrandMark: View {
    var body: some View {
        AirClipLogoMark()
            .frame(width: 97, height: 24)
        .accessibilityLabel("AirClip")
    }
}

struct AirClipLogoMark: View {
    var body: some View {
        Image(nsImage: MacSplashSVG.image(from: MacSplashSVG.logoSidebar))
            .resizable()
            .scaledToFit()
        .frame(width: 97, height: 24, alignment: .leading)
    }
}

struct AirClipEmptyLogoMark: View {
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

struct AirClipFigmaEmptyState: View {
    var body: some View {
        VStack(spacing: 12) {
            AirClipEmptyLogoMark(size: 36, color: Color(hex: "#D9DBE0"))

            Text("Airclip is ready. Copy on one device, to use it on another.")
                .font(.system(size: 14, weight: .regular))
                .lineSpacing(7)
                .foregroundColor(Color(hex: "#A0A6B1"))
                .multilineTextAlignment(.center)
                .frame(width: 200)
        }
        .frame(width: 200, height: 90)
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
    case colors

    var title: String {
        switch self {
        case .all: return "All"
        case .text: return "Text"
        case .links: return "Links"
        case .images: return "Images"
        case .colors: return "Color"
        }
    }

    var clipType: ClipType? {
        switch self {
        case .all: return nil
        case .text: return .text
        case .links: return .url
        case .images: return .image
        case .colors: return .color
        }
    }
}

private struct ClipboardWorkspace: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.undoManager) private var undoManager
    @Query(sort: \ClipboardItem.receivedAt, order: .reverse) private var allItems: [ClipboardItem]
    @ObservedObject private var revealStore = SensitiveContentRevealStore.shared
    @ObservedObject private var syncModeStore = SyncModeStore.shared

    let filter: ClipFilter
    let workspaceWidth: CGFloat
    let workspaceHeight: CGFloat
    @Binding var isNavigationCollapsed: Bool
    @State private var selectedItem: ClipboardItem?
    @State private var searchQuery = ""
    @State private var selectedTypeFilter: ClipTypeFilter = .all
    @State private var hoveredItemID: UUID?
    @FocusState private var searchFocused: Bool

    private var filteredItems: [ClipboardItem] {
        var items = allItems
        if filter == .saved {
            items = items.filter(\.isSaved)
        }
        if let clipType = selectedTypeFilter.clipType {
            items = items.filter { $0.clipType == clipType }
        }
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return items }
        return items.filter { item in
            item.text.localizedCaseInsensitiveContains(query) ||
                item.kindRaw.localizedCaseInsensitiveContains(query) ||
                clipTypeLabel(for: item.clipType).localizedCaseInsensitiveContains(query) ||
                deviceLabel(for: item).localizedCaseInsensitiveContains(query)
        }
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
        .onAppear { ensureSelection() }
        .onChange(of: allItems) { _, _ in ensureSelection() }
        .onChange(of: filter) { _, _ in ensureSelection() }
        .onChange(of: searchQuery) { _, _ in ensureSelection() }
        .onChange(of: selectedTypeFilter) { _, _ in ensureSelection() }
    }

    private var listPane: some View {
        VStack(alignment: .leading, spacing: 0) {
            searchBar
            typeFilterRow
            if syncModeStore.mode == .manualOnly {
                manualSendRow
            }
            sectionHeader
            if filteredItems.isEmpty {
                emptyListState
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(filteredItems) { item in
                            clipRow(item)
                        }
                    }
                    .padding(.horizontal, MainWindowLayout.listRowHorizontalInset)
                    .padding(.bottom, 8)
                }
                .scrollIndicators(.never)
            }
        }
        .frame(width: MainWindowLayout.listWidth, height: workspaceHeight)
        .background(MainWindowPalette.card)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(MainWindowPalette.divider)
                .frame(width: 1)
        }
    }

    private var manualSendRow: some View {
        Button {
            ManualClipboardSender.sendCurrentClipboard()
        } label: {
            Label("Send Clipboard", systemImage: "paperplane.fill")
                .font(.system(size: 11, weight: .medium))
                .frame(maxWidth: .infinity)
                .frame(height: 28)
        }
        .buttonStyle(.borderedProminent)
        .tint(.accent)
        .padding(.horizontal, MainWindowLayout.listSearchHorizontalInset)
        .padding(.bottom, 8)
    }

    private var searchBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                AirClipIcon(.search, size: 16)
                    .foregroundColor(MainWindowPalette.tertiaryText)
                TextField(
                    "",
                    text: $searchQuery,
                    prompt: Text("Search words or type")
                        .foregroundColor(MainWindowPalette.tertiaryText)
                )
                    .font(.system(size: 13))
                    .foregroundColor(MainWindowPalette.primaryText)
                    .textFieldStyle(.plain)
                    .focused($searchFocused)
                searchTrailingControl
            }
            .padding(.horizontal, 13)
            .frame(maxWidth: .infinity, minHeight: 34, idealHeight: 34, maxHeight: 34)
            .background(searchBackground)
            .overlay(searchBorder)
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .onTapGesture {
                searchFocused = true
            }
        }
        .padding(.horizontal, MainWindowLayout.listSearchHorizontalInset)
        .padding(.vertical, 13)
        .frame(width: MainWindowLayout.listWidth, height: MainWindowLayout.listSearchHeight, alignment: .topLeading)
    }

    private var searchBackground: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(searchFocused ? MainWindowPalette.card : MainWindowLayout.searchBackground)
    }

    private var searchBorder: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .strokeBorder(searchFocused ? MainWindowPalette.focusStroke : MainWindowLayout.searchBorder, lineWidth: 1)
    }

    @ViewBuilder
    private var searchTrailingControl: some View {
        if !searchQuery.isEmpty {
            Button {
                searchQuery = ""
                searchFocused = true
            } label: {
                AirClipIcon(.close, size: 10)
                    .foregroundColor(MainWindowPalette.tertiaryText)
                    .frame(width: 16, height: 16)
                    .background(
                        Circle()
                            .fill(MainWindowPalette.activeFill)
                    )
            }
            .buttonStyle(.plain)
            .help("Clear search")
            .accessibilityLabel("Clear search")
        }
    }

    private var typeFilterRow: some View {
        HStack(spacing: 4) {
            ForEach(ClipTypeFilter.allCases, id: \.self) { typeFilter in
                typeFilterButton(typeFilter)
            }
        }
        .padding(.horizontal, MainWindowLayout.listSearchHorizontalInset)
        .padding(.bottom, 8)
    }

    private func typeFilterButton(_ typeFilter: ClipTypeFilter) -> some View {
        let selected = selectedTypeFilter == typeFilter
        return Button {
            selectedTypeFilter = typeFilter
        } label: {
            Text(typeFilter.title)
                .font(.system(size: 10, weight: selected ? .medium : .regular))
                .foregroundColor(selected ? MainWindowPalette.primaryText : MainWindowPalette.tertiaryText)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .frame(height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(selected ? MainWindowPalette.activeFill : MainWindowPalette.searchFill.opacity(0.55))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(selected ? MainWindowPalette.divider : MainWindowPalette.divider.opacity(0.5), lineWidth: 0.5)
                )
        }
        .buttonStyle(.plain)
        .help("Show \(typeFilter.title.lowercased()) clips")
        .accessibilityLabel("Show \(typeFilter.title.lowercased()) clips")
        .accessibilityValue(selected ? "Selected" : "")
    }

    @ViewBuilder
    private var sectionHeader: some View {
        if let firstItem = filteredItems.first {
            Text(sectionTitle(for: firstItem.receivedAt))
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(MainWindowLayout.sectionHeaderText)
                .padding(.horizontal, MainWindowLayout.listHeaderHorizontalInset)
                .padding(.top, 8)
                .padding(.bottom, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func clipRow(_ item: ClipboardItem) -> some View {
        let active = selectedItem?.id == item.id
        let hovered = hoveredItemID == item.id
        return Button {
            selectedItem = item
        } label: {
            HStack(alignment: .top, spacing: 8) {
                clipTypeBadge(for: item)
                VStack(alignment: .leading, spacing: 8) {
                    Text(item.text)
                        .font(titleFont(for: item))
                        .foregroundColor(titleColor(for: item))
                        .underline(item.clipType == .url)
                        .lineLimit(2)
                        .truncationMode(.tail)
                        .blur(radius: shouldRedact(item) ? 4 : 0)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    HStack(spacing: 0) {
                        HStack(spacing: 4) {
                            Text(deviceLabel(for: item))
                                .lineLimit(1)
                                .truncationMode(.tail)
                            if item.isSaved {
                                AirClipIcon(.bookmarkCheck, size: 9)
                            }
                        }
                        Spacer(minLength: 4)
                        Text(relativeTime(item.receivedAt))
                    }
                    .font(.system(size: 12))
                    .foregroundColor(MainWindowLayout.listMetaText)
                }
            }
            .padding(8)
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
            Button {
                copy(item)
            } label: {
                Label {
                    Text("Copy")
                } icon: {
                    AirClipIcon(.copy, size: 13)
                }
            }
            Button {
                toggleSaved(item)
            } label: {
                Label {
                    Text(item.isSaved ? "Saved" : "Save")
                } icon: {
                    AirClipIcon(item.isSaved ? .bookmarkCheck : .bookmarkAdd, size: 13)
                }
            }
            Divider()
            Button(role: .destructive) {
                delete(item)
            } label: {
                Label {
                    Text("Delete")
                } icon: {
                    AirClipIcon(.delete, size: 13)
                }
            }
        }
    }

    private func rowBackground(active: Bool, hovered: Bool) -> Color {
        if active { return MainWindowPalette.activeFill }
        if hovered { return MainWindowPalette.hoverFill }
        return .clear
    }

    private func rowStroke(active: Bool, hovered: Bool) -> Color {
        if active { return MainWindowPalette.selectionStroke }
        if hovered { return MainWindowPalette.rowStroke }
        return .clear
    }

    private func rowStrokeWidth(active: Bool, hovered: Bool) -> CGFloat {
        (active || hovered) ? 0.5 : 0
    }

    private var emptyListState: some View {
        Group {
            if usesDefaultEmptyState {
                AirClipFigmaEmptyState()
            } else {
                VStack(spacing: 10) {
                    emptyListIcon
                    Text(emptyListTitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(MainWindowPalette.secondaryText)
                        .multilineTextAlignment(.center)
                    Text(emptyListSubtitle)
                        .font(.system(size: 11))
                        .foregroundColor(MainWindowPalette.tertiaryText)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
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

    @ViewBuilder
    private var emptyListIcon: some View {
        if usesDefaultEmptyState {
            AirClipEmptyLogoMark(size: 34, color: MainWindowPalette.tertiaryText.opacity(0.72))
        } else {
            AirClipIcon(filter == .saved ? .bookmark : .clipboard, size: 18)
                .foregroundColor(MainWindowPalette.tertiaryText)
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(MainWindowPalette.searchFill)
                )
        }
    }

    private var emptyListTitle: String {
        if !searchQuery.isEmpty { return "No matches" }
        if selectedTypeFilter != .all { return "No \(selectedTypeFilter.title.lowercased()) clips" }
        return filter == .saved ? "No saved clips" : "Airclip is ready."
    }

    private var emptyListSubtitle: String {
        if !searchQuery.isEmpty { return "Try a different search." }
        if selectedTypeFilter != .all { return "Try another type filter." }
        return filter == .saved ? "Saved clips appear here." : "Copy on one device, paste from another."
    }

    @ViewBuilder
    private func clipTypeBadge(for item: ClipboardItem) -> some View {
        let type = item.clipType
        switch type {
        case .text:
            clipBadge(background: MainWindowLayout.textBadgeFill) {
                AirClipIcon(.text, size: MainWindowLayout.rowIconWidth)
                    .foregroundColor(MainWindowLayout.textBadgeForeground)
            }
        case .url:
            clipBadge(background: MainWindowLayout.linkBadgeFill) {
                AirClipIcon(.arrowUpRight, size: MainWindowLayout.rowIconWidth)
                    .foregroundColor(MainWindowLayout.linkBadgeForeground)
            }
        case .code:
            clipBadge(background: MainWindowLayout.codeBadgeFill) {
                AirClipIcon(.code, size: MainWindowLayout.rowIconWidth)
                    .foregroundColor(MainWindowLayout.codeBadgeForeground)
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
                    AirClipIcon(.image, size: MainWindowLayout.rowIconWidth)
                        .foregroundColor(MainWindowLayout.imageBadgeForeground)
                }
            }
        case .email:
            clipBadge(background: MainWindowLayout.emailBadgeFill) {
                AirClipIcon(.mail, size: MainWindowLayout.rowIconWidth)
                    .foregroundColor(MainWindowLayout.emailBadgeForeground)
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
        @ViewBuilder content: () -> Content
    ) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(background)
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(MainWindowLayout.badgeBorder, lineWidth: 0.5)
            content()
        }
        .frame(width: 28, height: 28)
    }

    private func titleFont(for item: ClipboardItem) -> Font {
        switch item.clipType {
        case .code:
            return .system(size: 12, weight: .medium, design: .monospaced)
        case .url:
            return .system(size: 12, weight: .medium)
        case .image:
            return .system(size: 12, weight: .medium)
        case .email:
            return .system(size: 12, weight: .medium, design: .monospaced)
        case .color:
            return .system(size: 12, weight: .medium, design: .monospaced)
        case .text:
            return .system(size: 12, weight: .medium)
        }
    }

    private func titleColor(for item: ClipboardItem) -> Color {
        switch item.clipType {
        case .url:
            return MainWindowLayout.linkBadgeForeground
        case .code:
            return MainWindowLayout.codeTitleText
        case .email:
            return MainWindowLayout.listTitleText
        case .color:
            return MainWindowLayout.listTitleText
        case .image:
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
                        isSensitive: isSensitive(selectedItem),
                        isRevealed: revealStore.isRevealed(selectedItem.id)
                    )
                        .padding(.top, MainWindowLayout.previewTopInset)
                        .padding(.leading, MainWindowLayout.previewLeadingInset)
                        .padding(.trailing, MainWindowLayout.previewTrailingInset)
                        .padding(.bottom, MainWindowLayout.previewBottomInset)
                }
                .scrollIndicators(.never)
                .background(previewBackground(for: selectedItem))
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
                    onOpenBrowser: selectedItem.clipType == .url ? { openInBrowser(selectedItem) } : nil,
                    sensitiveRevealState: isSensitive(selectedItem)
                        ? revealStore.isRevealed(selectedItem.id)
                        : nil,
                    onToggleSensitiveReveal: isSensitive(selectedItem)
                        ? { revealStore.toggle(selectedItem.id) }
                        : nil,
                    onCopy: { copy(selectedItem) },
                    onSave: { toggleSaved(selectedItem) },
                    onDelete: { delete(selectedItem) }
                )
                .padding(.trailing, MainWindowLayout.previewActionTrailingInset)
                .padding(.bottom, MainWindowLayout.previewActionBottomInset)
                .zIndex(1)
            } else {
                emptyPreviewState
            }
        }
        .frame(width: previewWidth, height: workspaceHeight)
        .background(MainWindowPalette.card)
    }

    private var previewWidth: CGFloat {
        max(workspaceWidth - MainWindowLayout.listWidth, MainWindowLayout.previewMinWidth)
    }

    private func previewBackground(for item: ClipboardItem) -> Color {
        if item.clipType == .color, let color = parsedColor(for: item) {
            return color.opacity(0.2)
        }
        return MainWindowPalette.card
    }

    private var emptyPreviewState: some View {
        AirClipFigmaEmptyState()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func ensureSelection() {
        if !selectedItemIsValid {
            selectedItem = filteredItems.first
        }
    }

    private func copy(_ item: ClipboardItem) {
        ClipboardMonitor.shared.suppressPacket(item.clipboardPacket)
        ClipboardCapture.write(item.clipboardPacket, to: NSPasteboard.general)
    }

    private func openInBrowser(_ item: ClipboardItem) {
        let trimmed = item.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed) ?? URL(string: "https://\(trimmed)") else { return }
        NSWorkspace.shared.open(url)
    }

    private func toggleSaved(_ item: ClipboardItem) {
        item.isSaved.toggle()
        try? modelContext.save()
        if filter == .saved && !item.isSaved {
            selectedItem = filteredItems.first { $0.id != item.id }
        }
    }

    private func delete(_ item: ClipboardItem) {
        let snapshot = ClipboardItemSnapshot(item)
        if selectedItem?.id == item.id {
            selectedItem = filteredItems.first { $0.id != item.id }
        }
        revealStore.setRevealed(false, for: item.id)
        modelContext.delete(item)
        try? modelContext.save()
        undoManager?.registerUndo(withTarget: LocalHistoryStore.shared) { store in
            store.restore(snapshot)
        }
        undoManager?.setActionName("Delete Clipboard Item")
    }

    private func isSensitive(_ item: ClipboardItem) -> Bool {
        item.clipType != .image && SensitiveClipboardClassifier.classify(item.text).isSensitive
    }

    private func shouldRedact(_ item: ClipboardItem) -> Bool {
        isSensitive(item) && !revealStore.isRevealed(item.id)
    }

    private func deviceLabel(for item: ClipboardItem) -> String {
        if item.isLocal {
            let name = AirClipIdentity.shared.deviceName
            return name.isEmpty ? "This Mac" : name
        }
        return AirClipIdentity.shared.pairedDevices[item.fromDeviceId]?.deviceName ?? "Unknown device"
    }

    private func clipTypeLabel(for type: ClipType) -> String {
        switch type {
        case .url: return "Link"
        case .code: return "Code"
        case .color: return "Color"
        case .email: return "Email"
        case .image: return "Image"
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

    private func sectionTitle(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }

        let startOfToday = calendar.startOfDay(for: Date())
        let startOfDate = calendar.startOfDay(for: date)
        let daysAgo = calendar.dateComponents([.day], from: startOfDate, to: startOfToday).day ?? 0
        if daysAgo > 1 && daysAgo < 7 {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE"
            return formatter.string(from: date)
        }
        if daysAgo >= 7 && daysAgo < 14 { return "Last week" }

        let formatter = DateFormatter()
        formatter.dateFormat = calendar.isDate(date, equalTo: Date(), toGranularity: .year) ? "MMM d" : "MMM d, yyyy"
        return formatter.string(from: date)
    }
}

private struct ColorCircleTypeIcon: View {
    let color: Color

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 16, height: 16)
    }
}

private struct PreviewContent: View {
    let item: ClipboardItem
    let isSensitive: Bool
    let isRevealed: Bool
    @State private var isURLHovered = false

    private var type: ClipType { item.clipType }
    private var parsedColor: Color? { Color.parseHex(item.text) }
    private var shouldRedact: Bool { isSensitive && !isRevealed }

    var body: some View {
        VStack(alignment: .leading, spacing: previewSpacing) {
            if type == .image, let image = previewImage {
                imagePreview(image)
            } else if type == .color, let parsedColor {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(parsedColor)
                    .frame(width: 72, height: 72)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(MainWindowPalette.divider, lineWidth: 1)
                    )
                    .padding(.bottom, 4)
            }

            if type == .image {
                EmptyView()
            } else if type == .url {
                Button {
                    openURL()
                } label: {
                    redactedPreviewText(
                        foregroundColor: isURLHovered ? previewColor.opacity(0.84) : previewColor,
                        underline: true
                    )
                }
                .buttonStyle(.plain)
                .textSelection(.enabled)
                .onHover { hovering in
                    withAnimation(.easeOut(duration: MainWindowMotion.hoverDuration)) {
                        isURLHovered = hovering
                    }
                }
            } else {
                redactedPreviewText(foregroundColor: previewColor)
                    .textSelection(.enabled)
            }

            if shouldRedact {
                HStack(spacing: 6) {
                    AirClipIcon(.shield, size: 12)
                    Text("Sensitive content hidden")
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(MainWindowPalette.tertiaryText)
                .padding(.top, 10)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private func imagePreview(_ image: NSImage) -> some View {
        VStack(spacing: 0) {
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

            Text(item.text)
                .font(.system(size: 10, weight: .regular))
                .foregroundColor(MainWindowPalette.tertiaryText)
                .lineLimit(1)
                .truncationMode(.middle)
                .padding(.top, 100)
                .frame(maxWidth: 420)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func redactedPreviewText(
        foregroundColor: Color,
        underline: Bool = false
    ) -> some View {
        Text(item.text)
            .font(previewFont)
            .foregroundColor(foregroundColor)
            .underline(underline, color: foregroundColor)
            .lineSpacing(previewLineSpacing)
            .multilineTextAlignment(.leading)
            .blur(radius: shouldRedact ? 7 : 0)
            .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var previewImage: NSImage? {
        guard let data = item.imageData else { return nil }
        return NSImage(data: data)
    }

    private var previewFont: Font {
        let size: CGFloat = item.text.count > 260 ? 20 : previewBaseSize
        switch type {
        case .code:
            return .system(size: size.clamped(to: 13...13), weight: .regular, design: .monospaced)
        case .url:
            return .system(size: size.clamped(to: 18...18), weight: .regular)
        case .email:
            return .system(size: size.clamped(to: 18...18), weight: .regular, design: .monospaced)
        case .color:
            return .system(size: size.clamped(to: 20...20), weight: .medium, design: .monospaced)
        case .image:
            return .system(size: size.clamped(to: 18...18), weight: .regular)
        case .text:
            return .system(size: size, weight: .regular)
        }
    }

    private var previewBaseSize: CGFloat {
        switch type {
        case .code:
            return 13
        case .url:
            return 18
        case .email:
            return 18
        case .color:
            return 20
        case .image:
            return 18
        case .text:
            return 24
        }
    }

    private var previewColor: Color {
        switch type {
        case .url:
            return Color.syncBlue
        case .email:
            return Color.syncBlue
        case .color:
            return MainWindowPalette.primaryText
        case .code, .text:
            return MainWindowPalette.primaryText
        case .image:
            return MainWindowPalette.primaryText
        }
    }

    private var previewLineSpacing: CGFloat {
        switch type {
        case .code:
            return 4
        case .image:
            return 5
        case .text:
            return item.text.count > 480 ? 5 : 7
        default:
            return 5
        }
    }

    private var previewSpacing: CGFloat {
        type == .color ? 12 : 0
    }

    private func openURL() {
        let trimmed = item.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed) ?? URL(string: "https://\(trimmed)") else { return }
        NSWorkspace.shared.open(url)
    }
}

private extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        min(max(self, limits.lowerBound), limits.upperBound)
    }
}

private struct FloatingActions: View {
    let isSaved: Bool
    let onOpenBrowser: (() -> Void)?
    let sensitiveRevealState: Bool?
    let onToggleSensitiveReveal: (() -> Void)?
    let onCopy: () -> Void
    let onSave: () -> Void
    let onDelete: () -> Void

    @State private var didCopy = false

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
            if let sensitiveRevealState, let onToggleSensitiveReveal {
                ActionIconButton(
                    icon: .eye,
                    foregroundColor: sensitiveRevealState ? MainWindowPalette.primaryText : MainWindowPalette.secondaryText,
                    help: sensitiveRevealState ? "Hide sensitive content" : "Show sensitive content",
                    action: onToggleSensitiveReveal
                )
            }
            ActionIconButton(
                icon: didCopy ? .checkCircle : .copy,
                foregroundColor: didCopy ? MainWindowPalette.saved : MainWindowPalette.secondaryText,
                help: didCopy ? "Copied" : "Copy"
            ) {
                onCopy()
                withAnimation(.easeOut(duration: MainWindowMotion.feedbackDuration)) {
                    didCopy = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                    withAnimation(.easeOut(duration: MainWindowMotion.feedbackResetDuration)) {
                        didCopy = false
                    }
                }
            }
            .keyboardShortcut("c", modifiers: .command)
            ActionIconButton(
                icon: isSaved ? .bookmarkCheck : .bookmarkAdd,
                foregroundColor: isSaved ? MainWindowPalette.saved : MainWindowPalette.secondaryText,
                help: isSaved ? "Saved" : "Save",
                action: onSave
            )
            ActionIconButton(
                icon: .delete,
                foregroundColor: MainWindowPalette.secondaryText,
                hoverForegroundColor: MainWindowPalette.destructive,
                help: "Delete",
                action: onDelete
            )
            .keyboardShortcut(.delete, modifiers: [])
        }
        .padding(9)
        .frame(width: actionBarWidth, height: MainWindowLayout.actionBarHeight)
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
        let buttonCount = 3
            + (onOpenBrowser == nil ? 0 : 1)
            + (onToggleSensitiveReveal == nil ? 0 : 1)
        return CGFloat(18 + (40 * buttonCount) + (8 * max(buttonCount - 1, 0)))
    }
}

private struct ActionIconButton: View {
    let icon: AirClipIconName
    var foregroundColor: Color = MainWindowPalette.secondaryText
    var hoverForegroundColor: Color?
    let help: String
    let action: () -> Void

    @State private var isHovered = false
    @State private var isPressed = false

    var body: some View {
        Button {
            action()
        } label: {
            AirClipIcon(icon, size: 16)
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
        .help(help)
        .accessibilityLabel(help)
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

private struct DevicesPanel: View {
    @ObservedObject private var identity = AirClipIdentity.shared
    @ObservedObject private var peerManager = PeerManager.shared
    @ObservedObject private var syncModeStore = SyncModeStore.shared
    @ObservedObject private var lanDiagnostics = LanRuntimeDiagnostics.shared
    @StateObject private var currentWiFiNetwork = CurrentWiFiNetwork.shared

    @State private var hoveredDeviceID: String?
    @State private var pinnedDeviceID: String?
    @State private var deviceToRemove: PairedDevice?
    @State private var isShowingPairingSheet = false
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

                if !devices.isEmpty {
                    Button {
                        SyncEngine.shared.reconnect()
                        currentWiFiNetwork.requestAccessAndRefresh()
                    } label: {
                        Label("Reconnect", systemImage: "arrow.clockwise")
                            .font(.airClipCaptionMed)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityHint("Reconnects nearby paired devices")
                }

                DeviceAddButton {
                    isShowingPairingSheet = true
                }
            }
            .frame(height: 30, alignment: .topLeading)

            VStack(spacing: 12) {
                connectionSummary

                if devices.isEmpty {
                    VStack(spacing: 12) {
                        AirClipDeviceIcon(.smartPhone, size: 32, tint: MainWindowPalette.tertiaryText)
                        Text("No paired devices")
                            .font(.airClipTitle2)
                            .foregroundColor(MainWindowPalette.secondaryText)
                        Text("Add a device to sync clipboard items over your local network.")
                            .font(.airClipBody)
                            .foregroundColor(MainWindowPalette.tertiaryText)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityElement(children: .combine)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(devices.enumerated()), id: \.element.deviceId) { index, device in
                                deviceRow(device)
                                if index < devices.count - 1 {
                                    Rectangle()
                                        .fill(MainWindowPalette.divider)
                                        .frame(height: 0.5)
                                        .padding(.leading, 58)
                                }
                            }
                        }
                    }
                    .background(MainWindowPalette.sectionFill)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(MainWindowPalette.divider, lineWidth: 0.5)
                    )
                }
            }
            .padding(.top, 18)
        }
        .padding(.top, MainWindowLayout.devicesTopInset)
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
                }
                deviceToRemove = nil
            }
            Button("Cancel", role: .cancel) { deviceToRemove = nil }
        } message: {
            Text("This device will no longer sync with your AirClip network.")
        }
        .sheet(isPresented: $isShowingPairingSheet) {
            AddDevicePairingSheet()
        }
        .onAppear {
            currentWiFiNetwork.requestAccessAndRefresh()
        }
    }

    private var connectionSummary: some View {
        HStack(spacing: 10) {
            AirClipIcon(.wifi, size: 16, variant: .stroke)
                .foregroundColor(syncModeStore.mode == .paused ? MainWindowPalette.offline : Color.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text(hubWiFiStatus.displayName)
                    .font(.airClipBodyMedium)
                    .foregroundColor(MainWindowPalette.primaryText)
                Text(connectionSummaryText)
                    .font(.airClipCaption)
                    .foregroundColor(MainWindowPalette.secondaryText)
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 52)
        .background(MainWindowPalette.sectionFill)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(MainWindowPalette.divider, lineWidth: 0.5)
        )
        .accessibilityElement(children: .combine)
    }

    private var connectionSummaryText: String {
        if syncModeStore.mode == .paused { return "Sync paused" }
        if let helper = hubWiFiStatus.helperText { return helper }
        switch lanDiagnostics.diagnostic.issue {
        case .serverFailed: return "Listener unavailable — reconnect or check network access"
        case .discoveryFailed: return "Discovery unavailable — reconnect or check network access"
        case .none: return DeviceConnectionStatusText.onlineRemoteDevices(remoteOnlineCount)
        }
    }

    private func deviceRow(_ device: PairedDevice) -> some View {
        let isOnline = peerManager.connectedDeviceIds.contains(device.deviceId)
        return HStack(spacing: 12) {
            AirClipDeviceIcon(deviceIcon(for: device), size: 28, tint: isOnline ? Color.accent : MainWindowPalette.tertiaryText)
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 3) {
                Text(device.deviceName)
                    .font(.airClipBodyMedium)
                    .foregroundColor(MainWindowPalette.primaryText)
                    .lineLimit(1)
                Text(deviceDetail(device, isOnline: isOnline))
                    .font(.airClipCaption)
                    .foregroundColor(MainWindowPalette.secondaryText)
                    .lineLimit(1)
            }

            Spacer()

            HStack(spacing: 6) {
                Circle()
                    .fill(isOnline ? MainWindowPalette.online : MainWindowPalette.offline)
                    .frame(width: 6, height: 6)
                    .accessibilityHidden(true)
                Text(isOnline ? "Online" : lastSeenText(device))
                    .font(.airClipCaption)
                    .foregroundColor(MainWindowPalette.secondaryText)
            }

            Menu {
                if !isOnline {
                    Button("Reconnect") { SyncEngine.shared.reconnect() }
                }
                Button("Remove device", role: .destructive) { deviceToRemove = device }
            } label: {
                AirClipIcon(.moreHorizontal, size: 14)
                    .foregroundColor(MainWindowPalette.secondaryText)
                    .frame(width: 28, height: 28)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .accessibilityLabel("Actions for \(device.deviceName)")
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 58)
        .accessibilityElement(children: .contain)
    }

    private func deviceDetail(_ device: PairedDevice, isOnline: Bool) -> String {
        let platform = device.platform.isEmpty ? "Device" : device.platform.capitalized
        guard let network = device.wifiNetwork, !network.isEmpty else { return platform }
        return "\(platform) · \(network)"
    }

    private func lastSeenText(_ device: PairedDevice) -> String {
        guard device.lastSeenMs > 0 else { return "Offline" }
        let date = Date(timeIntervalSince1970: TimeInterval(device.lastSeenMs) / 1_000)
        return RelativeDateTimeFormatter().localizedString(for: date, relativeTo: Date())
    }

    private func deviceIcon(for device: PairedDevice) -> AirClipDeviceIconName {
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
                    AirClipIcon(.wifi, size: 28, variant: .stroke)
                        .foregroundColor(Color(hex: "#669C6C"))
                        .opacity(isHoveringIcon ? 0 : 1)
                        .scaleEffect(isHoveringIcon ? 0.92 : 1)
                    AirClipIcon(.refresh, size: 24)
                        .foregroundColor(Color(hex: "#7D64B5"))
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
                    .foregroundColor(MainWindowPalette.tertiaryText)
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
            return "Sync paused · resume to reconnect"
        }
        switch diagnostic.issue {
        case .serverFailed:
            return "Listener blocked · restart AirClip"
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
                AirClipIcon(.plus, size: 14)
                Text("Add Device")
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(MainWindowPalette.primaryText)
            .padding(.horizontal, 12)
            .frame(height: 28)
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

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(MainWindowPalette.searchFill)
                    AirClipIcon(.deviceSync, size: 22)
                        .foregroundColor(MainWindowPalette.secondaryText)
                }
                .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 5) {
                    Text(pairingSheet.didPairDevice ? "Device added" : "Add a device")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(MainWindowPalette.primaryText)

                    Text(pairingSheet.didPairDevice ? "The new device is now part of this AirClip network." : "Scan the QR code or enter the numeric code on the device you want to add.")
                        .font(.system(size: 12))
                        .foregroundColor(MainWindowPalette.secondaryText)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Button {
                    dismiss()
                } label: {
                    AirClipIcon(.remove, size: 14)
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
                } else {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            .frame(width: 224, height: 224)
            .padding(.bottom, 18)

            if let code = pairing.currentCode {
                VStack(spacing: 6) {
                    Text("Numeric code")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(MainWindowPalette.tertiaryText)
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
                    .foregroundColor(MainWindowPalette.secondaryText.opacity(0.72))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: onRemove) {
                AirClipIcon(.close, size: 16)
                    .foregroundColor(MainWindowPalette.secondaryText.opacity(0.72))
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
        AirClipDeviceIcon(deviceIcon, size: MainWindowLayout.deviceOrbitNodeSize, tint: tint)
        .frame(width: MainWindowLayout.deviceOrbitNodeSize, height: MainWindowLayout.deviceOrbitNodeSize)
        .opacity(isOnline ? 1 : 0.50)
    }

    private var deviceIcon: AirClipDeviceIconName {
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
    @ObservedObject private var identity = AirClipIdentity.shared
    @ObservedObject private var appearanceStore = AppAppearanceStore.shared
    @ObservedObject private var syncModeStore = SyncModeStore.shared
    @ObservedObject private var sensitiveProtection = SensitiveClipboardProtectionStore.shared

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
                            icon: .eye,
                            iconTint: MainWindowPalette.secondaryText,
                            iconFill: MainWindowPalette.activeFill,
                            title: "Theme"
                        ) {
                            appearanceChooser
                                .frame(width: 220)
                        }
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
                        settingsDivider
                        sensitiveProtectionContent
                    }
                }

                settingsSection("Keyboard Shortcuts") {
                    settingsGroup {
                        shortcutRow("Open AirClip", keys: ["⌘", "⇧", "V"])
                        settingsDivider
                        shortcutRow("Copy item", keys: ["⌘", "C"])
                        settingsDivider
                        shortcutRow("Delete item", keys: ["⌫"])
                    }
                }

                settingsSection("About") {
                    settingsGroup {
                        infoRow("Version", value: bundleValue("CFBundleShortVersionString"))
                        settingsDivider
                        infoRow("Build", value: bundleValue("CFBundleVersion"))
                    }
                }

                SettingsActionRow(
                    icon: .delete,
                    title: "Clear History",
                    subtitle: "Permanently removes every local clip, including saved clips.",
                    tint: MainWindowPalette.destructive,
                    hoverFill: MainWindowPalette.dangerHoverFill
                ) {
                    showClearHistoryAlert = true
                }
                .background(cardBackground(cornerRadius: 16))
                .padding(.bottom, 12)

                SettingsActionRow(
                    icon: .undo,
                    title: "Leave Network",
                    subtitle: "Removes this device from AirClip. Other devices stay connected.",
                    tint: MainWindowPalette.destructive,
                    hoverFill: MainWindowPalette.dangerHoverFill
                ) {
                    showResetAlert = true
                }
                .background(cardBackground(cornerRadius: 16))
            }
            .padding(MainWindowLayout.settingsInset)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.never)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(MainWindowPalette.card)
        .alert("Leave Network?", isPresented: $showResetAlert) {
            Button("Leave", role: .destructive) { identity.leaveNetwork() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes this device from AirClip and clears local pairing data. Other devices stay connected.")
        }
        .alert("Clear local history?", isPresented: $showClearHistoryAlert) {
            Button("Clear History", role: .destructive) { LocalHistoryStore.shared.clearAll() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently removes every clipboard item stored on this Mac, including saved clips.")
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
                AirClipLogoMark()
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
                Text("Tune AirClip for this Mac, keep the UI readable, and keep the behavior predictable.")
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

    private func metricCard(icon: AirClipIconName, value: String, label: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                AirClipIcon(icon, size: 13)
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
        icon: AirClipIconName,
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
                    AirClipIcon(icon, size: 14)
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
            .fill(MainWindowPalette.sectionFill.opacity(0.96))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(MainWindowPalette.divider.opacity(0.9), lineWidth: 0.5)
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
    }

    private func settingsRow<Accessory: View>(
        icon: AirClipIconName,
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
        .padding(.horizontal, 14)
        .frame(minHeight: 62)
    }

    private func settingsIcon(_ icon: AirClipIconName, tint: Color, fill: Color) -> some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(fill)
            .frame(width: 34, height: 34)
            .overlay(
                AirClipIcon(icon, size: 16)
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
                                .fill(appearanceStore.rawValue == option.rawValue ? MainWindowPalette.card : .clear)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .strokeBorder(appearanceStore.rawValue == option.rawValue ? MainWindowPalette.divider : .clear, lineWidth: 0.5)
                                )
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(MainWindowPalette.searchFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(MainWindowPalette.divider.opacity(0.8), lineWidth: 0.5)
                )
        )
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
                                .fill(syncModeStore.mode == mode ? MainWindowPalette.card : .clear)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .strokeBorder(syncModeStore.mode == mode ? MainWindowPalette.divider : .clear, lineWidth: 0.5)
                                )
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(MainWindowPalette.searchFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(MainWindowPalette.divider.opacity(0.8), lineWidth: 0.5)
                )
        )
    }

    private var encryptionRow: some View {
        settingsRow(
            icon: .shield,
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
                .background(Capsule(style: .continuous).fill(MainWindowPalette.saved.opacity(0.12)))
        }
    }

    private var locationServicesRow: some View {
        settingsRow(
            icon: .wifi,
            iconTint: Color(hex: "#669C6C"),
            iconFill: Color(hex: "#669C6C").opacity(0.12),
            title: "Wi-Fi network name",
            subtitle: "Allow Location Services so AirClip can show your current Wi-Fi."
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
                    .fill(MainWindowPalette.searchFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(MainWindowPalette.divider.opacity(0.8), lineWidth: 0.5)
                    )
            )
        }
    }

    private var sensitiveProtectionContent: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                settingsIcon(.shield, tint: MainWindowPalette.secondaryText, fill: MainWindowPalette.activeFill)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Sensitive sync")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(MainWindowPalette.primaryText)
                    Text(sensitiveProtection.masterAction == .allow ? "All sensitive clips are allowed by default." : "Category rules apply below.")
                        .font(.system(size: 11))
                        .foregroundColor(MainWindowPalette.secondaryText)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 12)
                Picker(
                    "Sensitive sync",
                    selection: Binding(
                        get: { sensitiveProtection.masterAction },
                        set: { sensitiveProtection.setMasterAction($0) }
                    )
                ) {
                    ForEach(SensitiveRuleAction.allCases, id: \.rawValue) { action in
                        Text(action.label).tag(action)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(width: 92)
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 62)

            if sensitiveProtection.masterAction != .allow {
                settingsDivider

                ForEach(Array(SensitiveCategory.allCases.enumerated()), id: \.element.rawValue) {
                    index,
                    category in
                    HStack {
                        Text(category.label)
                            .font(.system(size: 12))
                            .foregroundColor(MainWindowPalette.primaryText)
                        Spacer()
                        Picker(
                            category.label,
                            selection: Binding(
                                get: { sensitiveProtection.action(for: category) },
                                set: { sensitiveProtection.setAction($0, for: category) }
                            )
                        ) {
                            ForEach(SensitiveRuleAction.allCases, id: \.rawValue) { action in
                                Text(action.label).tag(action)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(width: 92)
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 38)

                    if index < SensitiveCategory.allCases.count - 1 {
                        settingsDivider
                    }
                }
            }

            Text("Ask stops automatic sync for matching clips until you approve them.")
                .font(.system(size: 11))
                .foregroundColor(MainWindowPalette.secondaryText)
                .padding(.horizontal, 14)
                .padding(.top, 8)
                .padding(.bottom, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
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
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(MainWindowPalette.tertiaryText)
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
            .fill(MainWindowPalette.divider)
            .frame(height: 1)
            .padding(.leading, 14)
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
        .padding(.horizontal, 14)
        .frame(height: 40)
    }

    private func infoRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(MainWindowPalette.primaryText)
            Spacer()
            Text(value)
                .font(.system(size: 13))
                .foregroundColor(MainWindowPalette.tertiaryText)
        }
        .padding(.horizontal, 14)
        .frame(height: 40)
    }
}

private struct SettingsActionRow: View {
    let icon: AirClipIconName
    let title: String
    let subtitle: String
    let tint: Color
    let hoverFill: Color
    let action: () -> Void

    @State private var isHovered = false
    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                AirClipIcon(icon, size: 14)
                    .foregroundColor(tint)
                    .frame(width: 16)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13))
                        .foregroundColor(tint)
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(MainWindowPalette.secondaryText)
                }
                Spacer()
            }
            .padding(.horizontal, 14)
            .frame(height: 54)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isHovered || isPressed ? hoverFill : .clear)
            )
            .scaleEffect(isPressed ? MainWindowMotion.rowPressScale : 1)
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
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
