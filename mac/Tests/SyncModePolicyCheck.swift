import Foundation

@main
struct SyncModePolicyCheck {
    static func main() {
        precondition(SyncMode.auto.allowsAutomaticCapture)
        precondition(SyncMode.auto.allowsManualSend)
        precondition(SyncMode.auto.keepsLanServiceRunning)

        precondition(!SyncMode.manualOnly.allowsAutomaticCapture)
        precondition(SyncMode.manualOnly.allowsManualSend)
        precondition(SyncMode.manualOnly.keepsLanServiceRunning)

        precondition(!SyncMode.paused.allowsAutomaticCapture)
        precondition(!SyncMode.paused.allowsManualSend)
        precondition(!SyncMode.paused.keepsLanServiceRunning)

        precondition(SyncMode.fromStoredValue(nil) == .manualOnly)
        precondition(SyncMode.fromStoredValue("") == .manualOnly)
        precondition(SyncMode.fromStoredValue("legacy") == .manualOnly)

        for mode in SyncMode.allCases {
            precondition(SyncMode.fromStoredValue(mode.rawValue) == mode)
        }
    }
}
