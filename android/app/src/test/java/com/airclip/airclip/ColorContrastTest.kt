package com.airclip.airclip

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.compositeOver
import com.airclip.airclip.ui.theme.buildDarkM3
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
                    colors.textTertiary,
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

    @Test
    fun darkMetadataRemainsReadableInInteractiveStates() {
        val c = darkAirclipColors()
        val surfaces = listOf(c.bgBase, c.bgElevated, c.bgFloating)
        for (surface in surfaces) {
            for (fill in listOf(c.activeFill, c.selectionFill)) {
                val background = fill.compositeOver(surface)
                for (text in listOf(c.textPrimary, c.textSecondary, c.textTertiary)) {
                    assertTrue("Interactive contrast ${contrast(text, background)}", contrast(text, background) >= 4.5)
                }
            }
        }
    }

    @Test
    fun destructiveButtonTextRemainsReadableWhenPressed() {
        val c = darkAirclipColors()
        val m3 = buildDarkM3()
        for (alpha in listOf(1f, 0.82f)) {
            val fill = c.destructive.copy(alpha = alpha).compositeOver(c.bgFloating)
            assertTrue(contrast(m3.onError, fill) >= 4.5)
        }
        assertTrue(contrast(m3.outline, c.bgFloating) >= 3.0)
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
