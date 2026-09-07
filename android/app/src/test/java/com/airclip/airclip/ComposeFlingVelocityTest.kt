package com.airclip.airclip

import androidx.compose.ui.ExperimentalComposeUiApi
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.input.pointer.PointerId
import androidx.compose.ui.input.pointer.PointerInputChange
import androidx.compose.ui.input.pointer.util.VelocityTracker
import androidx.compose.ui.input.pointer.util.VelocityTrackerAddPointsFix
import androidx.compose.ui.input.pointer.util.addPointerInputChange
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

@OptIn(ExperimentalComposeUiApi::class)
class ComposeFlingVelocityTest {
    @Test
    fun `finger lift preserves fast swipe direction and a held stop cancels fling`() {
        val previousSetting = VelocityTrackerAddPointsFix
        try {
            configureComposeVelocityTracking()
            for (direction in listOf(-1f, 1f)) {
                val fling = replay(direction, upTime = 47L)
                assertTrue("Fling reversed or stopped: direction=$direction velocity=$fling", direction * fling > 1000f)
                assertEquals(0f, replay(direction, upTime = 80L), 0.01f)
            }
        } finally {
            VelocityTrackerAddPointsFix = previousSetting
        }
    }

    private fun replay(direction: Float, upTime: Long): Float {
        val tracker = VelocityTracker()
        // OnePlus 6 finger trace: legacy tracking reverses this downward swipe at release.
        val times = listOf(0L, 10L, 20L, 21L, upTime)
        val positions = listOf(1101f, 1256f, 1470.0834f, 1494f, 1494f)
        for (i in times.indices) {
            val position = Offset(0f, direction * positions[i])
            tracker.addPointerInputChange(
                PointerInputChange(
                    id = PointerId(0),
                    uptimeMillis = times[i],
                    position = position,
                    pressed = i < times.lastIndex,
                    previousUptimeMillis = times[(i - 1).coerceAtLeast(0)],
                    previousPosition = Offset(0f, direction * positions[(i - 1).coerceAtLeast(0)]),
                    previousPressed = i > 0,
                    isInitiallyConsumed = false,
                ).copy(originalEventPosition = position),
            )
        }
        return tracker.calculateVelocity().y
    }
}
