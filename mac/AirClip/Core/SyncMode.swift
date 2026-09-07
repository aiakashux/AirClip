import Foundation

enum SyncMode: String, CaseIterable {
    case auto
    case manualOnly
    case paused

    var allowsAutomaticCapture: Bool {
        self == .auto
    }

    var allowsOutboundSync: Bool {
        self != .paused
    }

    var keepsLanServiceRunning: Bool {
        self != .paused
    }

    var label: String {
        switch self {
        case .auto: return "Auto"
        case .manualOnly: return "Manual"
        case .paused: return "Paused"
        }
    }

    var detail: String {
        switch self {
        case .auto:
            return "New clips sync automatically with nearby paired devices."
        case .manualOnly:
            return "AirClip receives clips automatically; sending requires an explicit action."
        case .paused:
            return "AirClip stops watching the clipboard and disconnects nearby sync."
        }
    }

    static func fromStoredValue(_ value: String?) -> SyncMode {
        guard let value, let mode = SyncMode(rawValue: value) else {
            return .auto
        }
        return mode
    }
}
