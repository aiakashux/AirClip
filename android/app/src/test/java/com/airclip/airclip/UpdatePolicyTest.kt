package com.airclip.airclip

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class UpdatePolicyTest {
    @Test
    fun launchChecksAreLimitedToOnceDaily() {
        val now = 200_000_000L
        assertTrue(UpdatePolicy.shouldCheck(now, 0L))
        assertFalse(UpdatePolicy.shouldCheck(now, now - UpdatePolicy.DAY_MS + 1))
        assertTrue(UpdatePolicy.shouldCheck(now, now - UpdatePolicy.DAY_MS))
    }

    @Test
    fun onlyNewerAllowlistedHttpsReleasesAreAccepted() {
        val valid = UpdateInfo(3, "2.1", "Small fixes.", "https://airclip-silk.vercel.app/#downloads")
        assertTrue(UpdatePolicy.isValidUpdate(valid, installedVersionCode = 2))
        assertFalse(UpdatePolicy.isValidUpdate(valid.copy(versionCode = 2), installedVersionCode = 2))
        assertFalse(UpdatePolicy.isValidUpdate(valid.copy(downloadUrl = "http://airclip-silk.vercel.app/#downloads"), 2))
        assertFalse(UpdatePolicy.isValidUpdate(valid.copy(downloadUrl = "https://example.com/app.apk"), 2))
    }
}
