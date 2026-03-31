import SwiftUI
import SwiftData
import AppKit

struct PopoverView: View {
    @ObservedObject private var syncEngine = SyncEngine.shared
    @ObservedObject private var authManager = AuthManager.shared
    @Query(sort: \ClipboardItem.receivedAt, order: .reverse) private var items: [ClipboardItem]

    var body: some View {
        VStack(spacing: 0) {
            header
            HairlineDivider()
            historyList
            HairlineDivider()
            footer
        }
        .frame(width: 360, height: 480)
        .background(.ultraThinMaterial)
        .background(Color.bgBase.opacity(0.92))
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: Spacing.sm) {
            Text("Clipr+")
                .font(.cliprTitle2)
                .foregroundColor(.textPrimary)

            Spacer()

            ConnectionBadge(isConnected: syncEngine.isConnected)

            Rectangle()
                .fill(Color.borderDefault)
                .frame(width: 0.5, height: 14)
                .padding(.horizontal, 2)

            Button(action: openSettingsWindow) {
                Image(systemName: "gearshape")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.textSecondary)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(IconButtonStyle())
        }
        .padding(.horizontal, Layout.rowPaddingH)
        .frame(height: 48)
    }

    // MARK: - History List

    private var historyList: some View {
        Group {
            if items.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        let capped = Array(items.prefix(20))
                        ForEach(capped.indices, id: \.self) { idx in
                            ClipItemRow(item: capped[idx])
                            if idx < capped.count - 1 {
                                HairlineDivider(leadingPad: Layout.rowPaddingH)
                            }
                        }
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: "clipboard")
                .font(.system(size: 26, weight: .regular))
                .foregroundColor(.textTertiary)

            Text("No clips yet")
                .font(.cliprBody)
                .foregroundColor(.textSecondary)

            Text("Copy something to get started")
                .font(.cliprCaption)
                .foregroundColor(.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Button("Sign out") {
                Task { await authManager.signOut() }
            }
            .font(.cliprCaption)
            .foregroundColor(.textSecondary)
            .buttonStyle(.plain)

            Spacer()
        }
        .padding(.horizontal, Layout.rowPaddingH)
        .frame(height: Layout.actionBarHeight)
    }

    // MARK: - Actions

    private func openSettingsWindow() {
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 560),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        win.center()
        win.title = "Clipr+ — Settings"
        win.contentView = NSHostingView(rootView: SettingsView())
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

// MARK: - Clip Item Row

struct ClipItemRow: View {
    let item: ClipboardItem
    @State private var isHovered = false
    @State private var showCopied = false

    var body: some View {
        Button(action: copyToClipboard) {
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.text)
                        .font(.cliprMono)
                        .foregroundColor(.textPrimary)
                        .lineLimit(2)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: 5) {
                        if !item.isLocal {
                            Circle()
                                .fill(Color.syncBlue)
                                .frame(width: 4, height: 4)
                        }
                        Text(item.receivedAt, style: .relative)
                            .font(.cliprCaption)
                            .foregroundColor(.textTertiary)
                    }
                }
                .padding(.vertical, 10)

                Spacer(minLength: Spacing.xs)

                if isHovered || showCopied {
                    Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(showCopied ? Color.encryptedGreen : Color.textTertiary)
                        .frame(width: 16)
                        .transition(.opacity)
                        .animation(.cliprInstant(Duration.micro), value: showCopied)
                }
            }
            .padding(.horizontal, Layout.rowPaddingH)
            .frame(minHeight: Layout.rowHeight)
            .background(isHovered ? Color.hoverFill : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }

    private func copyToClipboard() {
        ClipboardMonitor.shared.suppressNextChange()
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(item.text, forType: .string)
        showCopied = true
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            showCopied = false
        }
    }
}

// MARK: - Connection Badge

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
                .onChange(of: isConnected) { startPulseIfNeeded() }

            Text(isConnected ? "Live" : "Offline")
                .font(.cliprCaption)
                .foregroundColor(.textSecondary)
        }
    }

    private func startPulseIfNeeded() {
        dotOpacity = 1.0
        guard isConnected else { return }
        withAnimation(.cliprPulse.repeatForever(autoreverses: true)) {
            dotOpacity = 0.35
        }
    }
}
