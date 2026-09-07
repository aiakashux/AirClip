package com.airclip.airclip.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.RadioButton
import androidx.compose.material3.RadioButtonDefaults
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
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.airclip.airclip.AppAppearanceSetting
import com.airclip.airclip.BuildConfig
import com.airclip.airclip.ClipHistoryStore
import com.airclip.airclip.MainViewModel
import com.airclip.airclip.R
import com.airclip.airclip.SensitiveCategory
import com.airclip.airclip.SensitiveRuleAction
import com.airclip.airclip.SyncMode
import com.airclip.airclip.ui.theme.LocalAirClipColors

private val BearyFontFamily = FontFamily(Font(R.font.beary))
@Composable
fun SettingsScreen(viewModel: MainViewModel, uiState: SettingsTabUiState) {
    val c = LocalAirClipColors.current
    var showResetDialog by remember { mutableStateOf(false) }
    var showClearHistoryDialog by remember { mutableStateOf(false) }
    val statusBarTop = WindowInsets.statusBars.asPaddingValues().calculateTopPadding()
    val headerHeight = statusBarTop + 88.dp

    val appearanceOptions = listOf("System (Default)", "Light", "Dark")
    val historyOptions = listOf(
        "1 Day", "3 Days", "7 Days", "15 Days", "30 Days",
        "No Time Limit (${ClipHistoryStore.MAX_ITEMS})",
    )
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
                if (uiState.sensitiveMasterAction != SensitiveRuleAction.ALLOW) {
                    SensitiveCategory.entries.forEach { category ->
                        SettingsSelectableRow(
                            iconRes = R.drawable.ic_settings_security_lock,
                            title = category.label,
                            value = displaySensitiveAction(
                                uiState.sensitiveRules[category] ?: SensitiveRuleAction.ASK
                            ),
                            options = sensitiveOptions,
                            onSelect = { label ->
                                val action = when (label) {
                                    "Allowed (Default)" -> SensitiveRuleAction.ALLOW
                                    "Block" -> SensitiveRuleAction.ALWAYS_BLOCK
                                    else -> SensitiveRuleAction.ASK
                                }
                                viewModel.onSensitiveRuleChanged(category, action)
                            },
                        )
                    }
                }
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
                    value = BuildConfig.VERSION_NAME,
                )
                SettingsStaticRow(
                    iconRes = R.drawable.ic_settings_wrench_01,
                    title = "Build",
                    value = BuildConfig.VERSION_CODE.toString(),
                )
            }

            SettingsGroupDivider()

            SettingsGroup {
                SettingsDangerRow(
                    iconRes = R.drawable.ic_settings_database_sync,
                    title = "Clear History",
                    value = "Permanently remove every local clip, including saved clips.",
                    onClick = { showClearHistoryDialog = true },
                )
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

    if (showClearHistoryDialog) {
        AlertDialog(
            onDismissRequest = { showClearHistoryDialog = false },
            title = { Text("Clear local history?", color = c.textPrimary, fontWeight = FontWeight.SemiBold) },
            text = {
                Text(
                    "This permanently removes every clipboard item stored on this device, including saved clips.",
                    color = c.textSecondary,
                    style = MaterialTheme.typography.bodySmall,
                )
            },
            confirmButton = {
                TextButton(onClick = {
                    showClearHistoryDialog = false
                    viewModel.onClearHistory()
                }) {
                    Text("Clear History", color = c.destructive, fontWeight = FontWeight.SemiBold)
                }
            },
            dismissButton = {
                TextButton(onClick = { showClearHistoryDialog = false }) {
                    Text("Cancel", color = c.textSecondary)
                }
            },
            containerColor = c.bgFloating,
        )
    }
}

@Composable
private fun SettingsHeader(modifier: Modifier = Modifier) {
    val c = LocalAirClipColors.current
    val statusBarTop = WindowInsets.statusBars.asPaddingValues().calculateTopPadding()
    Box(
        modifier = modifier
            .fillMaxWidth()
            .background(c.bgBase)
            .padding(top = statusBarTop + 24.dp, bottom = 24.dp),
    ) {
        Text(
            "Settings",
            fontSize = 36.sp,
            lineHeight = 40.sp,
            fontFamily = BearyFontFamily,
            fontWeight = FontWeight.Normal,
            color = c.textPrimary,
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
    val c = LocalAirClipColors.current
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
    iconRes: Int,
    title: String,
    value: String,
    options: List<String>,
    onSelect: (String) -> Unit,
) {
    val c = LocalAirClipColors.current
    var expanded by remember { mutableStateOf(false) }
    SettingsListRow(
        iconRes = iconRes,
        title = title,
        value = value,
        showArrow = true,
        onClick = { expanded = true },
    )
    if (expanded) {
        ModalBottomSheet(
            onDismissRequest = { expanded = false },
            containerColor = c.bgFloating,
        ) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .navigationBarsPadding()
                    .padding(bottom = 16.dp),
            ) {
                Text(
                    title,
                    color = c.textPrimary,
                    fontSize = 20.sp,
                    lineHeight = 28.sp,
                    fontWeight = FontWeight.Medium,
                    modifier = Modifier.padding(horizontal = 24.dp, vertical = 12.dp),
                )
                options.forEach { option ->
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable(role = Role.RadioButton) {
                                onSelect(option)
                                expanded = false
                            }
                            .padding(horizontal = 20.dp, vertical = 10.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        RadioButton(
                            selected = option == value,
                            onClick = null,
                            colors = RadioButtonDefaults.colors(selectedColor = c.accent),
                        )
                        Spacer(Modifier.width(12.dp))
                        Text(option, color = c.textPrimary, fontSize = 16.sp)
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
private fun SettingsDangerRow(
    iconRes: Int,
    title: String,
    value: String,
    onClick: () -> Unit,
) {
    val c = LocalAirClipColors.current
    SettingsListRow(
        iconRes = iconRes,
        title = title,
        value = value,
        showArrow = false,
        tint = c.destructive,
        valueColor = c.destructive,
        isDestructive = true,
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
    tint: Color? = null,
    valueColor: Color? = null,
    isDestructive: Boolean = false,
    rowHeight: Dp = 73.dp,
    valueMaxLines: Int = 1,
) {
    val c = LocalAirClipColors.current
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
                    color = if (isDestructive) c.destructive else c.textPrimary,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
                Spacer(Modifier.height(4.dp))
                Text(
                    value,
                    fontSize = 14.sp,
                    lineHeight = if (isDestructive) 20.sp else 14.sp,
                    fontWeight = FontWeight.Normal,
                    color = resolvedValueColor,
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
