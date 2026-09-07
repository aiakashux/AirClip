package com.airclip.airclip.ui.screens

import androidx.annotation.DrawableRes
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.scaleOut
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.LocalIndication
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.airclip.airclip.AppAppearanceSetting
import com.airclip.airclip.ClipItemRecord
import com.airclip.airclip.PairedDevice
import com.airclip.airclip.R
import com.airclip.airclip.MainViewModel
import com.airclip.airclip.SensitiveCategory
import com.airclip.airclip.SensitiveRuleAction
import com.airclip.airclip.SyncMode
import com.airclip.airclip.lan.LanRuntimeDiagnostic
import com.airclip.airclip.ui.theme.*
import kotlinx.coroutines.delay

private enum class Tab { HOME, DEVICES, SETTINGS }

private data class NavItem(
    val tab: Tab,
    @DrawableRes val iconRes: Int,
    @DrawableRes val activeIconRes: Int,
    val label: String,
)

private val navItems = listOf(
    NavItem(Tab.HOME, R.drawable.ic_nav_home_06_stroke, R.drawable.ic_nav_home_06_solid, "Home"),
    NavItem(Tab.DEVICES, R.drawable.ic_nav_devices_sync_stroke, R.drawable.ic_nav_devices_sync_solid, "Devices"),
    NavItem(Tab.SETTINGS, R.drawable.ic_nav_settings_01_stroke, R.drawable.ic_nav_settings_01_solid, "Settings"),
)

@Immutable
data class ClipboardTabUiState(
    val clipHistory: List<ClipItemRecord>,
    val syncMode: SyncMode,
)

@Immutable
data class DevicesTabUiState(
    val pairedDevices: List<PairedDevice>,
    val connectedPeerCount: Int,
    val myDeviceId: String?,
    val syncMode: SyncMode,
    val lanRuntimeDiagnostic: LanRuntimeDiagnostic,
)

@Immutable
data class SettingsTabUiState(
    val appearanceSetting: AppAppearanceSetting,
    val historyDepth: Int,
    val syncMode: SyncMode,
    val sensitiveMasterAction: SensitiveRuleAction,
    val sensitiveRules: Map<SensitiveCategory, SensitiveRuleAction>,
)

@Composable
fun MainScreen(viewModel: MainViewModel, uiState: MainViewModel.UiState) {
    val c = LocalAirClipColors.current
    var currentTab by remember {
        mutableStateOf(if (uiState.openDevicesOnFirstLaunch) Tab.DEVICES else Tab.HOME)
    }
    val snackbarHostState = remember { SnackbarHostState() }
    var showDeviceAddedToast by remember { mutableStateOf(false) }
    val homeListState = rememberLazyListState()
    val devicesListState = rememberLazyListState()
    val clipboardTabState = remember(uiState.clipHistory, uiState.syncMode) {
        ClipboardTabUiState(
            clipHistory = uiState.clipHistory,
            syncMode = uiState.syncMode,
        )
    }
    val devicesTabState = remember(
        uiState.pairedDevices,
        uiState.connectedPeerCount,
        uiState.myDeviceId,
        uiState.syncMode,
        uiState.lanRuntimeDiagnostic,
    ) {
        DevicesTabUiState(
            pairedDevices = uiState.pairedDevices,
            connectedPeerCount = uiState.connectedPeerCount,
            myDeviceId = uiState.myDeviceId,
            syncMode = uiState.syncMode,
            lanRuntimeDiagnostic = uiState.lanRuntimeDiagnostic,
        )
    }
    val settingsTabState = remember(
        uiState.appearanceSetting,
        uiState.historyDepth,
        uiState.syncMode,
        uiState.sensitiveMasterAction,
        uiState.sensitiveRules,
    ) {
        SettingsTabUiState(
            appearanceSetting = uiState.appearanceSetting,
            historyDepth = uiState.historyDepth,
            syncMode = uiState.syncMode,
            sensitiveMasterAction = uiState.sensitiveMasterAction,
            sensitiveRules = uiState.sensitiveRules,
        )
    }
    LaunchedEffect(uiState.openDevicesOnFirstLaunch) {
        if (uiState.openDevicesOnFirstLaunch) {
            currentTab = Tab.DEVICES
            viewModel.onInitialDevicesTabShown()
        }
    }

    LaunchedEffect(uiState.sensitiveBlockedNotice) {
        val finding = uiState.sensitiveBlockedNotice ?: return@LaunchedEffect
        snackbarHostState.showSnackbar(
            message = "${finding.category.label} blocked. Kept on this device.",
            withDismissAction = true,
        )
        viewModel.onSensitiveBlockedNoticeShown()
    }

    LaunchedEffect(uiState.deviceAddedToastId) {
        if (uiState.deviceAddedToastId == 0L) return@LaunchedEffect
        showDeviceAddedToast = true
        delay(1_800)
        showDeviceAddedToast = false
        viewModel.onDeviceAddedToastShown()
    }

    Scaffold(
        snackbarHost = { SnackbarHost(snackbarHostState) },
        bottomBar = {
            AirClipBottomNavigation(
                currentTab = currentTab,
                onTabSelected = { currentTab = it },
            )
        },
        containerColor = c.bgBase,
        contentWindowInsets = WindowInsets(0.dp),
    ) { padding ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding),
        ) {
            when (currentTab) {
                Tab.HOME     -> ClipboardScreen(viewModel, clipboardTabState, listState = homeListState)
                Tab.DEVICES  -> DevicesScreen(viewModel, devicesTabState, listState = devicesListState)
                Tab.SETTINGS -> SettingsScreen(viewModel, settingsTabState)
            }

            DeviceAddedToast(
                visible = showDeviceAddedToast,
                modifier = Modifier
                    .align(Alignment.BottomCenter)
                    .padding(bottom = 24.dp),
            )
        }
    }

    uiState.pendingSensitiveFinding?.let { finding ->
        AlertDialog(
            onDismissRequest = viewModel::onCancelSensitiveSend,
            icon = { Icon(Icons.Outlined.WarningAmber, null, tint = c.yellow) },
            title = { Text("Send sensitive clipboard item?", color = c.textPrimary) },
            text = {
                Text(
                    "${finding.category.label} detected. Only continue if you intend to share it with your paired devices.",
                    color = c.textSecondary,
                    style = MaterialTheme.typography.bodySmall,
                )
            },
            confirmButton = {
                TextButton(onClick = viewModel::onConfirmSensitiveSend) {
                    Text("Send anyway", color = c.destructive)
                }
            },
            dismissButton = {
                TextButton(onClick = viewModel::onCancelSensitiveSend) {
                    Text("Cancel", color = c.textSecondary)
                }
            },
            containerColor = c.bgFloating,
        )
    }
}

@Composable
private fun DeviceAddedToast(
    visible: Boolean,
    modifier: Modifier = Modifier,
) {
    val c = LocalAirClipColors.current

    AnimatedVisibility(
        visible = visible,
        modifier = modifier,
        enter = fadeIn(tween(120)) +
                scaleIn(
                    animationSpec = spring(
                        dampingRatio = Spring.DampingRatioNoBouncy,
                        stiffness = Spring.StiffnessMediumLow,
                    ),
                    initialScale = 0.96f,
                ),
        exit = fadeOut(tween(160)) +
                scaleOut(animationSpec = tween(160), targetScale = 0.96f),
    ) {
        Box(
            modifier = Modifier
                .clip(RoundedCornerShape(percent = 50))
                .background(c.bgFloating.copy(alpha = 0.94f))
                .border(0.5.dp, c.borderSubtle, RoundedCornerShape(percent = 50))
                .padding(horizontal = 16.dp, vertical = 9.dp),
            contentAlignment = Alignment.Center,
        ) {
            Text(
                text = "New device added",
                style = MaterialTheme.typography.labelLarge,
                color = c.textPrimary,
            )
        }
    }
}

@Composable
private fun AirClipBottomNavigation(
    currentTab: Tab,
    onTabSelected: (Tab) -> Unit,
) {
    val c = LocalAirClipColors.current
    val navigationBarBottom = WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding()

    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(64.dp + navigationBarBottom)
            .background(c.bgBase),
    ) {
        HorizontalDivider(
            modifier = Modifier.align(Alignment.TopCenter),
            thickness = 1.dp,
            color = c.borderSubtle,
        )
        Row(
            modifier = Modifier
                .align(Alignment.TopCenter)
                .fillMaxWidth()
                .height(64.dp),
        ) {
            navItems.forEach { item ->
                AirClipBottomNavigationItem(
                    item = item,
                    isSelected = currentTab == item.tab,
                    onClick = { onTabSelected(item.tab) },
                    modifier = Modifier.weight(1f),
                )
            }
        }
    }
}

@Composable
private fun AirClipBottomNavigationItem(
    item: NavItem,
    isSelected: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val c = LocalAirClipColors.current
    val itemColor = if (isSelected) c.blue else c.textSecondary
    Column(
        modifier = modifier
            .fillMaxHeight()
            .semantics { selected = isSelected }
            .clickable(
                interactionSource = remember { MutableInteractionSource() },
                indication = LocalIndication.current,
                role = Role.Tab,
                onClick = onClick,
            )
            .padding(top = 6.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Box(
            modifier = Modifier
                .size(width = 56.dp, height = 32.dp)
                .clip(RoundedCornerShape(16.dp))
                .background(if (isSelected) c.activeFill else Color.Transparent),
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                painter = painterResource(id = if (isSelected) item.activeIconRes else item.iconRes),
                contentDescription = item.label,
                modifier = Modifier.size(24.dp),
                tint = itemColor,
            )
        }
        Spacer(modifier = Modifier.height(4.dp))
        Text(
            text = item.label,
            modifier = Modifier.fillMaxWidth(),
            color = itemColor,
            fontSize = 12.sp,
            lineHeight = 16.sp,
            fontWeight = FontWeight.Medium,
            textAlign = TextAlign.Center,
        )
    }
}
