import SwiftUI
import SwiftData

struct ClipboardHistoryView: View {
    @EnvironmentObject private var syncEngine: SyncEngine
    @Query(sort: \ClipboardItem.receivedAt, order: .reverse) private var items: [ClipboardItem]

    @State private var isSending = false
    @State private var lastSentId: UUID?

    var body: some View {
        NavigationStack {
            Group {
                if items.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(items) { item in
                            ClipRowView(item: item, onCopy: { copyToPasteboard(item.text) })
                        }
                        .onDelete(perform: delete)
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Clipboard")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    connectionStatus
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        sendCurrentClipboard()
                    } label: {
                        if isSending {
                            ProgressView().scaleEffect(0.8)
                        } else {
                            Label("Send", systemImage: "arrow.up.circle")
                        }
                    }
                    .disabled(isSending || !syncEngine.isConnected)
                }
            }
        }
    }

    private var connectionStatus: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(syncEngine.isConnected ? Color(red: 0.35, green: 0.83, blue: 0.60) : Color.secondary)
                .frame(width: 8, height: 8)
            Text(syncEngine.isConnected ? "Connected" : "No peers")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 40, weight: .thin))
                .foregroundStyle(.tertiary)
            Text("Nothing synced yet")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Copy something on your Mac or tap Send to share from this device.")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }

    private func sendCurrentClipboard() {
        isSending = true
        syncEngine.sendCurrentClipboard()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { isSending = false }
    }

    private func copyToPasteboard(_ text: String) {
        UIPasteboard.general.string = text
    }

    private func delete(at offsets: IndexSet) {
        let ctx = LocalHistoryStore.shared.container.mainContext
        offsets.map { items[$0] }.forEach { ctx.delete($0) }
        try? ctx.save()
    }
}

// MARK: - Row

private struct ClipRowView: View {
    let item: ClipboardItem
    let onCopy: () -> Void

    @State private var copied = false

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: item.isLocal ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                .font(.system(size: 14))
                .foregroundStyle(item.isLocal ? Color.accentColor : Color(red: 0.35, green: 0.83, blue: 0.60))
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.text)
                    .font(.system(.callout, design: .monospaced))
                    .lineLimit(2)
                    .foregroundStyle(.primary)

                Text(item.receivedAt, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Button {
                onCopy()
                withAnimation { copied = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation { copied = false }
                }
            } label: {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 14))
                    .foregroundStyle(copied ? .green : .secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 2)
    }
}
