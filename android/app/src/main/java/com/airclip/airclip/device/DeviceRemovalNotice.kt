package com.airclip.airclip.device

object DeviceRemovalNotice {
    const val TYPE = "device_removed"
    const val TARGET_DEVICE_ID = "target_device_id"

    fun payload(targetDeviceId: String): Map<String, String> = mapOf(
        "type" to TYPE,
        TARGET_DEVICE_ID to targetDeviceId,
    )

    fun targetsCurrentDevice(message: Map<String, String>, currentDeviceId: String?): Boolean =
        message["type"] == TYPE &&
            currentDeviceId != null &&
            message[TARGET_DEVICE_ID] == currentDeviceId
}
