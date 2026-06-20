import Foundation

enum DeviceRemovalNotice {
    static let type = "device_removed"

    static func payload(targetDeviceId: String) -> [String: String] {
        [
            "type": type,
            "target_device_id": targetDeviceId,
        ]
    }

    static func targetsCurrentDevice(_ json: [String: Any], currentDeviceId: String?) -> Bool {
        guard
            json["type"] as? String == type,
            let targetDeviceId = json["target_device_id"] as? String,
            let currentDeviceId
        else {
            return false
        }
        return targetDeviceId == currentDeviceId
    }
}
