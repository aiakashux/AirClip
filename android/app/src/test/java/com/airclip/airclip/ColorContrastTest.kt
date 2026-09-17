package com.airclip.airclip

import androidx.compose.ui.graphics.Color
import com.airclip.airclip.ui.theme.darkAirclipColors
import com.airclip.airclip.ui.theme.lightAirclipColors
import org.junit.Assert.assertTrue
import org.junit.Test

class ColorContrastTest {
    @Test
    fun readableColorsMeetWcagAaOnEverySurface() {
        for (colors in listOf(lightAirclipColors(), darkAirclipColors())) {
            for (surface in listOf(colors.bgBase, colors.bgElevated, colors.bgFloating)) {
                for (foreground in listOf(
                    colors.textPrimary,
                    colors.textSecondary,
                    colors.accent,
                    colors.green,
                    colors.blue,
                    colors.yellow,
                    colors.destructive,
                )) {
                    assertTrue("Contrast was ${contrast(foreground, surface)}", contrast(foreground, surface) >= 4.5)
                }
            }
        }
    }

    private fun contrast(a: Color, b: Color): Double {
        val lighter = maxOf(luminance(a), luminance(b))
        val darker = minOf(luminance(a), luminance(b))
        return (lighter + 0.05) / (darker + 0.05)
    }

    private fun luminance(color: Color): Double =
        0.2126 * linear(color.red) + 0.7152 * linear(color.green) + 0.0722 * linear(color.blue)

    private fun linear(value: Float): Double =
        if (value <= 0.04045f) value / 12.92 else Math.pow((value + 0.055) / 1.055, 2.4)
}
