import Foundation

/// App Group SharedPreferences bridge between the main app and the WidgetKit extension.
///
/// Both the main app and the widget read/write through `UserDefaults(suiteName: AppConfig.appGroupID)`.
/// The main app calls `WidgetCenter.shared.reloadAllTimelines()` after saving to push the update.
enum WidgetSyncState: String {
    case noDevices   = "no_devices"
    case synced      = "synced"
    case pending     = "pending"
    case readyToSend = "ready_to_send"
}

enum WidgetSharedState {

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: AppConfig.appGroupID)
    }

    // Keys
    private static let keyState    = "widget_state"
    private static let keyPreview  = "widget_preview"
    private static let keyLastText = "widget_last_text"
    private static let keySyncMs   = "widget_last_sync_ms"

    // MARK: - Write

    static func save(
        state:    WidgetSyncState,
        preview:  String? = nil,
        lastText: String? = nil
    ) {
        let d = defaults
        d?.set(state.rawValue, forKey: keyState)
        if let preview  { d?.set(preview,                forKey: keyPreview) }
        if let lastText { d?.set(String(lastText.prefix(1_000)), forKey: keyLastText) }
        if state == .synced { d?.set(Date().timeIntervalSince1970 * 1_000, forKey: keySyncMs) }
    }

    static func clear() {
        let d = defaults
        d?.removeObject(forKey: keyState)
        d?.removeObject(forKey: keyPreview)
        d?.removeObject(forKey: keyLastText)
        d?.removeObject(forKey: keySyncMs)
    }

    // MARK: - Read

    static var state: WidgetSyncState {
        guard let raw = defaults?.string(forKey: keyState) else { return .noDevices }
        return WidgetSyncState(rawValue: raw) ?? .noDevices
    }

    static var preview: String { defaults?.string(forKey: keyPreview) ?? "" }

    static var lastText: String { defaults?.string(forKey: keyLastText) ?? "" }

    static var lastSyncMs: Double { defaults?.double(forKey: keySyncMs) ?? 0 }

    // MARK: - Human-readable elapsed time

    static func elapsedLabel(syncMs: Double) -> String {
        guard syncMs > 0 else { return "" }
        let diff = Date().timeIntervalSince1970 * 1_000 - syncMs
        switch diff {
        case ..<60_000:     return "just now"
        case ..<3_600_000:  return "\(Int(diff / 60_000)) min ago"
        case ..<86_400_000: return "\(Int(diff / 3_600_000)) hr ago"
        default:            return "earlier"
        }
    }
}
