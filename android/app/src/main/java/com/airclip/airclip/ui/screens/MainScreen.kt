package com.airclip.airclip.ui.screens

import androidx.annotation.DrawableRes
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.Crossfade
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.CubicBezierEasing
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
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
    val remoteInsertionId: String?,
)

@Immutable
data class DevicesTabUiState(
    val spaceName: String,
    val pairedDevices: List<PairedDevice>,
    val connectedPeerCount: Int,
    val myDeviceId: String?,
    val syncMode: SyncMode,
    val lanRuntimeDiagnostic: LanRuntimeDiagnostic,
    val pairingError: String?,
)

@Immutable
data class SettingsTabUiState(
    val appearanceSetting: AppAppearanceSetting,
    val historyDepth: Int,
    val syncMode: SyncMode,
    val analyticsEnabled: Boolean,
    val updateStatus: String?,
    val isLastDeviceInSpace: Boolean,
)

@Composable
fun MainScreen(viewModel: MainViewModel, uiState: MainViewModel.UiState) {
    val c = LocalAirclipColors.current
    var showDeviceCodeInput by remember { mutableStateOf(false) }
    var currentTab by remember {
        mutableStateOf(if (uiState.openDevicesOnFirstLaunch) Tab.DEVICES else Tab.HOME)
    }
    val alertHostState = rememberAirclipAlertHostState()
    val homeListState = rememberLazyListState()
    val devicesListState = rememberLazyListState()
    val clipboardTabState = remember(uiState.clipHistory, uiState.syncMode) {
        ClipboardTabUiState(
            clipHistory = uiState.clipHistory,
            syncMode = uiState.syncMode,
            remoteInsertionId = uiState.remoteInsertionId,
        )
    }
    val devicesTabState = remember(
        uiState.pairedDevices,
        uiState.spaceName,
        uiState.connectedPeerCount,
        uiState.myDeviceId,
        uiState.syncMode,
        uiState.lanRuntimeDiagnostic,
        uiState.lastError,
    ) {
        DevicesTabUiState(
            spaceName = uiState.spaceName,
            pairedDevices = uiState.pairedDevices,
            connectedPeerCount = uiState.connectedPeerCount,
            myDeviceId = uiState.myDeviceId,
            syncMode = uiState.syncMode,
            lanRuntimeDiagnostic = uiState.lanRuntimeDiagnostic,
            pairingError = uiState.lastError,
        )
    }
    val settingsTabState = remember(
        uiState.appearanceSetting,
        uiState.historyDepth,
        uiState.syncMode,
        uiState.analyticsEnabled,
        uiState.updateStatus,
        uiState.pairedDevices,
    ) {
        SettingsTabUiState(
            appearanceSetting = uiState.appearanceSetting,
            historyDepth = uiState.historyDepth,
            syncMode = uiState.syncMode,
            analyticsEnabled = uiState.analyticsEnabled,
            updateStatus = uiState.updateStatus,
            isLastDeviceInSpace = uiState.pairedDevices.isEmpty(),
        )
    }
    LaunchedEffect(uiState.openDevicesOnFirstLaunch) {
        if (uiState.openDevicesOnFirstLaunch) {
            currentTab = Tab.DEVICES
            viewModel.onInitialDevicesTabShown()
        }
    }

    CompositionLocalProvider(LocalAirclipAlertHostState provides alertHostState) {
        Scaffold(
            bottomBar = {
                AnimatedVisibility(
                    visible = !showDeviceCodeInput,
                    enter = fadeIn(tween(120, easing = CubicBezierEasing(0.23f, 1f, 0.32f, 1f))),
                    exit = fadeOut(tween(120)),
                ) {
                    AirclipBottomNavigation(
                        currentTab = currentTab,
                        onTabSelected = { tab -> currentTab = tab },
                    )
                }
            },
            containerColor = c.bgBase,
            contentWindowInsets = WindowInsets(0.dp),
        ) { padding ->
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(padding),
            ) {
                AnimatedContent(
                    targetState = currentTab,
                    transitionSpec = {
                        fadeIn(tween(150, easing = CubicBezierEasing(0.23f, 1f, 0.32f, 1f))) togetherWith
                            fadeOut(tween(120))
                    },
                    label = "main tabs",
                ) { tab ->
                    when (tab) {
                        Tab.HOME -> ClipboardScreen(viewModel, clipboardTabState, listState = homeListState)
                        Tab.DEVICES -> DevicesScreen(
                            viewModel, devicesTabState, listState = devicesListState,
                            showCodeInput = showDeviceCodeInput,
                            onCodeInputChanged = { showDeviceCodeInput = it },
                        )
                        Tab.SETTINGS -> SettingsScreen(viewModel, settingsTabState)
                    }
                }

                AirclipAlertHost(
                    state = alertHostState,
                    modifier = Modifier
                        .align(Alignment.BottomCenter)
                        .padding(horizontal = 16.dp, vertical = 16.dp),
                )
            }
        }
    }

}

@Composable
private fun AirclipBottomNavigation(
    currentTab: Tab,
    onTabSelected: (Tab) -> Unit,
) {
    val c = LocalAirclipColors.current
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
                AirclipBottomNavigationItem(
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
private fun AirclipBottomNavigationItem(
    item: NavItem,
    isSelected: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val c = LocalAirclipColors.current
    val itemColor by animateColorAsState(
        targetValue = if (isSelected) c.accent else c.textSecondary,
        animationSpec = tween(140),
        label = "navigation color",
    )
    val indicatorColor by animateColorAsState(
        targetValue = if (isSelected) c.activeFill else Color.Transparent,
        animationSpec = tween(140),
        label = "navigation indicator",
    )
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
                .background(indicatorColor),
            contentAlignment = Alignment.Center,
        ) {
            Crossfade(targetState = isSelected, animationSpec = tween(120), label = "navigation icon") { selected ->
                Icon(
                    painter = painterResource(id = if (selected) item.activeIconRes else item.iconRes),
                    contentDescription = item.label,
                    modifier = Modifier.size(24.dp),
                    tint = itemColor,
                )
            }
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
