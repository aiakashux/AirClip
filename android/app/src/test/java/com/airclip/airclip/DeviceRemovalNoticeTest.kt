package com.airclip.airclip

import com.airclip.airclip.device.DeviceRemovalNotice
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class DeviceRemovalNoticeTest {
    @Test
    fun `payload targets removed device`() {
        val payload = DeviceRemovalNotice.payload("mac-1")

        assertEquals("device_removed", payload["type"])
        assertEquals("mac-1", payload["target_device_id"])
        assertTrue(DeviceRemovalNotice.targetsCurrentDevice(payload, "mac-1"))
        assertFalse(DeviceRemovalNotice.targetsCurrentDevice(payload, "android-1"))
        assertFalse(DeviceRemovalNotice.targetsCurrentDevice(payload, null))
    }
}
