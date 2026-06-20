package com.airclip.airclip.ui.theme

import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp

// ── Color tokens ────────────────────────────────────────────────────────────

val AirClipBgBase        = Color(0xFF121418)
val AirClipBgElevated    = Color(0xFF1E2024)
val AirClipBgFloating    = Color(0xFF23262B)

val AirClipTextPrimary   = Color(0xFFF2F3F5)
val AirClipTextSecondary = Color(0xFFC4C8D0)
val AirClipTextTertiary  = Color(0xFF8F949D)

val AirClipBorderSubtle  = Color(0xFF343741)
val AirClipBorderDefault = Color(0xFF444A56)

val AirClipAccent        = Color(0xFF10B981)
val AirClipAccentDeep    = Color(0xFF0E8F65)

val AirClipGreen         = Color(0xFF59D499)
val AirClipBlue          = Color(0xFF5FA7FF)
val AirClipYellow        = Color(0xFFFFC531)
val AirClipDestructive   = Color(0xFFE5342A)

val AirClipSelectionFill = Color(0x2610B981)
val AirClipActiveFill    = Color(0x1421262B)

// ── Material 3 scheme ───────────────────────────────────────────────────────

private val DarkColorScheme = darkColorScheme(
    primary            = AirClipAccent,
    onPrimary          = Color.White,
    primaryContainer   = AirClipSelectionFill,
    onPrimaryContainer = AirClipTextPrimary,
    secondary          = AirClipBlue,
    onSecondary        = AirClipBgBase,
    tertiary           = AirClipGreen,
    onTertiary         = AirClipBgBase,
    background         = AirClipBgBase,
    onBackground       = AirClipTextPrimary,
    surface            = AirClipBgElevated,
    onSurface          = AirClipTextPrimary,
    surfaceVariant     = AirClipBgFloating,
    onSurfaceVariant   = AirClipTextSecondary,
    error              = AirClipDestructive,
    onError            = Color.White,
    outline            = AirClipBorderDefault,
    outlineVariant     = AirClipBorderSubtle,
)

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

// ── Entry point ──────────────────────────────────────────────────────────────

@Composable
fun AirClipTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = DarkColorScheme,
        typography  = AirClipTypography,
        content     = content,
    )
}
