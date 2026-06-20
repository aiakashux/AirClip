import AppKit
import Foundation

@MainActor
final class SyncModeStore: ObservableObject {
    static let shared = SyncModeStore()

    private static let defaultsKey = "syncMode"
    private let defaults: UserDefaults

    @Published private(set) var mode: SyncMode

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        mode = SyncMode.fromStoredValue(defaults.string(forKey: Self.defaultsKey))
    }

    func setMode(_ mode: SyncMode) {
        guard self.mode != mode else { return }
        self.mode = mode
        defaults.set(mode.rawValue, forKey: Self.defaultsKey)
        applyRuntimePolicy()
    }

    func applyRuntimePolicy() {
        guard AirClipIdentity.shared.isPaired else {
            ClipboardMonitor.shared.stop()
            SyncEngine.shared.disconnect()
            return
        }

        if mode.allowsAutomaticCapture {
            ClipboardMonitor.shared.start()
        } else {
            ClipboardMonitor.shared.stop()
        }

        if mode.keepsLanServiceRunning {
            SyncEngine.shared.connect()
        } else {
            SyncEngine.shared.disconnect()
        }
    }

    @discardableResult
    func sendCurrentClipboard() -> Bool {
        guard mode.allowsManualSend,
              AirClipIdentity.shared.isPaired,
              let packet = ClipboardCapture.readCurrentPacket(from: NSPasteboard.general)
        else {
            return false
        }

        switch SensitiveClipboardProtectionStore.shared.requestManualSend(packet) {
        case .allow:
            SyncEngine.shared.sendClipboard(packet: packet)
        case .requireConfirmation:
            break
        case .block:
            return false
        }
        return true
    }
}
