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

    func recoverRuntime() {
        guard AirClipIdentity.shared.isPaired else { return }
        if mode.allowsAutomaticCapture {
            ClipboardMonitor.shared.restart()
        }
        SyncEngine.shared.reconnect()
    }

}
