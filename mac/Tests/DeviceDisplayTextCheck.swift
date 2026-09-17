import Foundation

@main
struct DeviceDisplayTextCheck {
    static func main() {
        precondition(DeviceDisplayText.clipped("OnePlus 6") == "OnePlus 6")
        precondition(DeviceDisplayText.clipped(String(repeating: "A", count: 36)).count == 36)

        let clipped = DeviceDisplayText.clipped(String(repeating: "B", count: 50))
        precondition(clipped.count == 36)
        precondition(clipped.hasSuffix("..."))

        let devices = PairedDevice.deduplicated([
            PairedDevice(deviceId: "old", deviceName: "ONEPLUS A6000", publicKey: "key", lastSeenMs: 1),
            PairedDevice(deviceId: "current", deviceName: "ONEPLUS A6000", publicKey: "key", lastSeenMs: 2),
            PairedDevice(deviceId: "other", deviceName: "ONEPLUS A6000", publicKey: "other", lastSeenMs: 1),
        ])
        precondition(devices.count == 2)
        precondition(devices["current"] != nil)
    }
}
