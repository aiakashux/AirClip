import Foundation

@main
struct DeviceConnectionStatusTextCheck {
    static func main() {
        precondition(DeviceConnectionStatusText.onlineRemoteDevices(0) == "No devices nearby · check same Wi-Fi")
        precondition(DeviceConnectionStatusText.onlineRemoteDevices(1) == "1 other device online")
        precondition(DeviceConnectionStatusText.onlineRemoteDevices(2) == "2 other devices online")
        precondition(DeviceConnectionStatusText.offlineDevice(lastSeen: "4 hours ago") == "Offline · last seen 4 hours ago")
        precondition(DeviceConnectionStatusText.offlineDevice(lastSeen: nil) == "Offline")

        precondition(HotspotFallbackPolicy.shouldProbeDefaultGateway(
            visiblePeerCount: 0,
            connectedPeerCount: 0,
            hasPairedAndroidDevice: true
        ))
        precondition(!HotspotFallbackPolicy.shouldProbeDefaultGateway(
            visiblePeerCount: 1,
            connectedPeerCount: 0,
            hasPairedAndroidDevice: true
        ))
        precondition(!HotspotFallbackPolicy.shouldProbeDefaultGateway(
            visiblePeerCount: 0,
            connectedPeerCount: 1,
            hasPairedAndroidDevice: true
        ))

        precondition(WiFiMismatchGuidance.message(
            currentNetwork: "Network 2",
            peerNetworks: ["Network 1", "Network 1"],
            allDevicesOffline: true
        ) == "This device is on “Network 2”. Other devices were last seen on “Network 1”.")
        precondition(WiFiMismatchGuidance.message(
            currentNetwork: "Network 1",
            peerNetworks: ["Network 1"],
            allDevicesOffline: true
        ) == "Check that all devices are on the same Wi-Fi.")
        precondition(WiFiMismatchGuidance.message(
            currentNetwork: "Network 2",
            peerNetworks: ["Network 1"],
            allDevicesOffline: false
        ) == nil)
    }
}
