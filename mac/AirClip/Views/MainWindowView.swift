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
    static let windowHeight: CGFloat = 558
    static let sidebarHorizontalPadding: CGFloat = 8
    static let cardRightInset: CGFloat = 8
    static let cardBottomInset: CGFloat = 8
    static let contentHeight: CGFloat = windowHeight - cardBottomInset
    static let contentWidth: CGFloat = windowWidth - cardRightInset * 2
    static let sidebarWidth: CGFloat = 140
    static let sidebarInnerWidth: CGFloat = sidebarWidth - sidebarHorizontalPadding * 2
    static let mainCardWidth: CGFloat = 696
    static let listWidth: CGFloat = 256
    static let listSearchHorizontalInset: CGFloat = 12
    static let listHeaderHorizontalInset: CGFloat = 12
    static let listRowHorizontalInset: CGFloat = 12
    static let listSearchHeight: CGFloat = 64
    static let previewWidth: CGFloat = 440
    static let navItemHeight: CGFloat = 32
    static let navCornerRadius: CGFloat = 10
    static let rowWidth: CGFloat = 232
    static let rowHeight: CGFloat = 70
    static let rowIconWidth: CGFloat = 16
    static let actionBarWidth: CGFloat = 154
    static let actionBarHeight: CGFloat = 50
    static let previewTopInset: CGFloat = 32
    static let previewLeadingInset: CGFloat = 32
    static let previewTrailingInset: CGFloat = 40
    static let previewBottomInset: CGFloat = 84
    static let previewActionTrailingInset: CGFloat = 16
    static let previewActionBottomInset: CGFloat = 16
    static let settingsInset: CGFloat = 32
    static let settingsMaxWidth: CGFloat = 520
    static let devicesHorizontalInset: CGFloat = 24
    static let devicesTopInset: CGFloat = 16
    static let deviceOrbitHubSize: CGFloat = 48
    static let deviceOrbitNodeSize: CGFloat = 56
    static let deviceOrbitTooltipWidth: CGFloat = 76
    static let deviceOrbitTooltipHeight: CGFloat = 38
    static let deviceOrbitTooltipGap: CGFloat = 8
    static let deviceOrbitTooltipTextGap: CGFloat = 4
    static let deviceOrbitStroke: CGFloat = 1
    static let textBadgeFill = Color(hex: "#78A57F").opacity(0.16)
    static let textBadgeForeground = Color(hex: "#78A57F")
    static let linkBadgeFill = Color(hex: "#695DF3").opacity(0.16)
    static let linkBadgeForeground = Color(hex: "#695DF3")
    static let codeBadgeFill = Color(hex: "#E5760E").opacity(0.16)
    static let codeBadgeForeground = Color(hex: "#E5760E")
    static let emailBadgeFill = Color(hex: "#70CBFF").opacity(0.16)
    static let emailBadgeForeground = Color(hex: "#70CBFF")
    static let colorBadgeFill = Color(hex: "#10B981").opacity(0.16)
    static let colorBadgeForeground = Color(hex: "#10B981")
    static let imageBadgeFill = Color.white.opacity(0.06)
    static let imageBadgeForeground = Color(hex: "#C4CBD8")
    static let badgeBorder = Color(hex: "#9E9E9E").opacity(0.5)
    static let codeTitleText = Color(hex: "#525F7A")
    static let searchBackground = MainWindowPalette.searchIdleFill
    static let searchBorder = MainWindowPalette.searchIdleBorder
    static let sectionHeaderText = MainWindowPalette.sectionHeaderText
    static let listTitleText = MainWindowPalette.listTitleText
    static let listMetaText = MainWindowPalette.listMetaText
}

private enum MainWindowPalette {
    static let shell = adaptive(light: "#F4F6FA", dark: "#121418").opacity(0.88)
    static let shellGlassTint = Color.glassTint.opacity(0.06)
    static let card = adaptive(light: "#FFFFFF", dark: "#1E2024")
    static let primaryText = adaptive(light: "#101828", dark: "#F2F3F5")
    static let secondaryText = adaptive(light: "#4A5565", dark: "#C4C8D0")
    static let tertiaryText = adaptive(light: "#99A1AF", dark: "#8F949D")
    static let divider = adaptive(light: "#E5E7EB", dark: "#343741")
    static let activeFill = adaptive(light: "#EFF0F0", dark: "#2A2D33")
    static let hoverFill = adaptive(light: "#F6F7F7", dark: "#272A30")
    static let pressedFill = adaptive(light: "#E9EAEA", dark: "#323640")
    static let searchFill = adaptive(light: "#F3F4F6", dark: "#282B31")
    static let focusStroke = Color(hex: "#10B981").opacity(0.42)
    static let rowStroke = adaptive(light: "#E5E7EB", dark: "#3A3E48").opacity(0.72)
    static let saved = Color(hex: "#10B981")
    static let destructive = Color(hex: "#EF4444")
    static let sectionFill = adaptive(light: "#FCFCFD", dark: "#23262B")
    static let dangerHoverFill = adaptive(light: "#FEF2F2", dark: "#351D20")
    static let online = Color(hex: "#19C332")
    static let offline = adaptive(light: "#D7D8DA", dark: "#5D6470")
    static let sidebarText = adaptive(light: "#1E293B", dark: "#E8EDF5")
    static let sidebarHoverFill = adaptive(light: "#EEF2F7", dark: "#2A2E36")
    static let sidebarActiveFill = adaptive(light: "#E3F1EA", dark: "#213129")
    static let sidebarActiveBorder = adaptive(light: "#B9E2CE", dark: "#2E4D3C")
    static let sidebarItemBorder = Color(hex: "#EEF1F1")
    static let searchIdleFill = adaptive(light: "#F3F4F6", dark: "#34373D").opacity(0.40)
    static let searchIdleBorder = adaptive(light: "#F1F1F1", dark: "#4A4E57")
    static let sectionHeaderText = adaptive(light: "#6A7282", dark: "#A5ADBC")
    static let listTitleText = adaptive(light: "#232E43", dark: "#EEF2F7")
    static let listMetaText = adaptive(light: "#232E43", dark: "#C8CED8").opacity(0.50)

    private static func adaptive(light: String, dark: String) -> Color {
        Color(NSColor(name: nil, dynamicProvider: { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            let hex = (isDark ? dark : light).trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
            var int: UInt64 = 0
            Scanner(string: hex).scanHexInt64(&int)
            return NSColor(
                srgbRed: CGFloat((int & 0xFF0000) >> 16) / 255,
                green: CGFloat((int & 0x00FF00) >> 8) / 255,
                blue: CGFloat(int & 0x0000FF) / 255,
                alpha: 1
            )
        }))
    }
}

private enum MainWindowMotion {
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

    private var currentMainCardWidth: CGFloat {
        isNavigationCollapsed ? MainWindowLayout.contentWidth : MainWindowLayout.mainCardWidth
    }

    var body: some View {
        HStack(spacing: 8) {
            if !isNavigationCollapsed {
                sideNavigation
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }
            mainCard
        }
        .frame(width: MainWindowLayout.contentWidth, height: MainWindowLayout.contentHeight, alignment: .topLeading)
        .padding(.horizontal, MainWindowLayout.cardRightInset)
        .padding(.bottom, MainWindowLayout.cardBottomInset)
        .frame(width: MainWindowLayout.windowWidth, height: MainWindowLayout.windowHeight, alignment: .topLeading)
        .background {
            Rectangle()
                .fill(MainWindowPalette.shell)
                .glassEffect(.regular.tint(MainWindowPalette.shellGlassTint), in: .rect)
                .shadow(color: Color.textSecondary.opacity(0.12), radius: 24, x: 0, y: 4)
        }
        .onReceive(NotificationCenter.default.publisher(for: .openSettingsTab)) { _ in
            withAnimation(.easeOut(duration: 0.18)) {
                activePage = .settings
            }
        }
    }

    private var sideNavigation: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(spacing: 6) {
                ForEach(MainPage.allCases, id: \.self) { page in
                    SidebarNavItem(
                        page: page,
                        isActive: activePage == page,
                        count: page == .saved ? savedCount : nil
                    ) {
                        withAnimation(.easeOut(duration: 0.18)) {
                            activePage = page
                        }
                    }
                }
            }
            .padding(.top, 16)

            Spacer()

            SidebarBrandMark()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 8)
                .padding(.bottom, 8)
        }
        .frame(width: MainWindowLayout.sidebarInnerWidth)
        .padding(.horizontal, MainWindowLayout.sidebarHorizontalPadding)
        .frame(width: MainWindowLayout.sidebarWidth, height: MainWindowLayout.contentHeight)
    }

    @ViewBuilder
    private var mainCard: some View {
        Group {
            switch activePage {
            case .home:
                ClipboardWorkspace(
                    filter: .all,
                    workspaceWidth: currentMainCardWidth,
                    isNavigationCollapsed: $isNavigationCollapsed
                )
            case .saved:
                ClipboardWorkspace(
                    filter: .saved,
                    workspaceWidth: currentMainCardWidth,
                    isNavigationCollapsed: $isNavigationCollapsed
                )
            case .devices:
                DevicesPanel()
            case .settings:
                SettingsPanel()
            }
        }
        .frame(width: currentMainCardWidth, height: MainWindowLayout.contentHeight)
        .background(MainWindowPalette.card)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .shadow(color: Color.textSecondary.opacity(0.12), radius: 24, x: 0, y: 4)
        .animation(.easeOut(duration: 0.18), value: isNavigationCollapsed)
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
        HStack(spacing: 6) {
            AirClipLogoMark()
                .frame(width: 18, height: 18)
            Text("AirClip")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(MainWindowPalette.sidebarText)
        }
        .accessibilityLabel("AirClip")
    }
}

struct AirClipLogoMark: View {
    var body: some View {
        ZStack {
            Circle()
                .stroke(MainWindowPalette.saved, lineWidth: 3.2)
                .frame(width: 18, height: 18)
            Circle()
                .fill(MainWindowPalette.saved)
                .frame(width: 5, height: 5)
                .offset(y: 4)
        }
        .frame(width: 18, height: 18)
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

    var title: String {
        switch self {
        case .all: return "All"
        case .text: return "Text"
        case .links: return "Links"
        case .images: return "Images"
        }
    }

    var clipType: ClipType? {
        switch self {
        case .all: return nil
        case .text: return .text
        case .links: return .url
        case .images: return .image
        }
    }
}

private struct ClipboardWorkspace: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ClipboardItem.receivedAt, order: .reverse) private var allItems: [ClipboardItem]
    @ObservedObject private var revealStore = SensitiveContentRevealStore.shared

    let filter: ClipFilter
    let workspaceWidth: CGFloat
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
        .frame(width: workspaceWidth, height: MainWindowLayout.contentHeight)
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
        .frame(width: MainWindowLayout.listWidth, height: MainWindowLayout.contentHeight)
        .background(MainWindowPalette.card)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(MainWindowPalette.divider)
                .frame(width: 1)
        }
    }

    private var searchBar: some View {
        HStack(spacing: 12) {
            Button {
                withAnimation(.easeOut(duration: 0.18)) {
                    isNavigationCollapsed.toggle()
                }
            } label: {
                AirClipIcon(.sidebarLeft, size: 20, variant: .stroke)
                    .foregroundColor(MainWindowPalette.secondaryText)
                    .frame(width: 20, height: 20)
                    .scaleEffect(x: isNavigationCollapsed ? -1 : 1, y: 1)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(isNavigationCollapsed ? "Show sidebar" : "Hide sidebar")

            HStack(spacing: 8) {
                AirClipIcon(.search, size: 16)
                    .foregroundColor(MainWindowPalette.tertiaryText)
                TextField("Search words or category", text: $searchQuery)
                    .font(.system(size: 10))
                    .foregroundColor(MainWindowPalette.primaryText)
                    .textFieldStyle(.plain)
                    .focused($searchFocused)
                searchTrailingControl
            }
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, minHeight: 32, idealHeight: 32, maxHeight: 32)
            .background(searchBackground)
            .overlay(searchBorder)
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .onTapGesture {
                searchFocused = true
            }
        }
        .padding(.horizontal, MainWindowLayout.listSearchHorizontalInset)
        .padding(.vertical, 16)
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
    }

    @ViewBuilder
    private var sectionHeader: some View {
        if let firstItem = filteredItems.first {
            Text(sectionTitle(for: firstItem.receivedAt))
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(MainWindowLayout.sectionHeaderText)
                .frame(maxWidth: .infinity, minHeight: 32, maxHeight: 32, alignment: .leading)
                .padding(.horizontal, MainWindowLayout.listHeaderHorizontalInset)
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
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.text)
                        .font(titleFont(for: item))
                        .foregroundColor(titleColor(for: item))
                        .underline(item.clipType == .url)
                        .lineLimit(1)
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
            .padding(.horizontal, MainWindowLayout.listRowHorizontalInset)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(rowBackground(active: active, hovered: hovered))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .strokeBorder(rowStroke(active: active, hovered: hovered), lineWidth: rowStrokeWidth(active: active, hovered: hovered))
                    )
            )
            .contentShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
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
        if active { return MainWindowPalette.divider }
        if hovered { return MainWindowPalette.rowStroke }
        return .clear
    }

    private func rowStrokeWidth(active: Bool, hovered: Bool) -> CGFloat {
        (active || hovered) ? 0.5 : 0
    }

    private var emptyListState: some View {
        VStack(spacing: 10) {
            AirClipIcon(filter == .saved ? .bookmark : .clipboard, size: 18)
                .foregroundColor(MainWindowPalette.tertiaryText)
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(MainWindowPalette.searchFill)
                )
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
        .frame(width: MainWindowLayout.rowWidth)
        .padding(.horizontal, 8)
        .padding(.top, 76)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var emptyListTitle: String {
        if !searchQuery.isEmpty { return "No matches" }
        if selectedTypeFilter != .all { return "No \(selectedTypeFilter.title.lowercased()) clips" }
        return filter == .saved ? "No saved clips" : "No clips yet"
    }

    private var emptyListSubtitle: String {
        if !searchQuery.isEmpty { return "Try a different search." }
        if selectedTypeFilter != .all { return "Try another type filter." }
        return filter == .saved ? "Saved clips appear here." : "Copied text appears here."
    }

    @ViewBuilder
    private func clipTypeBadge(for item: ClipboardItem) -> some View {
        let type = item.clipType
        switch type {
        case .text:
            clipBadge(background: MainWindowLayout.textBadgeFill) {
                AirClipIcon(.text, size: 14)
                    .foregroundColor(MainWindowLayout.textBadgeForeground)
            }
        case .url:
            clipBadge(background: MainWindowLayout.linkBadgeFill) {
                AirClipIcon(.arrowUpRight, size: 14)
                    .foregroundColor(MainWindowLayout.linkBadgeForeground)
            }
        case .code:
            clipBadge(background: MainWindowLayout.codeBadgeFill) {
                AirClipIcon(.code, size: 14)
                    .foregroundColor(MainWindowLayout.codeBadgeForeground)
            }
        case .image:
            clipBadge(background: MainWindowLayout.imageBadgeFill) {
                if let image = item.imageData.flatMap(NSImage.init(data:)) {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 27, height: 27)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                } else {
                    AirClipIcon(.image, size: 14)
                        .foregroundColor(MainWindowLayout.imageBadgeForeground)
                }
            }
        case .email:
            clipBadge(background: MainWindowLayout.emailBadgeFill) {
                AirClipIcon(.mail, size: 14)
                    .foregroundColor(MainWindowLayout.emailBadgeForeground)
            }
        case .color:
            clipBadge(background: MainWindowPalette.searchFill) {
                AirClipIcon(.color, size: 14)
                    .foregroundColor(parsedColor(for: item) ?? MainWindowLayout.colorBadgeForeground)
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
        .frame(width: previewWidth, height: MainWindowLayout.contentHeight)
        .background(MainWindowPalette.card)
    }

    private var previewWidth: CGFloat {
        max(workspaceWidth - MainWindowLayout.listWidth, MainWindowLayout.previewWidth)
    }

    private func previewBackground(for item: ClipboardItem) -> Color {
        if item.clipType == .color, let color = parsedColor(for: item) {
            return color.opacity(0.2)
        }
        return MainWindowPalette.card
    }

    private var emptyPreviewState: some View {
        VStack(spacing: 10) {
            AirClipIcon(filter == .saved ? .bookmark : .clipboard, size: 20)
                .foregroundColor(MainWindowPalette.tertiaryText)
                .frame(width: 36, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(MainWindowPalette.searchFill)
                )
            Text(filter == .saved ? "Select a saved clip" : "Select a clip")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(MainWindowPalette.secondaryText)
            Text(filter == .saved ? "Saved clipboard content previews here." : "Clipboard content previews here.")
                .font(.system(size: 11))
                .foregroundColor(MainWindowPalette.tertiaryText)
        }
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
        if selectedItem?.id == item.id {
            selectedItem = filteredItems.first { $0.id != item.id }
        }
        revealStore.setRevealed(false, for: item.id)
        modelContext.delete(item)
        try? modelContext.save()
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

    private var networkLabel: String {
        if let currentNetwork = CurrentWiFiNetwork.name(), !currentNetwork.isEmpty {
            return currentNetwork
        }
        let names = orbitItems
            .filter(\.isOnline)
            .compactMap { $0.device.wifiNetwork }
            .filter { !$0.isEmpty }
        if let first = names.first, names.allSatisfy({ $0 == first }) {
            return first
        }
        return "Wi-Fi network"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Text("Devices")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(MainWindowPalette.primaryText)

                Spacer()

                DeviceAddButton {
                    isShowingPairingSheet = true
                }
            }
            .frame(height: 30, alignment: .topLeading)

            GeometryReader { proxy in
                let size = proxy.size
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let placements = orbitPlacements(in: size)

                ZStack {
                    OrbitBackdrop()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    orbitFade(edge: .top)
                        .frame(height: 120)
                        .frame(maxHeight: .infinity, alignment: .top)

                    orbitFade(edge: .bottom)
                        .frame(height: 120)
                        .frame(maxHeight: .infinity, alignment: .bottom)

                    ForEach(placements) { placement in
                        OrbitDeviceNode(
                            item: placement.item,
                            isVisible: activeTooltipID == placement.item.device.deviceId,
                            isActive: activeTooltipID == placement.item.device.deviceId,
                            tooltipPlacement: placement.tooltipPlacement,
                            onTap: { togglePinned(placement.item.device.deviceId) },
                            onHover: { hovering in updateHoveredDevice(placement.item.device.deviceId, hovering: hovering) },
                            onRemove: { deviceToRemove = placement.item.device }
                        )
                        .position(placement.position)
                    }

                    if orbitItems.isEmpty {
                        DevicesEmptyState {
                            isShowingPairingSheet = true
                        }
                            .position(center)
                    } else {
                        NetworkHubView(
                            networkName: networkLabel,
                            remoteOnlineCount: remoteOnlineCount,
                            isPaused: syncModeStore.mode == .paused,
                            diagnostic: lanDiagnostics.diagnostic,
                            hasDevices: true
                        )
                        .position(center)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                .contentShape(Rectangle())
                .onTapGesture {
                    clearTooltip()
                }
            }
        }
        .padding(.top, MainWindowLayout.devicesTopInset)
        .padding(.horizontal, MainWindowLayout.devicesHorizontalInset)
        .frame(width: MainWindowLayout.mainCardWidth, height: MainWindowLayout.contentHeight, alignment: .topLeading)
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
            let rings: [CGFloat] = [0.16, 0.27, 0.39, 0.50].map { size * $0 }

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
    let networkName: String
    let remoteOnlineCount: Int
    let isPaused: Bool
    let diagnostic: LanRuntimeDiagnostic
    let hasDevices: Bool

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                MainWindowPalette.card,
                                MainWindowPalette.activeFill.opacity(0.80)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(
                        Circle()
                            .strokeBorder(MainWindowPalette.divider.opacity(0.88), lineWidth: 1)
                    )
                    .shadow(color: MainWindowPalette.divider.opacity(0.85), radius: 1, x: 0, y: 1)
                AirClipIcon(.wifi, size: 24, variant: .stroke)
                    .foregroundColor(MainWindowPalette.saved)
            }
            .frame(width: MainWindowLayout.deviceOrbitHubSize, height: MainWindowLayout.deviceOrbitHubSize)

            VStack(spacing: 0) {
                Text(networkName)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(MainWindowPalette.primaryText)
                    .lineLimit(1)
                Text(statusText)
                    .font(.system(size: 10))
                    .foregroundColor(MainWindowPalette.secondaryText.opacity(0.72))
                    .multilineTextAlignment(.center)
            }
        }
        .opacity(hasDevices ? 1 : 0.92)
    }

    private var statusText: String {
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

private struct DevicesEmptyState: View {
    let onAddDevice: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(MainWindowPalette.searchFill)
                    .overlay(
                        Circle()
                            .strokeBorder(MainWindowPalette.divider.opacity(0.72), lineWidth: 0.5)
                    )

                AirClipIcon(.deviceSync, size: 20)
                    .foregroundColor(MainWindowPalette.secondaryText)
            }
            .frame(width: 44, height: 44)

            VStack(spacing: 4) {
                Text("Waiting for paired devices")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(MainWindowPalette.secondaryText)
                    .multilineTextAlignment(.center)

                Text("Paired devices will appear here once they connect.")
                    .font(.system(size: 11))
                    .foregroundColor(MainWindowPalette.tertiaryText)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }

            DeviceAddButton(action: onAddDevice)
                .padding(.top, 2)
        }
        .frame(width: 236)
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
        guard code.count == 8 else { return code }
        return "\(code.prefix(4)) \(code.suffix(4))"
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
                    isOnline: item.isOnline
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
            width: MainWindowLayout.deviceOrbitNodeSize + 24,
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

    private var statusText: String {
        if isOnline {
            return device.lastSeenMs > 0 ? "Online · \(relativeLastSeen)" : "Online now"
        }
        return device.lastSeenMs > 0 ? "Last seen \(relativeLastSeen)" : "Offline"
    }

    private var relativeLastSeen: String {
        let lastSeen = Date(timeIntervalSince1970: TimeInterval(device.lastSeenMs) / 1000)
        let diff = max(0, Int(Date().timeIntervalSince(lastSeen)))
        if diff < 60 { return "just now" }
        let minutes = diff / 60
        if minutes < 60 { return "\(minutes)m ago" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours)h ago" }
        return "\(hours / 24)d ago"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: MainWindowLayout.deviceOrbitTooltipTextGap) {
            Text(DeviceDisplayText.clipped(device.deviceName))
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(MainWindowPalette.primaryText)
                .lineLimit(1)
                .help(device.deviceName)

            Text(statusText)
                .font(.system(size: 10))
                .foregroundColor(MainWindowPalette.secondaryText.opacity(0.72))
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .fixedSize(horizontal: true, vertical: false)
        .frame(minHeight: MainWindowLayout.deviceOrbitTooltipHeight, alignment: .leading)
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

    @State private var historyDepth: Int = UserDefaults.standard.object(forKey: "historyDepth") as? Int ?? 1
    @State private var showResetAlert = false
    @State private var isHistoryHovered = false
    @State private var isHistoryPressed = false

    private let historyOptions = ["7 days", "30 days", "90 days", "Forever"]
    private let historyDays = [7, 30, 90, 0]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                settingsHeader
                    .padding(.bottom, 16)

                settingsMetricRow
                    .padding(.bottom, 16)

                VStack(spacing: 16) {
                    settingsPanelCard(
                        title: "Sync mode",
                        icon: .deviceSync,
                        subtitle: "Control when clipboard content can leave this Mac."
                    ) {
                        syncModeChooser
                    }

                    settingsPanelCard(
                        title: "Appearance",
                        icon: .eye,
                        subtitle: "Follow the system or pin AirClip to one look."
                    ) {
                        appearanceChooser
                    }

                    settingsPanelCard(
                        title: "History",
                        icon: .clock,
                        subtitle: "Choose how long clips stay on this Mac."
                    ) {
                        historyMenuRow
                        Text("Pruning keeps the list fast and reduces clutter.")
                            .font(.system(size: 11))
                            .foregroundColor(MainWindowPalette.tertiaryText)
                            .padding(.horizontal, 14)
                            .padding(.bottom, 12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    settingsPanelCard(
                        title: "Privacy & Security",
                        icon: .shield,
                        subtitle: "Encryption stays on. There is no user toggle."
                    ) {
                        privacyContent
                    }

                    settingsPanelCard(
                        title: "Sensitive Content",
                        icon: .shield,
                        subtitle: "Choose what happens when AirClip detects credentials or financial data."
                    ) {
                        sensitiveProtectionContent
                    }

                    settingsPanelCard(
                        title: "Keyboard Shortcuts",
                        icon: .keyboard,
                        subtitle: "Fast paths for the commands you use often."
                    ) {
                        shortcutRow("Open AirClip", keys: ["⌘", "⇧", "V"])
                        settingsDivider
                        shortcutRow("Copy item", keys: ["⌘", "C"])
                        settingsDivider
                        shortcutRow("Delete item", keys: ["⌫"])
                    }

                    settingsPanelCard(
                        title: "About",
                        icon: .info,
                        subtitle: "Build and version details for this app."
                    ) {
                        infoRow("Version", value: "1.2.0")
                        settingsDivider
                        infoRow("Build", value: "2025.1")
                    }

                    settingsPanelCard(
                        title: "AirClip",
                        icon: .undo,
                        subtitle: "Leave the current AirClip network and clear local data."
                    ) {
                        SettingsActionRow(
                            icon: .undo,
                            title: "Leave AirClip & Reset",
                            subtitle: "Removes all pairings and history from this Mac.",
                            tint: MainWindowPalette.destructive,
                            hoverFill: MainWindowPalette.dangerHoverFill
                        ) {
                            showResetAlert = true
                        }
                        .padding(.horizontal, 4)
                        .padding(.vertical, 4)
                    }
                }
            }
            .padding(MainWindowLayout.settingsInset)
            .frame(maxWidth: MainWindowLayout.settingsMaxWidth, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.never)
        .frame(width: MainWindowLayout.mainCardWidth, height: MainWindowLayout.contentHeight)
        .background(
            LinearGradient(
                colors: [
                    MainWindowPalette.card,
                    MainWindowPalette.sectionFill.opacity(0.66)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .alert("Leave AirClip & Reset?", isPresented: $showResetAlert) {
            Button("Leave & Reset", role: .destructive) { identity.clearAll() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes all device pairings and clipboard history from this Mac. Other devices in the AirClip network are unaffected.")
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

    private var appearanceChooser: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                ForEach(AppAppearanceSetting.allCases, id: \.rawValue) { option in
                    Button {
                        appearanceStore.rawValue = option.rawValue
                    } label: {
                        Text(option.label)
                            .font(.system(size: 11.5, weight: appearanceStore.rawValue == option.rawValue ? .semibold : .regular))
                            .foregroundColor(appearanceStore.rawValue == option.rawValue ? MainWindowPalette.primaryText : MainWindowPalette.secondaryText)
                            .frame(maxWidth: .infinity)
                            .frame(height: 30)
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

            Text("System follows macOS. Light and dark keep the same spacing and contrast rules.")
                .font(.system(size: 11))
                .foregroundColor(MainWindowPalette.tertiaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var syncModeChooser: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                ForEach(SyncMode.allCases, id: \.rawValue) { mode in
                    Button {
                        syncModeStore.setMode(mode)
                    } label: {
                        Text(mode.label)
                            .font(.system(size: 11.5, weight: syncModeStore.mode == mode ? .semibold : .regular))
                            .foregroundColor(syncModeStore.mode == mode ? MainWindowPalette.primaryText : MainWindowPalette.secondaryText)
                            .frame(maxWidth: .infinity)
                            .frame(height: 30)
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

            Text(syncModeStore.mode.detail)
                .font(.system(size: 11))
                .foregroundColor(MainWindowPalette.tertiaryText)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                syncModeStore.sendCurrentClipboard()
            } label: {
                HStack(spacing: 8) {
                    AirClipIcon(.clipboard, size: 13)
                    Text("Send current clipboard")
                        .font(.system(size: 12, weight: .medium))
                    Spacer()
                }
                .foregroundColor(
                    syncModeStore.mode.allowsManualSend
                        ? MainWindowPalette.primaryText
                        : MainWindowPalette.tertiaryText
                )
                .padding(.horizontal, 12)
                .frame(height: 34)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(MainWindowPalette.activeFill)
                )
            }
            .buttonStyle(.plain)
            .disabled(!syncModeStore.mode.allowsManualSend)
        }
    }

    private var privacyContent: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(MainWindowPalette.saved.opacity(0.10))
                AirClipIcon(.shield, size: 16)
                    .foregroundColor(MainWindowPalette.saved)
            }
            .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 2) {
                Text("End-to-end encrypted")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(MainWindowPalette.primaryText)
                Text("Clipboard data is encrypted before leaving your device.")
                    .font(.system(size: 11))
                    .foregroundColor(MainWindowPalette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Text("Always on")
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundColor(MainWindowPalette.saved)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule(style: .continuous).fill(MainWindowPalette.saved.opacity(0.12)))
        }
        .padding(.vertical, 2)
    }

    private var sensitiveProtectionContent: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Sensitive sync")
                        .font(.system(size: 12))
                        .foregroundColor(MainWindowPalette.primaryText)
                    Text(sensitiveProtection.masterAction == .allow ? "All sensitive clips are allowed by default." : "Category rules apply below.")
                        .font(.system(size: 11))
                        .foregroundColor(MainWindowPalette.tertiaryText)
                }
                Spacer()
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
            .frame(minHeight: 46)

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

            Text("Ask prevents automatic sync for matching clips. Explicit copy/send actions stay quiet.")
                .font(.system(size: 11))
                .foregroundColor(MainWindowPalette.tertiaryText)
                .padding(.horizontal, 14)
                .padding(.top, 8)
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
                        Spacer(minLength: 12)
                        if historyDepth == index {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .semibold))
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 10) {
                AirClipIcon(.clock, size: 14)
                    .foregroundColor(MainWindowPalette.secondaryText)
                Text("Keep history for")
                    .font(.system(size: 13))
                    .foregroundColor(MainWindowPalette.primaryText)
                Spacer(minLength: 12)
                Text(historyOptions[historyDepth])
                    .font(.system(size: 13))
                    .foregroundColor(MainWindowPalette.secondaryText)
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(MainWindowPalette.tertiaryText)
            }
            .padding(.horizontal, 14)
            .frame(height: 44)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isHistoryHovered || isHistoryPressed ? MainWindowPalette.hoverFill : .clear)
            )
            .scaleEffect(isHistoryPressed ? MainWindowMotion.rowPressScale : 1)
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: MainWindowMotion.hoverDuration)) {
                isHistoryHovered = hovering
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isHistoryPressed {
                        withAnimation(.easeOut(duration: MainWindowMotion.pressDuration)) {
                            isHistoryPressed = true
                        }
                    }
                }
                .onEnded { _ in
                    withAnimation(.easeOut(duration: MainWindowMotion.releaseDuration)) {
                        isHistoryPressed = false
                    }
                }
        )
    }

    private func updateHistoryDepth(_ value: Int) {
        historyDepth = value
        UserDefaults.standard.set(value, forKey: "historyDepth")
        if historyDays[value] > 0 {
            LocalHistoryStore.shared.pruneToRetention(days: historyDays[value])
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
                        .foregroundColor(MainWindowPalette.tertiaryText)
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
