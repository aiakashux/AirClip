package com.airclip.airclip.ui.screens

import android.graphics.Bitmap
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.BorderStroke
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.*
import androidx.compose.material.icons.automirrored.outlined.ExitToApp
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.airclip.airclip.MainViewModel
import com.airclip.airclip.SensitiveCategory
import com.airclip.airclip.SensitiveRuleAction
import com.airclip.airclip.SyncMode
import com.airclip.airclip.ui.theme.*

@Composable
fun SettingsScreen(viewModel: MainViewModel, uiState: MainViewModel.UiState) {
    var showSignOutDialog by remember { mutableStateOf(false) }
    var historyDays by remember { mutableStateOf(30) }
    var deviceNameDraft by remember(uiState.deviceName) { mutableStateOf(uiState.deviceName) }
    val isPairingVisible = uiState.isPairingWaiting

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState()),
    ) {
        // Header
        Text(
            "Settings",
            style = MaterialTheme.typography.titleLarge,
            color = AirClipTextPrimary,
            modifier = Modifier
                .padding(horizontal = 20.dp)
                .padding(top = 20.dp, bottom = 20.dp),
        )

        // ── Account card ────────────────────────────────────────────────────
        AirClipCard(deviceName = uiState.deviceName, myDeviceId = uiState.myDeviceId)

        Spacer(Modifier.height(24.dp))

        // ── Profile section ─────────────────────────────────────────────────
        SectionHeader("Account")

        SettingsGroup {
            Column(modifier = Modifier.padding(16.dp)) {
                Text(
                    "Device name",
                    style = MaterialTheme.typography.labelMedium,
                    color = AirClipTextTertiary,
                )
                Spacer(Modifier.height(8.dp))
                AirClipTextField(
                    value = deviceNameDraft,
                    onValueChange = { deviceNameDraft = it },
                    placeholder = "This device",
                    label = "Name",
                )
                Spacer(Modifier.height(12.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    Button(
                        onClick = { viewModel.onRenameDevice(deviceNameDraft) },
                        enabled = deviceNameDraft.trim().isNotEmpty(),
                        colors = ButtonDefaults.buttonColors(
                            containerColor = AirClipAccent,
                            contentColor = Color.White,
                            disabledContainerColor = AirClipAccent.copy(alpha = 0.36f),
                            disabledContentColor = Color.White.copy(alpha = 0.7f),
                        ),
                    ) {
                        Text("Save name")
                    }
                    TextButton(
                        onClick = { deviceNameDraft = uiState.deviceName },
                        contentPadding = PaddingValues(horizontal = 12.dp, vertical = 8.dp),
                    ) {
                        Text("Reset", color = AirClipTextSecondary)
                    }
                }

                Spacer(Modifier.height(14.dp))
                SettingsDivider()
                Spacer(Modifier.height(14.dp))

                Row(
                    modifier = Modifier.fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Icon(Icons.Outlined.Tag, null, tint = AirClipTextSecondary, modifier = Modifier.size(18.dp))
                    Spacer(Modifier.width(12.dp))
                    Text(
                        "AirClip ID",
                        style = MaterialTheme.typography.bodyMedium,
                        color = AirClipTextPrimary,
                    )
                    Spacer(Modifier.weight(1f))
                    Text(
                        uiState.myDeviceId?.take(8)?.lowercase()?.plus("…") ?: "Not paired",
                        style = MaterialTheme.typography.labelSmall.copy(fontFamily = FontFamily.Monospace),
                        color = AirClipTextTertiary,
                    )
                }
            }
        }

        Spacer(Modifier.height(24.dp))

        // ── Devices section ─────────────────────────────────────────────────
        SectionHeader("Devices")

        SettingsGroup {
            ActionRow(
                icon = Icons.Outlined.AddCircleOutline,
                label = "Add device to AirClip",
                onClick = { viewModel.onStartPairingSession() },
            )
            SettingsDivider()
            InfoRow(
                icon = Icons.Outlined.Devices,
                label = "Paired devices",
                value = uiState.pairedDevices.size.toString(),
            )
        }

        Spacer(Modifier.height(24.dp))

        // ── Sync section ─────────────────────────────────────────────────────
        SectionHeader("Sync")

        SettingsGroup {
            Column(modifier = Modifier.padding(16.dp)) {
                Text(
                    "Sync mode",
                    style = MaterialTheme.typography.labelMedium,
                    color = AirClipTextTertiary,
                )
                Spacer(Modifier.height(10.dp))
                SyncModeSelector(
                    selectedMode = uiState.syncMode,
                    onSelect = viewModel::onSyncModeChanged,
                )
            }
        }

        Spacer(Modifier.height(24.dp))

        // ── History section ──────────────────────────────────────────────────
        SectionHeader("History")

        SettingsGroup {
            HistoryDepthRow(
                days = historyDays,
                onSelect = { historyDays = it },
            )
        }

        Spacer(Modifier.height(24.dp))

        // ── Security section ─────────────────────────────────────────────────
        SectionHeader("Security")

        SettingsGroup {
            InfoRow(
                icon = Icons.Outlined.Lock,
                label = "End-to-end encryption",
                value = "Enabled",
                valueColor = AirClipGreen,
            )
            SettingsDivider()
            Column(modifier = Modifier.padding(vertical = 4.dp)) {
                Text(
                    "Sensitive clipboard protection",
                    style = MaterialTheme.typography.labelMedium,
                    color = AirClipTextTertiary,
                    modifier = Modifier.padding(horizontal = 16.dp, vertical = 10.dp),
                )
                SensitiveCategory.entries.forEachIndexed { index, category ->
                    SensitiveRuleRow(
                        category = category,
                        action = uiState.sensitiveRules[category] ?: SensitiveRuleAction.ASK,
                        onSelect = { viewModel.onSensitiveRuleChanged(category, it) },
                    )
                    if (index < SensitiveCategory.entries.lastIndex) {
                        SettingsDivider()
                    }
                }
                Text(
                    "Ask blocks automatic sync and confirms explicit sends.",
                    style = MaterialTheme.typography.labelSmall,
                    color = AirClipTextTertiary,
                    modifier = Modifier.padding(horizontal = 16.dp, vertical = 10.dp),
                )
            }
        }

        Spacer(Modifier.height(24.dp))

        // ── AirClip actions ─────────────────────────────────────────────────────
        SectionHeader("AirClip")

        SettingsGroup {
            ActionRow(
                icon = Icons.AutoMirrored.Outlined.ExitToApp,
                label = "Reset AirClip network",
                labelColor = AirClipDestructive,
                onClick = { showSignOutDialog = true },
            )
        }

        Spacer(Modifier.height(32.dp))
    }

    if (isPairingVisible) {
        PairingDialog(
            qrBitmap = uiState.pairingQr,
            pairingCode = uiState.pairingCode,
            onCancel = {
                viewModel.onCancelPairing()
            },
            onRefresh = { viewModel.onRefreshPairingCode() },
        )
    }

    // Reset confirmation
    if (showSignOutDialog) {
        AlertDialog(
            onDismissRequest = { showSignOutDialog = false },
            title = { Text("Reset AirClip?", color = AirClipTextPrimary) },
            text = {
                Text(
                    "This will remove all pairings and clipboard history from this device. You'll need to create or join a AirClip again.",
                    color = AirClipTextSecondary,
                    style = MaterialTheme.typography.bodySmall,
                )
            },
            confirmButton = {
                TextButton(
                    onClick = { showSignOutDialog = false; viewModel.onResetAirClip() },
                ) {
                    Text("Reset", color = AirClipDestructive)
                }
            },
            dismissButton = {
                TextButton(onClick = { showSignOutDialog = false }) {
                    Text("Cancel", color = AirClipTextSecondary)
                }
            },
            containerColor = AirClipBgFloating,
            titleContentColor = AirClipTextPrimary,
        )
    }
}

@Composable
private fun SyncModeSelector(
    selectedMode: SyncMode,
    onSelect: (SyncMode) -> Unit,
) {
    val options = listOf(
        SyncMode.AUTO to "Auto",
        SyncMode.MANUAL_ONLY to "Manual",
        SyncMode.PAUSED to "Paused",
    )
    val shape = RoundedCornerShape(10.dp)

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .height(44.dp)
            .clip(shape)
            .border(0.5.dp, AirClipBorderDefault, shape),
    ) {
        options.forEachIndexed { index, (mode, label) ->
            val isSelected = selectedMode == mode
            Box(
                modifier = Modifier
                    .weight(1f)
                    .fillMaxHeight()
                    .background(if (isSelected) AirClipSelectionFill else Color.Transparent)
                    .clickable { onSelect(mode) },
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    label,
                    style = MaterialTheme.typography.labelLarge,
                    color = if (isSelected) AirClipGreen else AirClipTextSecondary,
                )
            }

            if (index < options.lastIndex) {
                VerticalDivider(
                    color = AirClipBorderSubtle,
                    thickness = 0.5.dp,
                )
            }
        }
    }
}

@Composable
private fun SensitiveRuleRow(
    category: SensitiveCategory,
    action: SensitiveRuleAction,
    onSelect: (SensitiveRuleAction) -> Unit,
) {
    var expanded by remember { mutableStateOf(false) }

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 6.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            category.label,
            style = MaterialTheme.typography.bodyMedium,
            color = AirClipTextPrimary,
            modifier = Modifier.weight(1f),
        )
        Box {
            TextButton(
                onClick = { expanded = true },
                contentPadding = PaddingValues(horizontal = 8.dp, vertical = 4.dp),
            ) {
                Text(
                    action.label,
                    style = MaterialTheme.typography.labelLarge,
                    color = when (action) {
                        SensitiveRuleAction.ALWAYS_BLOCK -> AirClipDestructive
                        SensitiveRuleAction.ASK -> AirClipAccent
                        SensitiveRuleAction.ALLOW -> AirClipTextSecondary
                    },
                )
                Spacer(Modifier.width(4.dp))
                Icon(
                    Icons.Outlined.ArrowDropDown,
                    contentDescription = "Change ${category.label} protection",
                    tint = AirClipTextTertiary,
                    modifier = Modifier.size(16.dp),
                )
            }
            DropdownMenu(
                expanded = expanded,
                onDismissRequest = { expanded = false },
            ) {
                SensitiveRuleAction.entries.forEach { option ->
                    DropdownMenuItem(
                        text = {
                            Text(
                                option.label,
                                color = if (option == action) AirClipAccent else AirClipTextPrimary,
                            )
                        },
                        onClick = {
                            onSelect(option)
                            expanded = false
                        },
                    )
                }
            }
        }
    }
}

@Composable
private fun PairingDialog(
    qrBitmap: Bitmap?,
    pairingCode: String?,
    onCancel: () -> Unit,
    onRefresh: () -> Unit,
) {
    Dialog(onDismissRequest = onCancel) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(22.dp))
                .background(AirClipBgFloating)
                .border(0.5.dp, AirClipBorderSubtle, RoundedCornerShape(22.dp))
                .padding(20.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Text(
                "Add device to AirClip",
                style = MaterialTheme.typography.titleMedium,
                color = AirClipTextPrimary,
            )
            Spacer(Modifier.height(6.dp))
            Text(
                "Scan this code from another device to pair it with the same AirClip network.",
                style = MaterialTheme.typography.bodySmall,
                color = AirClipTextSecondary,
                textAlign = androidx.compose.ui.text.style.TextAlign.Center,
            )

            Spacer(Modifier.height(18.dp))

            if (qrBitmap != null) {
                Image(
                    bitmap = qrBitmap.asImageBitmap(),
                    contentDescription = "Pairing QR code",
                    modifier = Modifier
                        .size(190.dp)
                        .clip(RoundedCornerShape(18.dp))
                        .background(Color.White),
                )
            } else {
                Box(
                    modifier = Modifier
                        .size(190.dp)
                        .clip(RoundedCornerShape(18.dp))
                        .background(AirClipBgElevated),
                    contentAlignment = Alignment.Center,
                ) {
                    CircularProgressIndicator(
                        color = AirClipAccent,
                        strokeWidth = 2.dp,
                        modifier = Modifier.size(24.dp),
                    )
                }
            }

            Spacer(Modifier.height(16.dp))

            if (!pairingCode.isNullOrBlank()) {
                Text(
                    pairingCode,
                    style = MaterialTheme.typography.headlineSmall.copy(fontFamily = FontFamily.Monospace),
                    color = AirClipTextPrimary,
                )
                Spacer(Modifier.height(4.dp))
                Text(
                    "Refreshes automatically",
                    style = MaterialTheme.typography.labelSmall,
                    color = AirClipTextTertiary,
                )
            }

            Spacer(Modifier.height(18.dp))

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                OutlinedButton(
                    onClick = onCancel,
                    modifier = Modifier.weight(1f),
                    colors = ButtonDefaults.outlinedButtonColors(contentColor = AirClipTextSecondary),
                    border = BorderStroke(0.5.dp, AirClipBorderDefault),
                ) {
                    Text("Cancel")
                }
                Button(
                    onClick = onRefresh,
                    modifier = Modifier.weight(1f),
                    colors = ButtonDefaults.buttonColors(
                        containerColor = AirClipAccent,
                        contentColor = Color.White,
                    ),
                ) {
                    Text("Refresh code")
                }
            }
        }
    }
}

// ── AirClip card ─────────────────────────────────────────────────────────────────

@Composable
private fun AirClipCard(deviceName: String, myDeviceId: String?) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp)
            .clip(RoundedCornerShape(14.dp))
            .background(AirClipBgElevated)
            .border(0.5.dp, AirClipBorderSubtle, RoundedCornerShape(14.dp))
            .padding(16.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Box(
            modifier = Modifier
                .size(44.dp)
                .clip(CircleShape)
                .background(
                    Brush.linearGradient(colors = listOf(Color(0xFF6C34F8), Color(0xFFFF6363)))
                ),
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                Icons.Outlined.RadioButtonChecked,
                null,
                tint = Color.White,
                modifier = Modifier.size(22.dp),
            )
        }

        Column(modifier = Modifier.weight(1f)) {
            Text(
                deviceName.ifBlank { "This device" },
                style = MaterialTheme.typography.bodyMedium,
                color = AirClipTextPrimary,
            )
            Spacer(Modifier.height(3.dp))
            Text(
                myDeviceId?.take(8)?.let { "ID: $it…" } ?: "Not paired",
                style = MaterialTheme.typography.labelSmall.copy(fontFamily = FontFamily.Monospace),
                color = AirClipTextTertiary,
            )
        }
    }
}

// ── Settings rows ─────────────────────────────────────────────────────────────

@Composable
private fun SettingsGroup(content: @Composable ColumnScope.() -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp)
            .clip(RoundedCornerShape(14.dp))
            .background(AirClipBgElevated)
            .border(0.5.dp, AirClipBorderSubtle, RoundedCornerShape(14.dp)),
        content = content,
    )
}

@Composable
private fun ToggleRow(
    icon: ImageVector,
    label: String,
    checked: Boolean,
    onCheckedChange: (Boolean) -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 14.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(icon, null, tint = AirClipTextSecondary, modifier = Modifier.size(18.dp))
        Spacer(Modifier.width(12.dp))
        Text(
            label,
            style = MaterialTheme.typography.bodyMedium,
            color = AirClipTextPrimary,
            modifier = Modifier.weight(1f),
        )
        Switch(
            checked = checked,
            onCheckedChange = onCheckedChange,
            modifier = Modifier.height(24.dp),
            colors = SwitchDefaults.colors(
                checkedThumbColor  = Color.White,
                checkedTrackColor  = AirClipAccent,
                uncheckedThumbColor = AirClipTextTertiary,
                uncheckedTrackColor = AirClipBgFloating,
                uncheckedBorderColor = AirClipBorderDefault,
            ),
        )
    }
}

@Composable
private fun HistoryDepthRow(days: Int, onSelect: (Int) -> Unit) {
    var showPicker by remember { mutableStateOf(false) }

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 14.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(Icons.Outlined.History, null, tint = AirClipTextSecondary, modifier = Modifier.size(18.dp))
        Spacer(Modifier.width(12.dp))
        Text(
            "Keep history for",
            style = MaterialTheme.typography.bodyMedium,
            color = AirClipTextPrimary,
            modifier = Modifier.weight(1f),
        )
        TextButton(
            onClick = { showPicker = true },
            contentPadding = PaddingValues(horizontal = 8.dp, vertical = 4.dp),
        ) {
            Text(
                if (days == 0) "Forever" else "$days days",
                style = MaterialTheme.typography.labelLarge,
                color = AirClipTextSecondary,
            )
            Spacer(Modifier.width(4.dp))
            Icon(Icons.Outlined.ArrowDropDown, null, tint = AirClipTextTertiary, modifier = Modifier.size(16.dp))
        }
    }

    if (showPicker) {
        AlertDialog(
            onDismissRequest = { showPicker = false },
            title = { Text("Keep history for", color = AirClipTextPrimary) },
            text = {
                Column {
                    listOf(7, 30, 90).forEach { d ->
                        TextButton(
                            onClick = { onSelect(d); showPicker = false },
                            modifier = Modifier.fillMaxWidth(),
                        ) {
                            Text(
                                "$d days",
                                color = if (d == days) AirClipAccent else AirClipTextPrimary,
                                modifier = Modifier.fillMaxWidth(),
                            )
                        }
                    }
                    TextButton(
                        onClick = { onSelect(0); showPicker = false },
                        modifier = Modifier.fillMaxWidth(),
                    ) {
                        Text(
                            "Forever",
                            color = if (days == 0) AirClipAccent else AirClipTextPrimary,
                            modifier = Modifier.fillMaxWidth(),
                        )
                    }
                }
            },
            confirmButton = {},
            containerColor = AirClipBgFloating,
        )
    }
}

@Composable
private fun InfoRow(
    icon: ImageVector,
    label: String,
    value: String,
    valueColor: Color = AirClipTextSecondary,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 14.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(icon, null, tint = AirClipTextSecondary, modifier = Modifier.size(18.dp))
        Spacer(Modifier.width(12.dp))
        Text(
            label,
            style = MaterialTheme.typography.bodyMedium,
            color = AirClipTextPrimary,
            modifier = Modifier.weight(1f),
        )
        Text(value, style = MaterialTheme.typography.bodySmall, color = valueColor)
    }
}

@Composable
private fun ActionRow(
    icon: ImageVector,
    label: String,
    labelColor: Color = AirClipTextPrimary,
    onClick: () -> Unit,
) {
    TextButton(
        onClick = onClick,
        modifier = Modifier.fillMaxWidth(),
        contentPadding = PaddingValues(horizontal = 16.dp, vertical = 14.dp),
        shape = RoundedCornerShape(0.dp),
    ) {
        Icon(icon, null, tint = labelColor, modifier = Modifier.size(18.dp))
        Spacer(Modifier.width(12.dp))
        Text(
            label,
            style = MaterialTheme.typography.bodyMedium,
            color = labelColor,
            modifier = Modifier.weight(1f),
        )
    }
}

@Composable
private fun SettingsDivider() {
    HorizontalDivider(
        modifier = Modifier.padding(start = 46.dp),
        thickness = 0.5.dp,
        color = AirClipBorderSubtle,
    )
}

@Composable
private fun SectionHeader(title: String) {
    Text(
        title,
        style = MaterialTheme.typography.labelMedium,
        color = AirClipTextTertiary,
        modifier = Modifier
            .padding(horizontal = 20.dp)
            .padding(bottom = 6.dp),
    )
}
