import Foundation

@main
struct DeviceConnectionStatusTextCheck {
    static func main() {
        precondition(DeviceConnectionStatusText.onlineRemoteDevices(0) == "No devices nearby · check same Wi-Fi")
        precondition(DeviceConnectionStatusText.onlineRemoteDevices(1) == "1 other device online")
        precondition(DeviceConnectionStatusText.onlineRemoteDevices(2) == "2 other devices online")
    }
}
