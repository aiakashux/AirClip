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
}
