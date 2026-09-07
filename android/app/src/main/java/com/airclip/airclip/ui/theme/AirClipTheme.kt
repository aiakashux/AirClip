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
    bgBase        = Color(0xFFF4F5F7),
    bgElevated    = Color(0xFFFFFFFF),
    bgFloating    = Color(0xFFF8F9FB),
    textPrimary   = Color(0xFF15161A),
    textSecondary = Color(0xFF5B6270),
    textTertiary  = Color(0xFF7A8392),
    borderSubtle  = Color(0x141C1D20),
    borderDefault = Color(0x241C1D20),
    accent        = Color(0xFF5647F2),
    accentDeep    = Color(0xFF4436D9),
    selectionFill = Color(0x145647F2),   // accent 8%
    activeFill    = Color(0x1A1C1D20),
    green         = Color(0xFF167B4B),
    blue          = Color(0xFF006FA8),
    yellow        = Color(0xFF8A5B00),
    destructive   = Color(0xFFB42318),
    isDark        = false,
)

// ── Dark palette ─────────────────────────────────────────────────────────────

fun darkAirClipColors() = AirClipColorScheme(
    bgBase        = Color(0xFF101113),
    bgElevated    = Color(0xFF1C1D20),
    bgFloating    = Color(0xFF25262A),
    textPrimary   = Color(0xFFF2F3F5),
    textSecondary = Color(0xFF8F949D),
    textTertiary  = Color(0xFF626875),
    borderSubtle  = Color(0x14FFFFFF),
    borderDefault = Color(0x24FFFFFF),
    accent        = Color(0xFF5647F2),
    accentDeep    = Color(0xFF4436D9),
    selectionFill = Color(0x225647F2),
    activeFill    = Color(0x1AFFFFFF),
    green         = Color(0xFF6CE0A8),
    blue          = Color(0xFF70CBFF),
    yellow        = Color(0xFFFFD45C),
    destructive   = Color(0xFFFF5B55),
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
val AirClipBgBase        = Color(0xFF101113)
val AirClipBgElevated    = Color(0xFF1C1D20)
val AirClipBgFloating    = Color(0xFF25262A)
val AirClipTextPrimary   = Color(0xFFF2F3F5)
val AirClipTextSecondary = Color(0xFF8F949D)
val AirClipTextTertiary  = Color(0xFF626875)
val AirClipBorderSubtle  = Color(0x14FFFFFF)
val AirClipBorderDefault = Color(0x24FFFFFF)
val AirClipAccent        = Color(0xFF5647F2)
val AirClipAccentDeep    = Color(0xFF4436D9)
val AirClipGreen         = Color(0xFF6CE0A8)
val AirClipBlue          = Color(0xFF70CBFF)
val AirClipYellow        = Color(0xFFFFD45C)
val AirClipDestructive   = Color(0xFFFF5B55)
val AirClipSelectionFill = Color(0x225647F2)
val AirClipActiveFill    = Color(0x1AFFFFFF)

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
    onPrimaryContainer = Color(0xFF15161A),
    secondary          = Color(0xFF006FA8),
    onSecondary        = Color.White,
    tertiary           = Color(0xFF167B4B),
    onTertiary         = Color.White,
    background         = Color(0xFFF4F5F7),
    onBackground       = Color(0xFF15161A),
    surface            = Color(0xFFFFFFFF),
    onSurface          = Color(0xFF15161A),
    surfaceVariant     = Color(0xFFF8F9FB),
    onSurfaceVariant   = Color(0xFF5B6270),
    error              = Color(0xFFB42318),
    onError            = Color.White,
    outline            = Color(0x241C1D20),
    outlineVariant     = Color(0x141C1D20),
)

private fun buildDarkM3() = darkColorScheme(
    primary            = Color(0xFF5647F2),
    onPrimary          = Color.White,
    primaryContainer   = Color(0x225647F2),
    onPrimaryContainer = Color(0xFFF2F3F5),
    secondary          = Color(0xFF70CBFF),
    onSecondary        = Color(0xFF101113),
    tertiary           = Color(0xFF6CE0A8),
    onTertiary         = Color(0xFF101113),
    background         = Color(0xFF101113),
    onBackground       = Color(0xFFF2F3F5),
    surface            = Color(0xFF1C1D20),
    onSurface          = Color(0xFFF2F3F5),
    surfaceVariant     = Color(0xFF25262A),
    onSurfaceVariant   = Color(0xFF8F949D),
    error              = Color(0xFFFF5B55),
    onError            = Color.White,
    outline            = Color(0x24FFFFFF),
    outlineVariant     = Color(0x14FFFFFF),
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
