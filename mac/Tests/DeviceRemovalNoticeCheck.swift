import Foundation

@main
struct DeviceRemovalNoticeCheck {
    static func main() {
        let payload = DeviceRemovalNotice.payload(targetDeviceId: "mac-1")

        precondition(payload["type"] == "device_removed")
        precondition(payload["target_device_id"] == "mac-1")
        precondition(DeviceRemovalNotice.targetsCurrentDevice(payload, currentDeviceId: "mac-1"))
        precondition(!DeviceRemovalNotice.targetsCurrentDevice(payload, currentDeviceId: "android-1"))
        precondition(!DeviceRemovalNotice.targetsCurrentDevice(payload, currentDeviceId: nil))
    }
}
