import Foundation
import AppKit

// MARK: - PairedDevice

struct PairedDevice: Codable, Identifiable, Hashable {
    var id: String { deviceId }
    let deviceId: String
    let deviceName: String
    let publicKey: String
    var deviceModel: String? = nil
    var platform: String = ""
    var lastSeenMs: Int64 = 0
    var wifiNetwork: String? = nil

    func hash(into hasher: inout Hasher) { hasher.combine(deviceId) }
    static func == (l: PairedDevice, r: PairedDevice) -> Bool { l.deviceId == r.deviceId }
}

// MARK: - AirClipIdentity

/// Self-sovereign identity store — no server account needed.
/// Replaces AuthManager's server-backed auth with a local airclip_id shared across
/// paired devices. All state persists to UserDefaults.
@MainActor
final class AirClipIdentity: ObservableObject {
    static let shared = AirClipIdentity()

    @Published private(set) var airClipId: String?
    @Published private(set) var deviceId: String?
    @Published private(set) var deviceName: String = ""
    @Published private(set) var isPaired: Bool = false
    @Published private(set) var pairedDevices: [String: PairedDevice] = [:]

    private init() { loadFromDisk() }

    // MARK: - AirClip lifecycle

    /// Create a brand-new AirClip with this Mac as the founding member.
    func createAirClip(name: String) {
        airClipId   = UUID().uuidString
        deviceId = UUID().uuidString
        deviceName = name
        isPaired = true
        persist()
    }

    /// Join an existing AirClip network (received via pair_ok from another device).
    func joinAirClip(airClipId: String, myName: String, allDevices: [PairedDevice]) {
        self.airClipId = airClipId
        if deviceId == nil { deviceId = UUID().uuidString }
        deviceName = myName
        isPaired   = true
        for d in allDevices { pairedDevices[d.deviceId] = d }
        persist()
    }

    func addOrUpdateDevice(_ device: PairedDevice) {
        pairedDevices[device.deviceId] = device
        persist()
    }

    func touchDevice(_ deviceId: String, wifiNetwork: String? = nil) {
        guard var d = pairedDevices[deviceId] else { return }
        d = PairedDevice(
            deviceId: d.deviceId, deviceName: d.deviceName,
            publicKey: d.publicKey, platform: d.platform,
            lastSeenMs: Int64(Date().timeIntervalSince1970 * 1000),
            wifiNetwork: wifiNetwork ?? d.wifiNetwork
        )
        pairedDevices[deviceId] = d
        persist()
    }

    func removeDevice(_ deviceId: String) {
        pairedDevices.removeValue(forKey: deviceId)
        persist()
        PeerManager.shared.disconnectDevice(deviceId, notifyRemote: true)
    }

    func ensureDeviceId() {
        guard deviceId == nil else { return }
        deviceId = UUID().uuidString
        persist()
    }

    func setDeviceName(_ name: String) {
        deviceName = name
        UserDefaults.standard.set(name, forKey: "deviceName")
    }

    func clearAll() {
        airClipId       = nil
        deviceId     = nil
        deviceName   = ""
        isPaired     = false
        pairedDevices = [:]
        ["airClipId", "deviceId", "deviceName", "pairedDevices"].forEach {
            UserDefaults.standard.removeObject(forKey: $0)
        }
        SyncModeStore.shared.applyRuntimePolicy()
        CryptoManager.shared.clearKeys()
    }

    // MARK: - Persistence

    private func persist() {
        UserDefaults.standard.set(airClipId,      forKey: "airClipId")
        UserDefaults.standard.set(deviceId,    forKey: "deviceId")
        UserDefaults.standard.set(deviceName,  forKey: "deviceName")
        if let data = try? JSONEncoder().encode(Array(pairedDevices.values)) {
            UserDefaults.standard.set(data, forKey: "pairedDevices")
        }
    }

    private func loadFromDisk() {
        airClipId     = UserDefaults.standard.string(forKey: "airClipId")
        deviceId   = UserDefaults.standard.string(forKey: "deviceId")
        deviceName = UserDefaults.standard.string(forKey: "deviceName") ?? ""
        isPaired   = airClipId != nil && deviceId != nil

        if let data    = UserDefaults.standard.data(forKey: "pairedDevices"),
           let devices = try? JSONDecoder().decode([PairedDevice].self, from: data) {
            pairedDevices = Dictionary(uniqueKeysWithValues: devices.map { ($0.deviceId, $0) })
        }
    }
}
