import Foundation

enum SyncMode: String, CaseIterable {
    case auto
    case manualOnly
    case paused

    var allowsAutomaticCapture: Bool {
        self == .auto
    }

    var allowsManualSend: Bool {
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
            return "New clipboard changes sync automatically."
        case .manualOnly:
            return "Only clips you explicitly send are synced."
        case .paused:
            return "Clipboard monitoring and nearby sync are stopped."
        }
    }

    static func fromStoredValue(_ value: String?) -> SyncMode {
        guard let value, let mode = SyncMode(rawValue: value) else {
            return .manualOnly
        }
        return mode
    }
}
