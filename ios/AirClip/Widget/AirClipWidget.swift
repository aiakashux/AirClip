import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Timeline entry

struct AirClipWidgetEntry: TimelineEntry {
    let date:       Date
    let state:      WidgetSyncState
    let preview:    String
    let syncMs:     Double
}

// MARK: - Timeline provider

struct AirClipWidgetProvider: TimelineProvider {

    func placeholder(in context: Context) -> AirClipWidgetEntry {
        AirClipWidgetEntry(date: Date(), state: .synced, preview: "", syncMs: 0)
    }

    func getSnapshot(in context: Context, completion: @escaping (AirClipWidgetEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<AirClipWidgetEntry>) -> Void) {
        let entry    = currentEntry()
        // Refresh in 5 minutes to update elapsed timestamps; earlier refresh triggered by app via WidgetCenter.
        let nextDate = Calendar.current.date(byAdding: .minute, value: 5, to: Date()) ?? Date()
        completion(Timeline(entries: [entry], policy: .after(nextDate)))
    }

    private func currentEntry() -> AirClipWidgetEntry {
        AirClipWidgetEntry(
            date:    Date(),
            state:   WidgetSharedState.state,
            preview: WidgetSharedState.preview,
            syncMs:  WidgetSharedState.lastSyncMs
        )
    }
}

// MARK: - Widget view

struct AirClipWidgetEntryView: View {
    var entry: AirClipWidgetProvider.Entry

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(dotColor)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(primaryText)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)
                if !secondaryText.isEmpty {
                    Text(secondaryText)
                        .font(.system(size: 11))
                        .foregroundColor(Color.white.opacity(0.55))
                        .lineLimit(1)
                }
            }

            Spacer()

            actionButton
        }
        .padding(.horizontal, 14)
        .containerBackground(for: .widget) {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(white: 0.11))
        }
    }

    // MARK: - State-driven content

    private var dotColor: Color {
        switch entry.state {
        case .noDevices:   return Color(white: 0.52)
        case .synced:      return Color(red: 0.35, green: 0.83, blue: 0.60)
        case .pending:     return Color(red: 0.34, green: 0.76, blue: 1.00)
        case .readyToSend: return Color(red: 1.00, green: 0.39, blue: 0.39)
        }
    }

    private var primaryText: String {
        switch entry.state {
        case .noDevices:   return "No devices nearby"
        case .synced:      return "AirClip in sync"
        case .pending:     return "New from Mac"
        case .readyToSend: return "Ready to sync"
        }
    }

    private var secondaryText: String {
        switch entry.state {
        case .noDevices:   return "Same WiFi needed"
        case .synced:      return WidgetSharedState.elapsedLabel(syncMs: entry.syncMs)
        case .pending:     return entry.preview.isEmpty ? "" : "\"\(entry.preview)\""
        case .readyToSend: return ""
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        switch entry.state {
        case .pending:
            Button(intent: PasteClipIntent()) {
                Text("Paste")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color(white: 0.20))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        case .readyToSend:
            Button(intent: SendClipIntent()) {
                Text("Send")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color(red: 1.00, green: 0.39, blue: 0.39).opacity(0.85))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        default:
            EmptyView()
        }
    }
}

// MARK: - Widget declaration

struct AirClipWidget: Widget {
    let kind: String = "AirClipWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: AirClipWidgetProvider()) { entry in
            AirClipWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("AirClip")
        .description("Clipboard sync status and quick actions.")
        .supportedFamilies([.systemMedium])
    }
}
