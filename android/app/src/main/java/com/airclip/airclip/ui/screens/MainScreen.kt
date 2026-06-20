package com.airclip.airclip.ui.screens

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.unit.dp
import com.airclip.airclip.MainViewModel
import com.airclip.airclip.ui.theme.*

private enum class Tab { CLIPBOARD, DEVICES, SETTINGS }

private data class NavItem(val tab: Tab, val icon: ImageVector, val label: String)

private val navItems = listOf(
    NavItem(Tab.CLIPBOARD, Icons.Outlined.ContentPaste, "Clipboard"),
    NavItem(Tab.DEVICES,   Icons.Outlined.Devices,      "Devices"),
    NavItem(Tab.SETTINGS,  Icons.Outlined.Settings,     "Settings"),
)

@Composable
fun MainScreen(viewModel: MainViewModel, uiState: MainViewModel.UiState) {
    var currentTab by remember { mutableStateOf(Tab.CLIPBOARD) }
    val snackbarHostState = remember { SnackbarHostState() }

    LaunchedEffect(uiState.sensitiveBlockedNotice) {
        val finding = uiState.sensitiveBlockedNotice ?: return@LaunchedEffect
        snackbarHostState.showSnackbar(
            message = "${finding.category.label} blocked. Kept on this device.",
            withDismissAction = true,
        )
        viewModel.onSensitiveBlockedNoticeShown()
    }

    Scaffold(
        snackbarHost = { SnackbarHost(snackbarHostState) },
        bottomBar = {
            Surface(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 14.dp, vertical = 12.dp),
                shape = RoundedCornerShape(22.dp),
                color = AirClipBgFloating,
                tonalElevation = 0.dp,
                shadowElevation = 0.dp,
                border = BorderStroke(0.5.dp, AirClipBorderSubtle),
            ) {
                NavigationBar(
                    containerColor = Color.Transparent,
                    tonalElevation = 0.dp,
                ) {
                    navItems.forEach { item ->
                        NavigationBarItem(
                            selected = currentTab == item.tab,
                            onClick  = { currentTab = item.tab },
                            icon = {
                                Icon(
                                    imageVector = item.icon,
                                    contentDescription = item.label,
                                    modifier = Modifier.size(22.dp),
                                )
                            },
                            label = { Text(item.label, style = MaterialTheme.typography.labelSmall) },
                            colors = NavigationBarItemDefaults.colors(
                                selectedIconColor   = AirClipGreen,
                                selectedTextColor   = AirClipTextPrimary,
                                unselectedIconColor = AirClipTextTertiary,
                                unselectedTextColor = AirClipTextTertiary,
                                indicatorColor      = AirClipSelectionFill,
                            ),
                        )
                    }
                }
            }
        },
        containerColor = AirClipBgBase,
    ) { padding ->
        Box(modifier = Modifier.fillMaxSize().padding(padding)) {
            when (currentTab) {
                Tab.CLIPBOARD -> ClipboardScreen(viewModel, uiState)
                Tab.DEVICES   -> DevicesScreen(viewModel, uiState)
                Tab.SETTINGS  -> SettingsScreen(viewModel, uiState)
            }
        }
    }

    uiState.pendingSensitiveFinding?.let { finding ->
        AlertDialog(
            onDismissRequest = viewModel::onCancelSensitiveSend,
            icon = {
                Icon(
                    Icons.Outlined.WarningAmber,
                    contentDescription = null,
                    tint = AirClipYellow,
                )
            },
            title = {
                Text("Send sensitive clipboard item?", color = AirClipTextPrimary)
            },
            text = {
                Text(
                    "${finding.category.label} detected. Only continue if you intend to share it with your paired devices.",
                    color = AirClipTextSecondary,
                    style = MaterialTheme.typography.bodySmall,
                )
            },
            confirmButton = {
                TextButton(onClick = viewModel::onConfirmSensitiveSend) {
                    Text("Send anyway", color = AirClipDestructive)
                }
            },
            dismissButton = {
                TextButton(onClick = viewModel::onCancelSensitiveSend) {
                    Text("Cancel", color = AirClipTextSecondary)
                }
            },
            containerColor = AirClipBgFloating,
        )
    }
}
