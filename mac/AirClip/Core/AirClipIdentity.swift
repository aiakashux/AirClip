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

    /// A public key identifies an Airclip installation even when it has been
    /// assigned a replacement device ID during pairing.
    static func deduplicated(_ devices: [PairedDevice]) -> [String: PairedDevice] {
        var result: [String: PairedDevice] = [:]
        for device in devices {
            if !device.publicKey.isEmpty {
                result = result.filter { $0.value.publicKey != device.publicKey }
            }
            result[device.deviceId] = device
        }
        return result
    }
}

// MARK: - AirclipIdentity

/// Self-sovereign identity store — no server account needed.
/// Replaces AuthManager's server-backed auth with a local airclip_id shared across
/// paired devices. All state persists to UserDefaults.
@MainActor
final class AirclipIdentity: ObservableObject {
    static let shared = AirclipIdentity()

    @Published private(set) var airClipId: String?
    @Published private(set) var deviceId: String?
    @Published private(set) var deviceName: String = ""
    @Published private(set) var spaceName: String = ""
    @Published private(set) var isPaired: Bool = false
    @Published private(set) var pairedDevices: [String: PairedDevice] = [:]

    private init() { loadFromDisk() }

    // MARK: - Airclip lifecycle

    /// Create a brand-new Airclip with this Mac as the founding member.
    func createAirclip(spaceName: String, deviceName: String) {
        airClipId   = UUID().uuidString
        deviceId = UUID().uuidString
        self.deviceName = normalizedDeviceName(deviceName)
        self.spaceName = normalizedDeviceName(spaceName)
        isPaired = true
        persist()
        SyncModeStore.shared.applyRuntimePolicy()
    }

    /// Join an existing Airclip space (received via pair_ok from another device).
    func joinAirclip(airClipId: String, myName: String, spaceName: String? = nil, allDevices: [PairedDevice]) {
        self.airClipId = airClipId
        if deviceId == nil { deviceId = UUID().uuidString }
        deviceName = normalizedDeviceName(myName)
        if let spaceName, !spaceName.isEmpty { self.spaceName = normalizedDeviceName(spaceName) }
        isPaired   = true
        pairedDevices.removeAll()
        for d in allDevices where d.deviceId != deviceId {
            pairedDevices[d.deviceId] = normalizedPairedDevice(d)
        }
        persist()
        SyncModeStore.shared.applyRuntimePolicy()
    }

    func addOrUpdateDevice(_ device: PairedDevice) {
        let normalizedDevice = normalizedPairedDevice(device)
        let isNewDevice = !pairedDevices.values.contains {
            $0.deviceId == normalizedDevice.deviceId ||
            (!normalizedDevice.publicKey.isEmpty && $0.publicKey == normalizedDevice.publicKey)
        }
        pairedDevices = PairedDevice.deduplicated(Array(pairedDevices.values) + [normalizedDevice])
        persist()
        if isNewDevice, normalizedDevice.deviceId != deviceId {
            DeviceNotificationCoordinator.shared.notifyDeviceAdded(normalizedDevice)
        }
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
        let normalizedName = normalizedDeviceName(name)
        deviceName = normalizedName
        UserDefaults.standard.set(normalizedName, forKey: "deviceName")
    }

    func clearAll() {
        airClipId       = nil
        deviceId     = nil
        deviceName   = ""
        spaceName    = ""
        isPaired     = false
        pairedDevices = [:]
        ["airClipId", "deviceId", "deviceName", "spaceName", "pairedDevices"].forEach {
            UserDefaults.standard.removeObject(forKey: $0)
        }
        SyncModeStore.shared.applyRuntimePolicy()
        LocalHistoryStore.shared.clearAll()
        UnreadStore.shared.markRead()
        CryptoManager.shared.clearKeys()
    }

    func leaveNetwork() {
        if let deviceId {
            PeerManager.shared.broadcastDeviceRemoval(targetDeviceId: deviceId)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.clearAll()
        }
    }

    // MARK: - Persistence

    private func persist() {
        UserDefaults.standard.set(airClipId,      forKey: "airClipId")
        UserDefaults.standard.set(deviceId,    forKey: "deviceId")
        UserDefaults.standard.set(deviceName,  forKey: "deviceName")
        UserDefaults.standard.set(spaceName,   forKey: "spaceName")
        if let data = try? JSONEncoder().encode(Array(pairedDevices.values)) {
            UserDefaults.standard.set(data, forKey: "pairedDevices")
        }
    }

    private func loadFromDisk() {
        airClipId     = UserDefaults.standard.string(forKey: "airClipId")
        deviceId   = UserDefaults.standard.string(forKey: "deviceId")
        deviceName = UserDefaults.standard.string(forKey: "deviceName") ?? ""
        spaceName  = UserDefaults.standard.string(forKey: "spaceName") ?? "My Space"
        isPaired   = airClipId != nil && deviceId != nil

        if let data    = UserDefaults.standard.data(forKey: "pairedDevices"),
           let devices = try? JSONDecoder().decode([PairedDevice].self, from: data) {
            let normalizedDevices = devices.map(normalizedPairedDevice).sorted { $0.lastSeenMs < $1.lastSeenMs }
            pairedDevices = PairedDevice.deduplicated(normalizedDevices)
            if pairedDevices.count != devices.count { persist() }
        }
    }

    private func normalizedDeviceName(_ name: String) -> String {
        DeviceDisplayText.limitedName(name.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private func normalizedPairedDevice(_ device: PairedDevice) -> PairedDevice {
        PairedDevice(
            deviceId: device.deviceId,
            deviceName: normalizedDeviceName(device.deviceName),
            publicKey: device.publicKey,
            deviceModel: device.deviceModel,
            platform: device.platform,
            lastSeenMs: device.lastSeenMs,
            wifiNetwork: device.wifiNetwork
        )
    }
}
