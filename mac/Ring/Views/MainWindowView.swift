import SwiftUI
import SwiftData
import AppKit

// MARK: - Page

enum MainPage: Equatable {
    case clipboard, devices, settings
}

// MARK: - Main Window

struct MainWindowView: View {
    @State private var activePage: MainPage = .clipboard

    var body: some View {
        ZStack(alignment: .bottom) {
            // Window background
            Color(red: 14/255, green: 15/255, blue: 15/255).opacity(0.94)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                titlebar

                Group {
                    switch activePage {
                    case .clipboard: ClipboardPage()
                    case .devices:   DevicesPage()
                    case .settings:  SettingsPage()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            // Floating bottom nav
            BottomNavBar(activePage: $activePage)
                .padding(.bottom, 12)
        }
        .frame(width: 720, height: 620)
    }

    // MARK: Titlebar

    private var titlebar: some View {
        HStack {
            // App identity
            HStack(spacing: 8) {
                // Clipboard mark — two overlapping rounded rects (matches Figma)
                ZStack {
                    RoundedRectangle(cornerRadius: Radius.xs)
                        .stroke(Color.white.opacity(0.18), lineWidth: 1.5)
                        .frame(width: 13, height: 13)
                        .offset(x: 2.5, y: 2.5)
                    RoundedRectangle(cornerRadius: Radius.xs)
                        .fill(Color.white.opacity(0.14))
                        .overlay(
                            RoundedRectangle(cornerRadius: Radius.xs)
                                .stroke(Color.white.opacity(0.28), lineWidth: 1.5)
                        )
                        .frame(width: 13, height: 13)
                        .offset(x: -2.5, y: -2.5)
                }
                .frame(width: 18, height: 18)

                Text("Ring")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.38))
            }
            Spacer()
        }
        .padding(.horizontal, Spacing.md)
        .frame(height: 40)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.borderSubtle)
                .frame(height: 0.5)
        }
    }
}

// MARK: - Bottom Nav Bar

private struct BottomNavBar: View {
    @Binding var activePage: MainPage

    var body: some View {
        HStack(spacing: 12) {
            navBtn(.clipboard, symbol: "doc.on.clipboard")
            navBtn(.devices,   symbol: "laptopcomputer.and.iphone")
            navBtn(.settings,  symbol: "gearshape")
        }
        .padding(10)
        .frame(height: 48)
        .background(
            Capsule()
                .fill(Color(red: 53/255, green: 55/255, blue: 53/255).opacity(0.60))
                .overlay(Capsule().strokeBorder(Color(white: 0.27), lineWidth: 0.5))
        )
        .animation(.spring(response: 0.25, dampingFraction: 0.80), value: activePage)
    }

    @ViewBuilder
    private func navBtn(_ page: MainPage, symbol: String) -> some View {
        let active = activePage == page
        Button { activePage = page } label: {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(.white.opacity(active ? 0.88 : 0.45))
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 32)
                        .fill(active ? Color.white.opacity(0.20) : Color.clear)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Clipboard Page

private struct ClipboardPage: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ClipboardItem.receivedAt, order: .reverse) private var allItems: [ClipboardItem]
    @State private var selectedItem: ClipboardItem?
    @State private var searchQuery = ""

    private var filtered: [ClipboardItem] {
        guard !searchQuery.isEmpty else { return Array(allItems) }
        return allItems.filter { $0.text.localizedCaseInsensitiveContains(searchQuery) }
    }

    private var todayItems: [ClipboardItem] {
        filtered.filter { Calendar.current.isDateInToday($0.receivedAt) }
    }
    private var earlierItems: [ClipboardItem] {
        filtered.filter { !Calendar.current.isDateInToday($0.receivedAt) }
    }

    var body: some View {
        HStack(spacing: 0) {
            listPane.frame(width: 248)
            previewPane
                .padding(.top, 8)
                .padding(.trailing, 16)
                .padding(.bottom, 8)
        }
        .onAppear { if selectedItem == nil { selectedItem = allItems.first } }
        .onChange(of: allItems) { _, items in
            if selectedItem == nil || !items.contains(where: { $0.id == selectedItem?.id }) {
                selectedItem = items.first
            }
        }
    }

    // MARK: List pane

    private var listPane: some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: 0, pinnedViews: []) {
                searchBar
                    .padding(.top, 8)
                    .padding(.bottom, 4)
                    .padding(.trailing, 8)

                if filtered.isEmpty {
                    emptyList
                } else {
                    if !todayItems.isEmpty {
                        sectionHeader("Today")
                        ForEach(todayItems) { clipRow($0) }
                    }
                    if !earlierItems.isEmpty {
                        sectionHeader("Earlier")
                        ForEach(earlierItems) { clipRow($0) }
                    }
                }
            }
            .padding(.leading, Spacing.md)
            .padding(.bottom, 72)   // clear bottom nav
        }
        .scrollIndicators(.never)
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(searchQuery.isEmpty ? 0.45 : 0.65))
                .scaleEffect(x: -1)  // mirror to face right

            TextField("Search", text: $searchQuery)
                .font(.system(size: 12))
                .foregroundColor(searchQuery.isEmpty ? .textSecondary : .white)
                .textFieldStyle(.plain)

            if !searchQuery.isEmpty {
                Button { searchQuery = "" } label: {
                    ZStack {
                        Circle().fill(Color.white.opacity(0.14)).frame(width: 14, height: 14)
                        Text("×").font(.system(size: 8)).foregroundColor(.white.opacity(0.70))
                    }
                }
                .buttonStyle(.plain)
                .transition(.opacity.combined(with: .scale(scale: 0.80)))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: Radius.xl)
                .fill(Color.white.opacity(0.07))
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.xl)
                        .strokeBorder(searchQuery.isEmpty ? Color.clear : Color.borderFocus, lineWidth: 1)
                )
        )
        .animation(.spring(response: 0.22, dampingFraction: 0.82), value: searchQuery.isEmpty)
    }

    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Color(white: 0.44))
                .kerning(0.11)
            Spacer()
        }
        .frame(height: 28)
        .padding(.horizontal, 8)
        .padding(.trailing, 8)
    }

    private func deleteItem(_ item: ClipboardItem) {
        if selectedItem?.id == item.id {
            let remaining = allItems.filter { $0.id != item.id }
            selectedItem = remaining.first
        }
        modelContext.delete(item)
    }

    @ViewBuilder
    private func clipRow(_ item: ClipboardItem) -> some View {
        let sel = selectedItem?.id == item.id
        let type = ClipType.detect(item.text)

        HStack(spacing: 10) {
            typeIcon(type)

            Text(item.text)
                .font(type == .code ? .ringMono : .ringBody)
                .foregroundColor(.white.opacity(0.85))
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: 0)

            if !item.isLocal {
                Circle().fill(Color.syncBlue).frame(width: 4, height: 4)
            }
        }
        .padding(.horizontal, 10)
        .frame(height: Layout.rowHeight)
        .background(
            RoundedRectangle(cornerRadius: Radius.md)
                .fill(sel ? Color.white.opacity(0.10) : Color.clear)
        )
        .padding(.trailing, 8)
        .contentShape(Rectangle())
        .onTapGesture { withAnimation(.spring(response: 0.18, dampingFraction: 0.85)) { selectedItem = item } }
        .contextMenu {
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(item.text, forType: .string)
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }
            Divider()
            Button(role: .destructive) {
                deleteItem(item)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func typeIcon(_ type: ClipType) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: Radius.sm)
                .fill(typeIconBg(type))
                .frame(width: 28, height: 28)
            Image(systemName: typeIconSymbol(type))
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(typeIconFg(type))
        }
    }

    private func typeIconBg(_ t: ClipType) -> Color {
        switch t {
        case .url:   return Color.syncBlue.opacity(0.14)
        case .code:  return Color.encryptedGreen.opacity(0.14)
        case .color: return Color.accent.opacity(0.14)
        case .text:  return Color.white.opacity(0.12)
        }
    }
    private func typeIconSymbol(_ t: ClipType) -> String {
        switch t {
        case .url:   return "link"
        case .code:  return "chevron.left.forwardslash.chevron.right"
        case .color: return "paintpalette"
        case .text:  return "doc.text"
        }
    }
    private func typeIconFg(_ t: ClipType) -> Color {
        switch t {
        case .url:   return Color.syncBlue
        case .code:  return Color.encryptedGreen
        case .color: return Color.accent
        case .text:  return Color.white.opacity(0.45)
        }
    }

    private var emptyList: some View {
        Text(searchQuery.isEmpty ? "Nothing copied yet" : "No results")
            .font(.ringBody)
            .foregroundColor(.textTertiary)
            .frame(maxWidth: .infinity)
            .padding(.top, Spacing.xxl)
    }

    // MARK: Preview pane

    @ViewBuilder
    private var previewPane: some View {
        if let item = selectedItem {
            ClipPreviewPane(item: item, onDelete: { deleteItem(item) })
        } else {
            RoundedRectangle(cornerRadius: Radius.lg)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    Text("Select a clip to preview")
                        .font(.ringCaption)
                        .foregroundColor(.textTertiary)
                )
        }
    }
}

// MARK: - Clip Preview Pane

private struct ClipPreviewPane: View {
    let item: ClipboardItem
    let onDelete: () -> Void

    private var type: ClipType { ClipType.detect(item.text) }

    var body: some View {
        RoundedRectangle(cornerRadius: Radius.lg)
            .fill(Color.white.opacity(0.04))
            .overlay(
                VStack(spacing: 0) {
                    // Content area
                    ScrollView {
                        previewContent
                            .padding(Spacing.md)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .scrollIndicators(.never)

                    // Info panel
                    infoPanel
                }
                .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
            )
    }

    @ViewBuilder
    private var previewContent: some View {
        switch type {
        case .url:
            Text(item.text)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color.syncBlue)
                .underline()
                .lineSpacing(4)
                .frame(maxWidth: .infinity, alignment: .leading)

        case .code:
            Text(item.text)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(Color.white.opacity(0.50))
                .lineSpacing(6)
                .frame(maxWidth: .infinity, alignment: .leading)

        case .color:
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.text)
                        .font(.system(size: 22, design: .monospaced))
                        .foregroundColor(.white.opacity(0.88))
                    if let parsed = parseColor(item.text) {
                        Text(rgbString(parsed))
                            .font(.ringMono)
                            .foregroundColor(.textSecondary)
                    }
                }
                Spacer()
                RoundedRectangle(cornerRadius: 10)
                    .fill(parseColor(item.text) ?? Color.accent)
                    .frame(width: 44, height: 44)
                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.white.opacity(0.12), lineWidth: 1))
            }
            .padding(.vertical, 4)

        case .text:
            Text(item.text)
                .font(.system(size: 14))
                .foregroundColor(Color.white.opacity(0.50))
                .lineSpacing(5)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var infoPanel: some View {
        VStack(spacing: 0) {
            Rectangle().fill(Color.white.opacity(0.16)).frame(height: 0.5)

            VStack(spacing: 0) {
                Text("INFO")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color(white: 0.44))
                    .kerning(0.11)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 10)

                infoRow("Source",  value: item.isLocal ? "This Mac" : "Remote device")
                infoRow("Time",    value: item.receivedAt.formatted(.dateTime.month().day().hour().minute()))
                infoRow("Type",    value: typeName)
                infoRow("Length",  value: "\(item.text.count) chars")

                HStack {
                    Spacer()
                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "trash")
                                .font(.system(size: 11))
                            Text("Delete")
                                .font(.ringCaption)
                        }
                        .foregroundColor(Color.destructiveRed)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: Radius.sm)
                                .fill(Color.destructiveRed.opacity(0.10))
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 10)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.md)
            .padding(.bottom, 60)  // clear nav
        }
    }

    private func infoRow(_ key: String, value: String) -> some View {
        HStack {
            Text(key)
                .font(.ringCaption)
                .foregroundColor(Color(white: 0.44))
            Spacer()
            Text(value)
                .font(.ringCaption)
                .foregroundColor(.white.opacity(0.72))
        }
        .frame(minHeight: 28)
        .overlay(alignment: .top) {
            Rectangle().fill(Color.white.opacity(0.16)).frame(height: 0.5)
        }
    }

    private var typeName: String {
        switch type {
        case .url:   return "URL"
        case .code:  return "Code"
        case .color: return "Color"
        case .text:  return "Text"
        }
    }

    private func parseColor(_ hex: String) -> Color? {
        var h = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        guard h.hasPrefix("#") else { return nil }
        h = String(h.dropFirst())
        if h.count == 3 { h = h.map { "\($0)\($0)" }.joined() }
        guard h.count == 6 else { return nil }
        var rgb: UInt64 = 0
        guard Scanner(string: h).scanHexInt64(&rgb) else { return nil }
        return Color(
            red:   Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8)  & 0xFF) / 255,
            blue:  Double( rgb        & 0xFF) / 255
        )
    }

    private func rgbString(_ c: Color) -> String {
        guard let resolved = NSColor(c).usingColorSpace(.sRGB) else { return "" }
        let r = Int(resolved.redComponent * 255)
        let g = Int(resolved.greenComponent * 255)
        let b = Int(resolved.blueComponent * 255)
        return "rgb(\(r), \(g), \(b))"
    }
}

// MARK: - Devices Page

private struct DevicesPage: View {
    @State private var devices: [DeviceInfo] = []
    @State private var isLoading = false

    private let cols = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                // Connected devices grid
                VStack(alignment: .leading, spacing: 8) {
                    sectionLabel("Connected devices")

                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Spacing.xl)
                    } else if devices.isEmpty {
                        emptyDevices
                    } else {
                        LazyVGrid(columns: cols, spacing: 10) {
                            ForEach(Array(devices.enumerated()), id: \.element.id) { idx, device in
                                DeviceCard(device: device, isThisDevice: idx == 0)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.top, 18)
            .padding(.bottom, 80)
        }
        .scrollIndicators(.never)
        .task { await loadDevices() }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(.white.opacity(0.28))
            .kerning(0.6)
    }

    private var emptyDevices: some View {
        RoundedRectangle(cornerRadius: Radius.lg)
            .fill(Color.white.opacity(0.05))
            .overlay(
                Text("No other devices connected")
                    .font(.ringBody)
                    .foregroundColor(.textTertiary)
            )
            .frame(height: 80)
            .overlay(
                RoundedRectangle(cornerRadius: Radius.lg)
                    .strokeBorder(Color.white.opacity(0.09), lineWidth: 0.5)
            )
    }

    private func loadDevices() async {
        isLoading = true
        devices = (try? await APIClient.shared.listDevices()) ?? []
        isLoading = false
    }
}

private struct DeviceCard: View {
    let device: DeviceInfo
    let isThisDevice: Bool
    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Top row: icon + status pill
            HStack(alignment: .top) {
                // Device icon
                ZStack {
                    RoundedRectangle(cornerRadius: Radius.md)
                        .fill(Color.white.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: Radius.md)
                                .strokeBorder(Color.white.opacity(0.10), lineWidth: 0.5)
                        )
                    Image(systemName: "laptopcomputer")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(.white.opacity(0.55))
                }
                .frame(width: 38, height: 38)

                Spacer()

                // Live pill
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.encryptedGreen)
                        .frame(width: 6, height: 6)
                    Text("Live")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color.encryptedGreen)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(Color.encryptedGreen.opacity(0.15))
                )
            }
            .padding(.bottom, 12)

            // Name + badge
            HStack(alignment: .center, spacing: 6) {
                Text(device.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.92))
                    .lineLimit(1)

                if isThisDevice {
                    Text("This device")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.38))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: Radius.sm)
                                .fill(Color.white.opacity(0.10))
                                .overlay(
                                    RoundedRectangle(cornerRadius: Radius.sm)
                                        .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5)
                                )
                        )
                }
            }

            // Footer
            HStack {
                Text("Just now")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.28))
                Spacer()
            }
            .padding(.top, 8)
            .overlay(alignment: .top) {
                Rectangle().fill(Color.white.opacity(0.06)).frame(height: 0.5)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: Radius.lg)
                .fill(isHovered ? Color.white.opacity(0.07) : Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.lg)
                        .strokeBorder(Color.white.opacity(0.09), lineWidth: 0.5)
                )
        )
        .animation(.spring(response: 0.20, dampingFraction: 0.82), value: isHovered)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Settings Page

private struct SettingsPage: View {
    @ObservedObject private var authManager = AuthManager.shared
    @State private var activeTab: SettingsTab = .account

    enum SettingsTab: String, CaseIterable {
        case account  = "Account"
        case clipboard = "Clipboard"
        case devices  = "Devices"
        case shortcuts = "Shortcuts"
        case about    = "About"
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Rectangle().fill(Color.white.opacity(0.06)).frame(width: 0.5)
            settingsContent
        }
    }

    // MARK: Sidebar

    private var sidebar: some View {
        VStack(spacing: 0) {
            // Sidebar header
            HStack {
                Text("Settings")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.textSecondary)
            }
            .frame(height: 48)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Color.borderSubtle).frame(height: 0.5)
            }

            // Nav items
            ScrollView {
                VStack(spacing: 2) {
                    ForEach(SettingsTab.allCases, id: \.self) { tab in
                        sidebarItem(tab)
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 8)
            }
            .scrollIndicators(.never)
        }
        .frame(width: 160)
        .background(Color.black.opacity(0.15))
    }

    private func sidebarItem(_ tab: SettingsTab) -> some View {
        let active = activeTab == tab
        return Button { withAnimation(.spring(response: 0.22, dampingFraction: 0.82)) { activeTab = tab } } label: {
            HStack(spacing: 8) {
                Image(systemName: sidebarIcon(tab))
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.white.opacity(active ? 0.80 : 0.38))
                    .frame(width: 16)
                Text(tab.rawValue)
                    .font(.system(size: 12, weight: active ? .medium : .regular))
                    .foregroundColor(.white.opacity(active ? 0.85 : 0.42))
                Spacer()
            }
            .padding(.horizontal, 8)
            .frame(height: 32)
            .background(
                RoundedRectangle(cornerRadius: Radius.md)
                    .fill(active ? Color.white.opacity(0.09) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }

    private func sidebarIcon(_ tab: SettingsTab) -> String {
        switch tab {
        case .account:   return "person.circle"
        case .clipboard: return "doc.on.clipboard"
        case .devices:   return "laptopcomputer.and.iphone"
        case .shortcuts: return "command"
        case .about:     return "info.circle"
        }
    }

    // MARK: Content

    @ViewBuilder
    private var settingsContent: some View {
        VStack(spacing: 0) {
            // Page header
            HStack {
                Text(activeTab.rawValue)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.88))
                Spacer()
            }
            .frame(height: 48)
            .padding(.horizontal, Spacing.md)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Color.white.opacity(0.07)).frame(height: 0.5)
            }

            ScrollView {
                VStack(spacing: 12) {
                    switch activeTab {
                    case .account:   accountTab
                    case .clipboard: clipboardTab
                    case .devices:   devicesTab
                    case .shortcuts: shortcutsTab
                    case .about:     aboutTab
                    }
                }
                .padding(.horizontal, Spacing.md)
                .padding(.top, 14)
                .padding(.bottom, 80)
            }
            .scrollIndicators(.never)
        }
    }

    // MARK: Account tab

    private var accountTab: some View {
        VStack(spacing: 12) {
            // Profile card
            settingsCard {
                HStack(spacing: 12) {
                    // Avatar
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "#789BFA").opacity(0.55), Color.encryptedGreen.opacity(0.35)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                )
                            )
                            .overlay(Circle().strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5))
                        Text(avatarInitial)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white.opacity(0.90))
                    }
                    .frame(width: 36, height: 36)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(authManager.accountEmail ?? "—")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white.opacity(0.88))
                            // Plan badge
                            Text("Free")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(Color(hex: "#789BFA"))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    RoundedRectangle(cornerRadius: Radius.xs)
                                        .fill(Color(hex: "#789BFA").opacity(0.15))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: Radius.xs)
                                                .strokeBorder(Color(hex: "#789BFA").opacity(0.25), lineWidth: 0.5)
                                        )
                                )
                        }
                        Text("Ring account")
                            .font(.ringCaption)
                            .foregroundColor(.textSecondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 14)
                .frame(minHeight: 56)
            }

            // Sign out
            settingsCard {
                Button {
                    Task { await authManager.signOut() }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.system(size: 12))
                        Text("Sign out")
                            .font(.ringBody)
                    }
                    .foregroundColor(Color.destructiveRed)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .frame(height: 40)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var avatarInitial: String {
        (authManager.accountEmail?.first.map(String.init) ?? "?").uppercased()
    }

    // MARK: Clipboard tab

    @State private var autoSync = true
    @State private var historyDepth = 1   // 0=7d 1=30d 2=90d
    @State private var encryptionOn = true

    private var clipboardTab: some View {
        VStack(spacing: 12) {
            sectionLabel("Sync")
            settingsCard {
                toggleRow("Auto-sync", isOn: $autoSync)
                HairlineDivider(leadingPad: 14)
                toggleRow("End-to-end encryption", isOn: $encryptionOn)
            }

            sectionLabel("History")
            settingsCard {
                VStack(spacing: 0) {
                    HStack {
                        Text("Keep history for")
                            .font(.ringBody)
                            .foregroundColor(.textPrimary)
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 40)

                    HairlineDivider()

                    HStack(spacing: 0) {
                        ForEach(["7 days", "30 days", "90 days"].indices, id: \.self) { i in
                            Button { withAnimation { historyDepth = i } } label: {
                                Text(["7 days", "30 days", "90 days"][i])
                                    .font(historyDepth == i ? .ringCaptionMed : .ringCaption)
                                    .foregroundColor(historyDepth == i ? .textPrimary : .textSecondary)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 28)
                                    .background(
                                        RoundedRectangle(cornerRadius: Radius.sm)
                                            .fill(historyDepth == i ? Color.white.opacity(0.10) : Color.clear)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(Spacing.xxs)
                    .background(
                        RoundedRectangle(cornerRadius: Radius.md)
                            .fill(Color.white.opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: Radius.md)
                                    .strokeBorder(Color.borderSubtle, lineWidth: 0.5)
                            )
                    )
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .animation(.spring(response: 0.20, dampingFraction: 0.82), value: historyDepth)
                }
            }

            sectionLabel("Data")
            settingsCard {
                Button { LocalHistoryStore.shared.clearAll() } label: {
                    Text("Clear local history")
                        .font(.ringBody)
                        .foregroundColor(Color.destructiveRed)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 14)
                        .frame(height: 40)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: Devices tab

    @State private var settingsDevices: [DeviceInfo] = []

    private var devicesTab: some View {
        VStack(spacing: 12) {
            sectionLabel("Connected devices")
            settingsCard {
                if settingsDevices.isEmpty {
                    Text("No other devices")
                        .font(.ringBody)
                        .foregroundColor(.textTertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 14)
                        .frame(height: 40)
                } else {
                    ForEach(Array(settingsDevices.enumerated()), id: \.element.id) { idx, device in
                        HStack(spacing: 12) {
                            Circle().fill(Color.encryptedGreen).frame(width: 6, height: 6)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(device.name).font(.ringBody).foregroundColor(.textPrimary)
                                Text("Trusted").font(.ringCaption).foregroundColor(Color.encryptedGreen)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 14)
                        .frame(minHeight: 44)
                        if idx < settingsDevices.count - 1 { HairlineDivider(leadingPad: 14) }
                    }
                }
            }
        }
        .task { settingsDevices = (try? await APIClient.shared.listDevices()) ?? [] }
    }

    // MARK: Shortcuts tab

    private var shortcutsTab: some View {
        settingsCard {
            shortcutRow("Open Ring", keys: ["⌘", "⇧", "V"])
            HairlineDivider(leadingPad: 14)
            shortcutRow("Paste last item", keys: ["⌘", "⇧", "P"])
        }
    }

    private func shortcutRow(_ label: String, keys: [String]) -> some View {
        HStack {
            Text(label).font(.ringBody).foregroundColor(.textPrimary)
            Spacer()
            HStack(spacing: 4) {
                ForEach(keys, id: \.self) { key in
                    Text(key)
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.60))
                        .frame(minWidth: 20, minHeight: 20)
                        .padding(.horizontal, 4)
                        .background(
                            RoundedRectangle(cornerRadius: Radius.xs)
                                .fill(Color.white.opacity(0.08))
                                .overlay(
                                    RoundedRectangle(cornerRadius: Radius.xs)
                                        .strokeBorder(Color.white.opacity(0.14), lineWidth: 0.5)
                                )
                        )
                }
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 40)
    }

    // MARK: About tab

    private var aboutTab: some View {
        VStack(spacing: 12) {
            // Developer card
            settingsCard {
                VStack(spacing: 0) {
                    HStack(spacing: 12) {
                        Circle()
                            .fill(Color.white.opacity(0.08))
                            .frame(width: 56, height: 56)
                            .overlay(Circle().strokeBorder(Color.white.opacity(0.16), lineWidth: 1.5))

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Akash")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white.opacity(0.92))
                            Text("Designer & Developer")
                                .font(.ringCaption)
                                .foregroundColor(.textSecondary)
                        }
                        Spacer()
                    }
                    .padding(Spacing.md)

                    HairlineDivider()

                    HStack(spacing: 8) {
                        socialPill(label: "@Akash_UX",  icon: "at")
                        socialPill(label: "akashux.com", icon: "safari")
                    }
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, 12)
                }
            }

            // App info
            settingsCard {
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: Radius.md)
                            .fill(Color.accent.opacity(0.12))
                            .overlay(
                                RoundedRectangle(cornerRadius: Radius.md)
                                    .strokeBorder(Color.accent.opacity(0.22), lineWidth: 0.5)
                            )
                        Image(systemName: "doc.on.clipboard")
                            .foregroundColor(Color.accent)
                    }
                    .frame(width: 36, height: 36)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Ring")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white.opacity(0.88))
                        Text("Version 1.0.0")
                            .font(.ringCaption)
                            .foregroundColor(.white.opacity(0.38))
                    }
                    Spacer()
                }
                .padding(.horizontal, 14)
                .frame(height: 56)
            }
        }
    }

    private func socialPill(label: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.45))
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.72))
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: Radius.md)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.md)
                        .strokeBorder(Color.borderDefault, lineWidth: 0.5)
                )
        )
        .frame(maxWidth: .infinity)
    }

    // MARK: Shared helpers

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.ringCaptionMed)
            .foregroundColor(.textTertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 2)
    }

    private func settingsCard<C: View>(@ViewBuilder content: () -> C) -> some View {
        VStack(spacing: 0) { content() }
            .background(
                RoundedRectangle(cornerRadius: Radius.md + 2)
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.md + 2)
                            .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: Radius.md + 2))
    }

    private func toggleRow(_ label: String, isOn: Binding<Bool>) -> some View {
        HStack {
            Text(label).font(.ringBody).foregroundColor(.textPrimary)
            Spacer()
            Toggle("", isOn: isOn).labelsHidden().toggleStyle(.switch).tint(Color.syncBlue)
        }
        .padding(.horizontal, 14)
        .frame(height: 40)
    }
}
