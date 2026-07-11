package com.airclip.airclip.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.airclip.airclip.AppAppearanceSetting
import com.airclip.airclip.MainViewModel
import com.airclip.airclip.R
import com.airclip.airclip.SensitiveRuleAction
import com.airclip.airclip.SyncMode
import com.airclip.airclip.ui.theme.LocalAirClipColors

private val BearyFontFamily = FontFamily(Font(R.font.beary))
private val SettingsText = Color.Black
private val SettingsMuted = Color(0xFF655B76)
private val SettingsDanger = Color(0xFFD50B0B)
private val SettingsDangerBody = Color(0xFFDC3838)
private val SettingsDivider = Color(0xFFE9EAEC)

@Composable
fun SettingsScreen(viewModel: MainViewModel, uiState: SettingsTabUiState) {
    val c = LocalAirClipColors.current
    var showResetDialog by remember { mutableStateOf(false) }
    val statusBarTop = WindowInsets.statusBars.asPaddingValues().calculateTopPadding()
    val headerHeight = statusBarTop + 88.dp

    val appearanceOptions = listOf("System (Default)", "Light", "Dark")
    val historyOptions = listOf("1 Day", "3 Days", "7 Days", "15 Days", "30 Days", "Forever")
    val syncOptions = listOf("Auto", "Manual", "Paused")
    val sensitiveOptions = listOf("Allowed (Default)", "Ask", "Block")

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
                            "Auto" -> viewModel.onSyncModeChanged(SyncMode.AUTO)
                            "Manual" -> viewModel.onSyncModeChanged(SyncMode.MANUAL_ONLY)
                            "Paused" -> viewModel.onSyncModeChanged(SyncMode.PAUSED)
                        }
                    },
                )
                SettingsSelectableRow(
                    iconRes = R.drawable.ic_settings_security_lock,
                    title = "Sensitive Data Sync",
                    value = displaySensitiveAction(uiState.sensitiveMasterAction),
                    options = sensitiveOptions,
                    onSelect = { label ->
                        when (label) {
                            "Allowed (Default)" -> viewModel.onSensitiveMasterRuleChanged(SensitiveRuleAction.ALLOW)
                            "Ask" -> viewModel.onSensitiveMasterRuleChanged(SensitiveRuleAction.ASK)
                            "Block" -> viewModel.onSensitiveMasterRuleChanged(SensitiveRuleAction.ALWAYS_BLOCK)
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
                    value = "1.2.0",
                )
                SettingsStaticRow(
                    iconRes = R.drawable.ic_settings_wrench_01,
                    title = "Build",
                    value = "2025.1",
                )
            }

            SettingsGroupDivider()

            SettingsGroup {
                SettingsDangerRow(
                    iconRes = R.drawable.ic_settings_logout_03,
                    title = "Leave Network",
                    value = "Disconnect this device from AirClip; keep others connected.",
                    onClick = { showResetDialog = true },
                )
            }

            Spacer(Modifier.height(40.dp))
        }

        SettingsHeader(modifier = Modifier.align(Alignment.TopCenter))
    }

    if (showResetDialog) {
        AlertDialog(
            onDismissRequest = { showResetDialog = false },
            title = { Text("Leave Network?", color = c.textPrimary, fontWeight = FontWeight.SemiBold) },
            text = {
                Text(
                    "This removes this device from AirClip and clears local pairing data. Other devices stay connected.",
                    color = c.textSecondary,
                    style = MaterialTheme.typography.bodySmall,
                )
            },
            confirmButton = {
                TextButton(onClick = { showResetDialog = false; viewModel.onResetAirClip() }) {
                    Text("Leave", color = c.destructive, fontWeight = FontWeight.SemiBold)
                }
            },
            dismissButton = {
                TextButton(onClick = { showResetDialog = false }) {
                    Text("Cancel", color = c.textSecondary)
                }
            },
            containerColor = c.bgFloating,
        )
    }
}

@Composable
private fun SettingsHeader(modifier: Modifier = Modifier) {
    val statusBarTop = WindowInsets.statusBars.asPaddingValues().calculateTopPadding()
    Box(
        modifier = modifier
            .fillMaxWidth()
            .background(Color.White)
            .padding(top = statusBarTop + 24.dp, bottom = 24.dp),
    ) {
        Text(
            "Settings",
            fontSize = 36.sp,
            lineHeight = 40.sp,
            fontFamily = BearyFontFamily,
            fontWeight = FontWeight.Normal,
            color = Color(0xFF202327),
            letterSpacing = (-0.6).sp,
            modifier = Modifier.padding(horizontal = 20.dp),
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
    HorizontalDivider(
        modifier = Modifier.padding(horizontal = 20.dp),
        thickness = 1.dp,
        color = SettingsDivider,
    )
    Spacer(Modifier.height(0.dp))
}

@Composable
private fun SettingsSelectableRow(
    iconRes: Int,
    title: String,
    value: String,
    options: List<String>,
    onSelect: (String) -> Unit,
) {
    var expanded by remember { mutableStateOf(false) }
    Box {
        SettingsListRow(
            iconRes = iconRes,
            title = title,
            value = value,
            showArrow = true,
            onClick = { expanded = true },
        )
        Box(
            modifier = Modifier
                .align(Alignment.CenterEnd)
                .padding(end = 20.dp),
        ) {
            AirClipDropdownMenu(
                expanded = expanded,
                onDismissRequest = { expanded = false },
                selectedLabel = value,
                items = options.map { option ->
                    AirClipDropdownItem(
                        label = option,
                        onClick = { onSelect(option) },
                    )
                },
            )
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
private fun SettingsDangerRow(
    iconRes: Int,
    title: String,
    value: String,
    onClick: () -> Unit,
) {
    SettingsListRow(
        iconRes = iconRes,
        title = title,
        value = value,
        showArrow = false,
        tint = SettingsDanger,
        valueColor = SettingsDangerBody,
        rowHeight = 105.dp,
        valueMaxLines = 3,
        onClick = onClick,
    )
}

@Composable
private fun SettingsListRow(
    iconRes: Int,
    title: String,
    value: String,
    showArrow: Boolean,
    onClick: (() -> Unit)?,
    tint: Color = SettingsMuted,
    valueColor: Color = tint,
    rowHeight: Dp = 73.dp,
    valueMaxLines: Int = 1,
) {
    val interactionSource = remember { MutableInteractionSource() }
    val clickableModifier = if (onClick != null) {
        Modifier.clickable(
            interactionSource = interactionSource,
            indication = null,
            onClick = onClick,
        )
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
            Icon(
                painter = painterResource(iconRes),
                contentDescription = null,
                tint = Color.Unspecified,
                modifier = Modifier
                    .padding(top = if (rowHeight > 73.dp) 12.dp else 0.dp)
                    .size(24.dp),
            )

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
                    color = if (tint == SettingsDanger) SettingsDanger else SettingsText,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
                Spacer(Modifier.height(4.dp))
                Text(
                    value,
                    fontSize = 14.sp,
                    lineHeight = if (tint == SettingsDanger) 20.sp else 14.sp,
                    fontWeight = FontWeight.Normal,
                    color = valueColor,
                    maxLines = valueMaxLines,
                    overflow = TextOverflow.Ellipsis,
                )
            }

            if (showArrow) {
                Spacer(Modifier.width(16.dp))
                Icon(
                    painter = painterResource(R.drawable.ic_settings_arrow_down_01),
                    contentDescription = null,
                    tint = Color.Unspecified,
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
        SyncMode.AUTO -> "Auto"
        SyncMode.MANUAL_ONLY -> "Manual"
        SyncMode.PAUSED -> "Paused"
    }

private fun displaySensitiveAction(action: SensitiveRuleAction): String =
    when (action) {
        SensitiveRuleAction.ALLOW -> "Allowed (Default)"
        SensitiveRuleAction.ASK -> "Ask"
        SensitiveRuleAction.ALWAYS_BLOCK -> "Block"
    }
