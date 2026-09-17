import Foundation

enum DeviceConnectionStatusText {
    static func onlineRemoteDevices(_ count: Int) -> String {
        if count <= 0 {
            return "No devices nearby · check same Wi-Fi"
        }
        if count == 1 {
            return "1 other device online"
        }
        return "\(count) other devices online"
    }

    static func offlineDevice(lastSeen: String?) -> String {
        guard let lastSeen else { return "Offline" }
        return "Offline · last seen \(lastSeen)"
    }
}

enum HotspotFallbackPolicy {
    static func shouldProbeDefaultGateway(
        visiblePeerCount: Int,
        connectedPeerCount: Int,
        hasPairedAndroidDevice: Bool
    ) -> Bool {
        visiblePeerCount == 0 && connectedPeerCount == 0 && hasPairedAndroidDevice
    }
}

enum WiFiMismatchGuidance {
    static func message(
        currentNetwork: String?,
        peerNetworks: [String],
        allDevicesOffline: Bool
    ) -> String? {
        guard allDevicesOffline else { return nil }
        let current = currentNetwork?.trimmingCharacters(in: .whitespacesAndNewlines)
        let peers = Set(peerNetworks.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty })
        guard let current, !current.isEmpty, peers.count == 1, let peer = peers.first, peer != current else {
            return "Check that all devices are on the same Wi-Fi."
        }
        return "This device is on “\(current)”. Other devices were last seen on “\(peer)”."
    }
}
