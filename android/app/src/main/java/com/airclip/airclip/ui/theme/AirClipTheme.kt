package com.airclip.airclip.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp
import com.airclip.airclip.AppAppearanceSetting

// ── Color data class — all semantic tokens in one place ─────────────────────

data class AirClipColorScheme(
    val bgBase: Color,
    val bgElevated: Color,
    val bgFloating: Color,
    val textPrimary: Color,
    val textSecondary: Color,
    val textTertiary: Color,
    val borderSubtle: Color,
    val borderDefault: Color,
    val accent: Color,
    val accentDeep: Color,
    val selectionFill: Color,
    val activeFill: Color,
    val green: Color,
    val blue: Color,
    val yellow: Color,
    val destructive: Color,
    val isDark: Boolean,
)

// ── Light palette ────────────────────────────────────────────────────────────

fun lightAirClipColors() = AirClipColorScheme(
    bgBase        = Color(0xFFFFFFFF),
    bgElevated    = Color(0xFFF5F5F7),
    bgFloating    = Color(0xFFFFFFFF),
    textPrimary   = Color(0xFF0A0A12),
    textSecondary = Color(0xFF6C7280),
    textTertiary  = Color(0xFF9CA3AF),
    borderSubtle  = Color(0xFFEBEBEF),
    borderDefault = Color(0xFFD4D4D8),
    accent        = Color(0xFF5647F2),
    accentDeep    = Color(0xFF4436D9),
    selectionFill = Color(0x145647F2),   // accent 8%
    activeFill    = Color(0x0A000000),   // black 4%
    green         = Color(0xFF16A34A),
    blue          = Color(0xFF2563EB),
    yellow        = Color(0xFFD97706),
    destructive   = Color(0xFFDC2626),
    isDark        = false,
)

// ── Dark palette ─────────────────────────────────────────────────────────────

fun darkAirClipColors() = AirClipColorScheme(
    bgBase        = Color(0xFF121418),
    bgElevated    = Color(0xFF1E2024),
    bgFloating    = Color(0xFF23262B),
    textPrimary   = Color(0xFFF2F3F5),
    textSecondary = Color(0xFFC4C8D0),
    textTertiary  = Color(0xFF8F949D),
    borderSubtle  = Color(0xFF343741),
    borderDefault = Color(0xFF444A56),
    accent        = Color(0xFF5647F2),
    accentDeep    = Color(0xFF4436D9),
    selectionFill = Color(0x225647F2),
    activeFill    = Color(0x18FFFFFF),
    green         = Color(0xFF59D499),
    blue          = Color(0xFF5FA7FF),
    yellow        = Color(0xFFFFC531),
    destructive   = Color(0xFFE5342A),
    isDark        = true,
)

// ── CompositionLocal ─────────────────────────────────────────────────────────

val LocalAirClipColors = staticCompositionLocalOf { lightAirClipColors() }

// ── Convenience extension — use inside any @Composable ───────────────────────
// Usage: val c = LocalAirClipColors.current
// Or via extension: MaterialTheme.airClip

val MaterialTheme.airClip: AirClipColorScheme
    @Composable get() = LocalAirClipColors.current

// ── Legacy top-level aliases (dark defaults — kept so any untouched code compiles)
val AirClipBgBase        = Color(0xFF121418)
val AirClipBgElevated    = Color(0xFF1E2024)
val AirClipBgFloating    = Color(0xFF23262B)
val AirClipTextPrimary   = Color(0xFFF2F3F5)
val AirClipTextSecondary = Color(0xFFC4C8D0)
val AirClipTextTertiary  = Color(0xFF8F949D)
val AirClipBorderSubtle  = Color(0xFF343741)
val AirClipBorderDefault = Color(0xFF444A56)
val AirClipAccent        = Color(0xFF5647F2)
val AirClipAccentDeep    = Color(0xFF4436D9)
val AirClipGreen         = Color(0xFF59D499)
val AirClipBlue          = Color(0xFF5FA7FF)
val AirClipYellow        = Color(0xFFFFC531)
val AirClipDestructive   = Color(0xFFE5342A)
val AirClipSelectionFill = Color(0x225647F2)
val AirClipActiveFill    = Color(0x18FFFFFF)

// ── Typography ───────────────────────────────────────────────────────────────

val AirClipTypography = Typography(
    titleLarge  = TextStyle(fontWeight = FontWeight.SemiBold, fontSize = 20.sp, lineHeight = 28.sp),
    titleMedium = TextStyle(fontWeight = FontWeight.SemiBold, fontSize = 17.sp, lineHeight = 24.sp),
    bodyLarge   = TextStyle(fontWeight = FontWeight.Normal,   fontSize = 15.sp, lineHeight = 22.sp),
    bodyMedium  = TextStyle(fontWeight = FontWeight.Normal,   fontSize = 13.sp, lineHeight = 19.sp),
    bodySmall   = TextStyle(fontWeight = FontWeight.Normal,   fontSize = 12.sp, lineHeight = 17.sp),
    labelLarge  = TextStyle(fontWeight = FontWeight.Medium,   fontSize = 13.sp, lineHeight = 19.sp),
    labelMedium = TextStyle(fontWeight = FontWeight.Medium,   fontSize = 11.sp, lineHeight = 16.sp),
    labelSmall  = TextStyle(fontWeight = FontWeight.Medium,   fontSize = 10.sp, lineHeight = 14.sp),
)

// ── M3 schemes ───────────────────────────────────────────────────────────────

private fun buildLightM3() = lightColorScheme(
    primary            = Color(0xFF5647F2),
    onPrimary          = Color.White,
    primaryContainer   = Color(0x145647F2),
    onPrimaryContainer = Color(0xFF0A0A12),
    secondary          = Color(0xFF2563EB),
    onSecondary        = Color.White,
    tertiary           = Color(0xFF16A34A),
    onTertiary         = Color.White,
    background         = Color(0xFFFFFFFF),
    onBackground       = Color(0xFF0A0A12),
    surface            = Color(0xFFF5F5F7),
    onSurface          = Color(0xFF0A0A12),
    surfaceVariant     = Color(0xFFFFFFFF),
    onSurfaceVariant   = Color(0xFF6C7280),
    error              = Color(0xFFDC2626),
    onError            = Color.White,
    outline            = Color(0xFFD4D4D8),
    outlineVariant     = Color(0xFFEBEBEF),
)

private fun buildDarkM3() = darkColorScheme(
    primary            = Color(0xFF5647F2),
    onPrimary          = Color.White,
    primaryContainer   = Color(0x225647F2),
    onPrimaryContainer = Color(0xFFF2F3F5),
    secondary          = Color(0xFF5FA7FF),
    onSecondary        = Color(0xFF121418),
    tertiary           = Color(0xFF59D499),
    onTertiary         = Color(0xFF121418),
    background         = Color(0xFF121418),
    onBackground       = Color(0xFFF2F3F5),
    surface            = Color(0xFF1E2024),
    onSurface          = Color(0xFFF2F3F5),
    surfaceVariant     = Color(0xFF23262B),
    onSurfaceVariant   = Color(0xFFC4C8D0),
    error              = Color(0xFFE5342A),
    onError            = Color.White,
    outline            = Color(0xFF444A56),
    outlineVariant     = Color(0xFF343741),
)

// ── Entry point ──────────────────────────────────────────────────────────────

@Composable
fun AirClipTheme(
    appearanceSetting: AppAppearanceSetting = AppAppearanceSetting.LIGHT,
    content: @Composable () -> Unit,
) {
    val darkTheme = when (appearanceSetting) {
        AppAppearanceSetting.DARK   -> true
        AppAppearanceSetting.LIGHT  -> false
        AppAppearanceSetting.SYSTEM -> isSystemInDarkTheme()
    }
    val colors = if (darkTheme) darkAirClipColors() else lightAirClipColors()
    val m3Colors = if (darkTheme) buildDarkM3() else buildLightM3()

    CompositionLocalProvider(LocalAirClipColors provides colors) {
        MaterialTheme(
            colorScheme = m3Colors,
            typography  = AirClipTypography,
            content     = content,
        )
    }
}
