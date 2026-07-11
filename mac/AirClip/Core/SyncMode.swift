import Foundation

enum SyncMode: String, CaseIterable {
    case auto
    case paused

    var allowsAutomaticCapture: Bool {
        self == .auto
    }

    var allowsOutboundSync: Bool {
        self == .auto
    }

    var keepsLanServiceRunning: Bool {
        self != .paused
    }

    var label: String {
        switch self {
        case .auto: return "Auto"
        case .paused: return "Paused"
        }
    }

    var detail: String {
        switch self {
        case .auto:
            return "New clips sync automatically with nearby paired devices."
        case .paused:
            return "AirClip stops watching the clipboard and disconnects nearby sync."
        }
    }

    static func fromStoredValue(_ value: String?) -> SyncMode {
        if value == "manualOnly" {
            return .auto
        }
        guard let value, let mode = SyncMode(rawValue: value) else {
            return .auto
        }
        return mode
    }
}
