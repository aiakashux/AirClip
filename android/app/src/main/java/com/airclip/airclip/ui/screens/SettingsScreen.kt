package com.airclip.airclip.ui.screens

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.Crossfade
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.CubicBezierEasing
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.selection.selectableGroup
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Check
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.material3.RadioButton
import androidx.compose.material3.RadioButtonDefaults
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import com.airclip.airclip.AppAppearanceSetting
import com.airclip.airclip.BuildConfig
import com.airclip.airclip.MainViewModel
import com.airclip.airclip.R
import com.airclip.airclip.SyncMode
import com.airclip.airclip.ui.theme.LocalAirclipColors

private val BearyFontFamily = FontFamily(Font(R.font.beary))
@Composable
fun SettingsScreen(viewModel: MainViewModel, uiState: SettingsTabUiState) {
    val c = LocalAirclipColors.current
    var showResetDialog by remember { mutableStateOf(false) }
    var showClearHistoryDialog by remember { mutableStateOf(false) }
    val statusBarTop = WindowInsets.statusBars.asPaddingValues().calculateTopPadding()
    val headerHeight = statusBarTop + 80.dp

    val appearanceOptions = listOf("System (Default)", "Light", "Dark")
    val historyOptions = listOf(
        "1 Day", "3 Days", "7 Days", "15 Days", "Forever",
    )
    val syncOptions = listOf("Automatic", "Manual only", "Paused")

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(color = c.bgBase),
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(top = headerHeight),
        ) {

            SettingsGroup(topPadding = 8.dp) {
                SettingsSelectableRow(
                    iconRes = R.drawable.ic_settings_sun_03,
                    title = "Appearance",
                    value = displayAppearance(uiState.appearanceSetting),
                    options = appearanceOptions,
                    onSelect = { label ->
                        when (label) {
                            "System (Default)" -> viewModel.onAppearanceSettingChanged(AppAppearanceSetting.SYSTEM)
                            "Light" -> viewModel.onAppearanceSettingChanged(AppAppearanceSetting.LIGHT)
                            "Dark" -> viewModel.onAppearanceSettingChanged(AppAppearanceSetting.DARK)
                        }
                    },
                )
            }

            SettingsGroupDivider()

            SettingsGroup {
                SettingsSelectableRow(
                    iconRes = R.drawable.ic_settings_clock_02,
                    title = "Keep History for",
                    value = historyOptions[uiState.historyDepth.coerceIn(0, historyOptions.lastIndex)],
                    options = historyOptions,
                    onSelect = { label ->
                        val index = historyOptions.indexOf(label)
                        if (index >= 0) viewModel.onHistoryDepthChanged(index)
                    },
                )
                SettingsSelectableRow(
                    iconRes = R.drawable.ic_settings_database_sync,
                    title = "Sync Clipboard",
                    value = displaySyncMode(uiState.syncMode),
                    options = syncOptions,
                    onSelect = { label ->
                        when (label) {
                            "Automatic" -> viewModel.onSyncModeChanged(SyncMode.AUTO)
                            "Manual only" -> viewModel.onSyncModeChanged(SyncMode.MANUAL_ONLY)
                            "Paused" -> viewModel.onSyncModeChanged(SyncMode.PAUSED)
                        }
                    },
                )
                SettingsStaticRow(
                    iconRes = R.drawable.ic_settings_encrypt,
                    title = "End-to-End Encrypted",
                    value = "Always On",
                )
            }

            SettingsGroupDivider()

            SettingsGroup {
                SettingsStaticRow(
                    iconRes = R.drawable.ic_settings_information_circle,
                    title = "Version",
                    value = "${BuildConfig.VERSION_NAME} (${BuildConfig.VERSION_CODE})",
                )
                SettingsListRow(
                    iconRes = R.drawable.ic_settings_database_sync,
                    title = "Check for Updates",
                    value = uiState.updateStatus ?: "Checks automatically at most once daily.",
                    showArrow = false,
                    onClick = viewModel::onCheckForUpdates,
                    rowHeight = 94.dp,
                    valueMaxLines = 2,
                )
            }

            SettingsGroupDivider()

            SettingsGroup {
                SettingsChoiceRow(
                    iconRes = R.drawable.ic_settings_security_lock,
                    title = "Help improve Airclip",
                    value = "Anonymous feature counts help us improve Airclip. Clipboard content is never shared.",
                    checked = uiState.analyticsEnabled,
                    onCheckedChange = viewModel::onAnalyticsEnabledChanged,
                )
            }

            SettingsGroupDivider()

            SettingsGroup {
                SettingsDangerRow(
                    iconRes = R.drawable.ic_clip_delete,
                    title = "Clear History",
                    value = "Clear clips and saved items from all devices in this space.",
                    onClick = { showClearHistoryDialog = true },
                )
                SettingsDangerRow(
                    iconRes = R.drawable.ic_settings_logout_03,
                    title = "Leave Space",
                    value = "Disconnect this device and clear local data.",
                    onClick = { showResetDialog = true },
                )
            }

            Spacer(Modifier.height(40.dp))
        }

        SettingsHeader(modifier = Modifier.align(Alignment.TopCenter))
    }

    if (showResetDialog) {
        AirclipDestructiveDialog(
            onDismissRequest = { showResetDialog = false },
            iconRes = R.drawable.ic_settings_logout_03,
            title = "Leave this space?",
            message = if (uiState.isLastDeviceInSpace) {
                "This is the last device. Leaving permanently clears this space and its data."
            } else {
                "This device will disconnect and its history, pairing data, settings, and encryption keys will be removed. Other devices stay connected."
            },
            confirmLabel = "Leave Space",
            onConfirm = { showResetDialog = false; viewModel.onResetAirclip() },
        )
    }

    if (showClearHistoryDialog) {
        AirclipDestructiveDialog(
            onDismissRequest = { showClearHistoryDialog = false },
            iconRes = R.drawable.ic_clip_delete,
            title = "Clear history?",
            message = "This permanently removes all clipboard history and saved items from every device in this space.",
            confirmLabel = "Clear History",
            onConfirm = {
                showClearHistoryDialog = false
                viewModel.onClearHistory()
            },
        )
    }
}

@Composable
private fun AirclipDestructiveDialog(
    iconRes: Int,
    title: String,
    message: String,
    confirmLabel: String,
    onDismissRequest: () -> Unit,
    onConfirm: () -> Unit,
) {
    val c = LocalAirclipColors.current
    Dialog(onDismissRequest = onDismissRequest) {
        Surface(
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(24.dp),
            color = c.bgFloating,
            tonalElevation = 0.dp,
            shadowElevation = 12.dp,
            border = androidx.compose.foundation.BorderStroke(1.dp, c.borderSubtle),
        ) {
            Column(
                modifier = Modifier.padding(horizontal = 24.dp, vertical = 28.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Box(
                    modifier = Modifier
                        .size(64.dp)
                        .background(c.destructive.copy(alpha = 0.10f), CircleShape),
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(
                        painter = painterResource(iconRes),
                        contentDescription = null,
                        tint = c.destructive,
                        modifier = Modifier.size(28.dp),
                    )
                }
                Spacer(Modifier.height(20.dp))
                Text(
                    text = title,
                    color = c.textPrimary,
                    fontSize = 20.sp,
                    lineHeight = 26.sp,
                    fontWeight = FontWeight.SemiBold,
                    modifier = Modifier.semantics { heading() },
                )
                Spacer(Modifier.height(8.dp))
                Text(
                    text = message,
                    color = c.textSecondary,
                    fontSize = 14.sp,
                    lineHeight = 20.sp,
                    textAlign = androidx.compose.ui.text.style.TextAlign.Center,
                )
                Spacer(Modifier.height(24.dp))
                AirclipDialogButton(confirmLabel, destructive = true, onClick = onConfirm)
                Spacer(Modifier.height(10.dp))
                AirclipDialogButton("Cancel", destructive = false, onClick = onDismissRequest)
            }
        }
    }
}

@Composable
private fun AirclipDialogButton(
    label: String,
    destructive: Boolean,
    onClick: () -> Unit,
) {
    val c = LocalAirclipColors.current
    val interactionSource = remember { MutableInteractionSource() }
    val pressed by interactionSource.collectIsPressedAsState()
    val neutralFill = if (c.isDark) c.activeFill else Color(0x1A1C1D20)
    val pressedNeutralFill = if (c.isDark) Color.White.copy(alpha = 0.12f) else Color.Black.copy(alpha = 0.10f)
    val fill by animateColorAsState(
        targetValue = when {
            destructive && pressed -> c.destructive.copy(alpha = 0.82f)
            destructive -> c.destructive
            pressed -> pressedNeutralFill
            else -> neutralFill
        },
        animationSpec = tween(100),
        label = "dialog button fill",
    )
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(52.dp)
            .clip(RoundedCornerShape(14.dp))
            .background(fill)
            .clickable(
                interactionSource = interactionSource,
                indication = null,
                role = Role.Button,
                onClick = onClick,
            ),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = label,
            color = if (destructive) Color.White.copy(alpha = 0.96f) else c.textSecondary,
            fontWeight = FontWeight.SemiBold,
            fontSize = 15.sp,
        )
    }
}

@Composable
private fun SettingsHeader(modifier: Modifier = Modifier) {
    val c = LocalAirclipColors.current
    val statusBarTop = WindowInsets.statusBars.asPaddingValues().calculateTopPadding()
    Box(
        modifier = modifier
            .fillMaxWidth()
            .background(c.bgBase)
            .padding(top = statusBarTop + 20.dp, bottom = 20.dp),
    ) {
        Text(
            "Settings",
            fontSize = 36.sp,
            lineHeight = 40.sp,
            fontFamily = BearyFontFamily,
            fontWeight = FontWeight.Normal,
            color = c.textPrimary,
            letterSpacing = (-0.6).sp,
            modifier = Modifier
                .padding(horizontal = 20.dp)
                .semantics { heading() },
        )
    }
}

@Composable
private fun SettingsGroup(
    topPadding: Dp = 20.dp,
    content: @Composable ColumnScope.() -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(top = topPadding, bottom = 20.dp),
        verticalArrangement = Arrangement.spacedBy(4.dp),
        content = content,
    )
}

@Composable
private fun SettingsGroupDivider() {
    val c = LocalAirclipColors.current
    HorizontalDivider(
        modifier = Modifier.padding(horizontal = 20.dp),
        thickness = 1.dp,
        color = c.borderSubtle,
    )
    Spacer(Modifier.height(0.dp))
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun SettingsSelectableRow(
    iconRes: Int?,
    title: String,
    value: String,
    options: List<String>,
    onSelect: (String) -> Unit,
) {
    val c = LocalAirclipColors.current
    var expanded by remember { mutableStateOf(false) }
    var pendingValue by remember(value) { mutableStateOf(value) }
    SettingsListRow(
        iconRes = iconRes,
        title = title,
        value = value,
        showArrow = true,
        onClick = {
            pendingValue = value
            expanded = true
        },
    )
    if (expanded) {
        ModalBottomSheet(
            onDismissRequest = { expanded = false },
            sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
            containerColor = if (c.isDark) c.bgFloating else Color.White,
            tonalElevation = 0.dp,
            dragHandle = { AirclipSheetHandle() },
        ) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .verticalScroll(rememberScrollState())
                    .padding(horizontal = 24.dp)
                    .padding(bottom = 24.dp)
                    .selectableGroup(),
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                Text(
                    title,
                    color = c.textPrimary,
                    fontSize = 24.sp,
                    lineHeight = 32.sp,
                    fontWeight = FontWeight.SemiBold,
                    modifier = Modifier.padding(bottom = 12.dp).semantics { heading() },
                )
                options.forEach { option ->
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clip(RoundedCornerShape(16.dp))
                            .background(if (option == pendingValue) c.accent.copy(alpha = 0.10f)
                                else if (c.isDark) c.bgElevated else Color.White)
                            .border(1.dp, if (option == pendingValue) c.accent.copy(alpha = 0.6f)
                                else c.borderSubtle, RoundedCornerShape(16.dp))
                            .selectable(
                                selected = option == pendingValue,
                                role = Role.RadioButton,
                                onClick = { pendingValue = option },
                            )
                            .heightIn(min = 60.dp)
                            .padding(horizontal = 16.dp, vertical = 12.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Text(option, color = if (option == pendingValue) c.accent else c.textPrimary,
                            fontWeight = if (option == pendingValue) FontWeight.Medium else FontWeight.Normal,
                            fontSize = 16.sp, modifier = Modifier.weight(1f))
                        Spacer(Modifier.width(12.dp))
                        RadioButton(
                            selected = option == pendingValue,
                            onClick = null,
                            colors = RadioButtonDefaults.colors(
                                selectedColor = c.accent,
                                unselectedColor = c.textTertiary,
                            ),
                        )
                    }
                }
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .navigationBarsPadding()
                        .padding(top = 12.dp),
                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    TextButton(
                        onClick = { expanded = false },
                        modifier = Modifier.weight(1f).height(52.dp),
                    ) {
                        Text("Cancel", color = c.textSecondary, fontWeight = FontWeight.Medium)
                    }
                    Button(
                        onClick = {
                            if (pendingValue != value) onSelect(pendingValue)
                            expanded = false
                        },
                        modifier = Modifier.weight(1f).height(52.dp),
                        shape = RoundedCornerShape(26.dp),
                        colors = ButtonDefaults.buttonColors(
                            containerColor = c.textPrimary,
                            contentColor = c.bgBase,
                        ),
                    ) {
                        Text("Save", fontWeight = FontWeight.SemiBold)
                    }
                }
            }
        }
    }
}

@Composable
private fun SettingsStaticRow(
    iconRes: Int,
    title: String,
    value: String,
) {
    SettingsListRow(
        iconRes = iconRes,
        title = title,
        value = value,
        showArrow = false,
        onClick = null,
    )
}

@Composable
private fun SettingsChoiceRow(
    iconRes: Int,
    title: String,
    value: String,
    checked: Boolean,
    onCheckedChange: (Boolean) -> Unit,
) {
    val c = LocalAirclipColors.current
    var expanded by remember { mutableStateOf(false) }
    val shape = RoundedCornerShape(8.dp)
    Row(
        modifier = Modifier.fillMaxWidth().heightIn(min = 96.dp).padding(horizontal = 20.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(painterResource(iconRes), null, tint = c.textSecondary, modifier = Modifier.size(28.dp))
        Spacer(Modifier.width(23.dp))
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text(title, color = c.textPrimary, fontSize = 16.sp, lineHeight = 22.sp, fontWeight = FontWeight.Medium)
            Text(value, color = c.textSecondary, fontSize = 13.sp, lineHeight = 18.sp)
        }
        Spacer(Modifier.width(8.dp))
        Box {
            Row(
                modifier = Modifier
                    .clip(shape)
                    .clickable(role = Role.Button) { expanded = true }
                    .padding(horizontal = 8.dp, vertical = 10.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                Text(
                    if (checked) "Allowed" else "Not allowed",
                    color = c.textSecondary,
                    fontSize = 12.sp,
                    maxLines = 1,
                )
                Icon(
                    painter = painterResource(R.drawable.ic_settings_arrow_down_01),
                    contentDescription = null,
                    tint = c.textSecondary,
                    modifier = Modifier.size(18.dp),
                )
            }
            DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
                DropdownMenuItem(
                    text = { Text("Allow") },
                    onClick = { expanded = false; onCheckedChange(true) },
                    trailingIcon = if (checked) {{ Icon(Icons.Outlined.Check, null) }} else null,
                )
                DropdownMenuItem(
                    text = { Text("Don't allow") },
                    onClick = { expanded = false; onCheckedChange(false) },
                    trailingIcon = if (!checked) {{ Icon(Icons.Outlined.Check, null) }} else null,
                )
            }
        }
    }
}

@Composable
private fun SettingsDangerRow(
    iconRes: Int,
    title: String,
    value: String,
    onClick: () -> Unit,
) {
    val c = LocalAirclipColors.current
    SettingsListRow(
        iconRes = iconRes,
        title = title,
        value = value,
        showArrow = false,
        tint = c.destructive,
        valueColor = c.textSecondary,
        isDestructive = true,
        rowHeight = 105.dp,
        valueMaxLines = 3,
        onClick = onClick,
    )
}

@Composable
private fun SettingsListRow(
    iconRes: Int?,
    title: String,
    value: String,
    showArrow: Boolean,
    onClick: (() -> Unit)?,
    tint: Color? = null,
    valueColor: Color? = null,
    isDestructive: Boolean = false,
    rowHeight: Dp = 73.dp,
    valueMaxLines: Int = 1,
) {
    val c = LocalAirclipColors.current
    val resolvedTint = tint ?: c.textSecondary
    val resolvedValueColor = valueColor ?: resolvedTint
    val clickableModifier = if (onClick != null) {
        Modifier.clickable(role = Role.Button, onClick = onClick)
    } else {
        Modifier
    }

    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(rowHeight)
            .then(clickableModifier),
    ) {
        Row(
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = 20.dp),
            verticalAlignment = if (rowHeight > 73.dp) Alignment.Top else Alignment.CenterVertically,
        ) {
            if (iconRes != null) {
                Icon(
                    painter = painterResource(iconRes),
                    contentDescription = null,
                    tint = resolvedTint,
                    modifier = Modifier
                        .padding(top = if (rowHeight > 73.dp) 12.dp else 0.dp)
                        .size(28.dp),
                )
            } else {
                Spacer(Modifier.size(28.dp))
            }

            Spacer(Modifier.width(23.dp))

            Column(
                modifier = Modifier
                    .padding(top = if (rowHeight > 73.dp) 12.dp else 0.dp)
                    .weight(1f),
            ) {
                Text(
                    title,
                    fontSize = 16.sp,
                    lineHeight = 24.sp,
                    fontWeight = FontWeight.Medium,
                    color = if (isDestructive) c.destructive else c.textPrimary,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
                Spacer(Modifier.height(4.dp))
                Crossfade(targetState = value, animationSpec = tween(120), label = "settings value") { displayedValue ->
                    Text(
                        displayedValue,
                        fontSize = 14.sp,
                        lineHeight = if (isDestructive) 20.sp else 18.sp,
                        fontWeight = FontWeight.Normal,
                        color = resolvedValueColor,
                        maxLines = valueMaxLines,
                        overflow = TextOverflow.Ellipsis,
                    )
                }
            }

            if (showArrow) {
                Spacer(Modifier.width(16.dp))
                Icon(
                    painter = painterResource(R.drawable.ic_settings_arrow_down_01),
                    contentDescription = null,
                    tint = c.textSecondary,
                    modifier = Modifier.size(24.dp),
                )
            }
        }
    }
}

private fun displayAppearance(setting: AppAppearanceSetting): String =
    when (setting) {
        AppAppearanceSetting.SYSTEM -> "System (Default)"
        AppAppearanceSetting.LIGHT -> "Light"
        AppAppearanceSetting.DARK -> "Dark"
    }

private fun displaySyncMode(mode: SyncMode): String =
    when (mode) {
        SyncMode.AUTO -> "Automatic"
        SyncMode.MANUAL_ONLY -> "Manual only"
        SyncMode.PAUSED -> "Paused"
    }
