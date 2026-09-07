import Foundation

@main
struct SyncModePolicyCheck {
    static func main() {
        precondition(SyncMode.auto.allowsAutomaticCapture)
        precondition(SyncMode.auto.allowsOutboundSync)
        precondition(SyncMode.auto.keepsLanServiceRunning)

        precondition(!SyncMode.manualOnly.allowsAutomaticCapture)
        precondition(SyncMode.manualOnly.allowsOutboundSync)
        precondition(SyncMode.manualOnly.keepsLanServiceRunning)

        precondition(!SyncMode.paused.allowsAutomaticCapture)
        precondition(!SyncMode.paused.allowsOutboundSync)
        precondition(!SyncMode.paused.keepsLanServiceRunning)

        precondition(SyncMode.fromStoredValue(nil) == .auto)
        precondition(SyncMode.fromStoredValue("") == .auto)
        precondition(SyncMode.fromStoredValue("legacy") == .auto)
        precondition(SyncMode.fromStoredValue("manualOnly") == .manualOnly)

        for mode in SyncMode.allCases {
            precondition(SyncMode.fromStoredValue(mode.rawValue) == mode)
        }
    }
}
