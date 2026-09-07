package com.airclip.airclip.ui.screens

import android.Manifest
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.LocalIndication
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyListState
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.airclip.airclip.R
import com.journeyapps.barcodescanner.ScanContract
import com.journeyapps.barcodescanner.ScanOptions
import com.airclip.airclip.MainViewModel
import com.airclip.airclip.PairedDevice
import com.airclip.airclip.SyncMode
import com.airclip.airclip.device.WifiNetworkName
import com.airclip.airclip.lan.LanRuntimeIssue
import com.airclip.airclip.lan.PeerManager
import com.airclip.airclip.pairing.AirClipCaptureActivity
import com.airclip.airclip.ui.theme.*
import kotlinx.coroutines.delay

private val BearyFontFamily = FontFamily(Font(R.font.beary))

@Composable
fun DevicesScreen(
    viewModel: MainViewModel,
    uiState: DevicesTabUiState,
    listState: LazyListState,
) {
    val c = LocalAirClipColors.current
    val context = LocalContext.current
    var wifiNetwork by remember { mutableStateOf(WifiNetworkName.current(context)) }
    var statusClockMs by remember { mutableStateOf(System.currentTimeMillis()) }
    var showLocationExplanation by remember { mutableStateOf(false) }
    fun refreshWifiNetworkName() {
        wifiNetwork = WifiNetworkName.current(context)
    }
    val locationPermissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions(),
    ) {
        refreshWifiNetworkName()
    }

    LaunchedEffect(Unit) {
        refreshWifiNetworkName()
    }

    LaunchedEffect(uiState.pairedDevices.isNotEmpty()) {
        if (uiState.pairedDevices.isEmpty()) return@LaunchedEffect
        while (true) {
            delay(30_000L)
            statusClockMs = System.currentTimeMillis()
        }
    }

    val scanLauncher = rememberLauncherForActivityResult(ScanContract()) { result ->
        result.contents?.let { viewModel.onQrScanned(it) }
    }

    fun launchPairingScanner() {
        val opts = ScanOptions().apply {
            setPrompt("Scan a new device's QR code to pair it")
            setBeepEnabled(false)
            setCaptureActivity(AirClipCaptureActivity::class.java)
            setOrientationLocked(true)
        }
        scanLauncher.launch(opts)
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(color = c.bgBase),
    ) {
        LazyColumn(
            modifier = Modifier.fillMaxSize(),
            state = listState,
            contentPadding = PaddingValues(
                bottom = if (uiState.pairedDevices.isEmpty()) 112.dp else 32.dp,
            ),
        ) {
            item(key = "devices-header") {
                DevicesPageHeader(
                    network = wifiNetwork,
                    connectedCount = uiState.connectedPeerCount,
                    onPairClick = { launchPairingScanner() },
                    onPermissionRequest = { showLocationExplanation = true },
                )
            }

            // ── Diagnostic banner ─────────────────────────────────────────────────
            val diagnostic = if (uiState.pairedDevices.isEmpty()) null else deviceDiagnostic(uiState)
            if (diagnostic != null) {
                item {
                    DiagnosticBanner(diagnostic, modifier = Modifier.padding(horizontal = 16.dp))
                    Spacer(Modifier.height(8.dp))
                }
            }

            // ── Device list ───────────────────────────────────────────────────────
            if (uiState.pairedDevices.isNotEmpty()) {
                itemsIndexed(uiState.pairedDevices, key = { _, d -> d.deviceId }) { index, device ->
                    val isReachable = PeerManager.hasPeer(device.deviceId)
                    val isLast = index == uiState.pairedDevices.lastIndex
                    DeviceFeedRow(
                        device = device,
                        isReachable = isReachable,
                        nowMs = statusClockMs,
                        isLast = isLast,
                        onRefresh = viewModel::onReconnectDevice,
                        onRemove = { viewModel.onRemoveDevice(device.deviceId) },
                    )
                }
            }
        }

        if (uiState.pairedDevices.isEmpty()) {
            AirClipEmptyState(
                iconRes = R.drawable.ic_devices_empty_state,
                text = "Connect another device to start copying and pasting across devices.",
            )

            AddNewDeviceButton(
                onClick = { launchPairingScanner() },
                modifier = Modifier
                    .align(Alignment.Center)
                    .offset(y = 170.dp),
            )
        }

    }

    if (showLocationExplanation) {
        AlertDialog(
            onDismissRequest = { showLocationExplanation = false },
            icon = { Icon(Icons.Outlined.LocationOn, contentDescription = null, tint = c.blue) },
            title = { Text("Show Wi-Fi name?", color = c.textPrimary) },
            text = {
                Text(
                    "Android requires Location permission to read the connected Wi-Fi name. AirClip uses it only to help identify your local network.",
                    color = c.textSecondary,
                )
            },
            confirmButton = {
                TextButton(
                    onClick = {
                        showLocationExplanation = false
                        locationPermissionLauncher.launch(
                            arrayOf(
                                Manifest.permission.ACCESS_COARSE_LOCATION,
                                Manifest.permission.ACCESS_FINE_LOCATION,
                            ),
                        )
                    },
                ) { Text("Continue", color = c.blue) }
            },
            dismissButton = {
                TextButton(onClick = { showLocationExplanation = false }) {
                    Text("Not now", color = c.textSecondary)
                }
            },
            containerColor = c.bgFloating,
        )
    }
}

@Composable
private fun DevicesPageHeader(
    network: WifiNetworkName.Result,
    connectedCount: Int,
    onPairClick: () -> Unit,
    onPermissionRequest: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val c = LocalAirClipColors.current
    val statusBarTop = WindowInsets.statusBars.asPaddingValues().calculateTopPadding()
    Column(
        modifier = modifier
            .fillMaxWidth()
            .background(c.bgBase)
            .padding(top = statusBarTop + 24.dp, bottom = 24.dp),
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .height(48.dp)
                .padding(horizontal = 20.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                "Devices",
                fontSize = 36.sp,
                lineHeight = 40.sp,
                fontFamily = BearyFontFamily,
                fontWeight = FontWeight.Normal,
                color = c.textPrimary,
                letterSpacing = (-0.6).sp,
            )
            Spacer(Modifier.weight(1f))
            Box(
                modifier = Modifier
                    .size(48.dp)
                    .clip(CircleShape)
                    .background(c.bgBase.copy(alpha = 0.8f))
                    .clickable(
                        interactionSource = remember { MutableInteractionSource() },
                        indication = LocalIndication.current,
                        role = Role.Button,
                    ) { onPairClick() },
                contentAlignment = Alignment.Center,
            ) {
                Icon(
                    painter = painterResource(R.drawable.ic_pair_qr),
                    contentDescription = "Pair new device",
                    tint = c.textPrimary,
                    modifier = Modifier.size(28.dp),
                )
            }
        }
        Spacer(Modifier.height(32.dp))
        NetworkStatusCard(
            network = network,
            connectedCount = connectedCount,
            onPermissionRequest = onPermissionRequest,
            modifier = Modifier.padding(horizontal = 20.dp),
        )
    }
}

// ── Network status card ───────────────────────────────────────────────────────

@Composable
private fun NetworkStatusCard(
    network: WifiNetworkName.Result,
    connectedCount: Int,
    onPermissionRequest: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val c = LocalAirClipColors.current
    val needsPermission = network.unavailableReason == WifiNetworkName.UnavailableReason.PermissionRequired
    val networkName = network.name ?: "Wi-Fi name unavailable"
    val subtitle = network.unavailableReason?.let { reason ->
        when (reason) {
            WifiNetworkName.UnavailableReason.PermissionRequired ->
                "Tap to show your Wi-Fi network name."
            WifiNetworkName.UnavailableReason.LocationDisabled ->
                "Turn on Location to show your Wi-Fi network name."
            WifiNetworkName.UnavailableReason.Unknown ->
                "Wi-Fi network name could not be read."
        }
    } ?: when {
        connectedCount == 0 -> "No devices"
        connectedCount == 1 -> "1 device"
        else -> "$connectedCount devices"
    }

    Box(
        modifier = modifier
            .fillMaxWidth()
            .height(80.dp)
            .clip(RoundedCornerShape(24.dp))
            .background(c.bgElevated)
            .border(1.dp, c.borderSubtle, RoundedCornerShape(24.dp))
            .then(
                if (needsPermission) {
                    Modifier.clickable(role = Role.Button, onClick = onPermissionRequest)
                } else {
                    Modifier
                },
            )
            .clipToBounds(),
    ) {
        val ringColor = c.borderSubtle
        Canvas(modifier = Modifier.matchParentSize()) {
            val strokeWidth = 1.dp.toPx()
            val rings = listOf(
                Triple(-16f, -24f, 128f),
                Triple(-56f, -64f, 208f),
                Triple(-96f, -104f, 288f),
                Triple(-136f, -144f, 368f),
                Triple(-176f, -184f, 448f),
            )
            val ringAlphas = listOf(1f, 0.7f, 0.5f, 0.4f, 0.3f)
            rings.forEachIndexed { index, (x, y, size) ->
                drawOval(
                    color = ringColor.copy(alpha = ringAlphas[index]),
                    topLeft = androidx.compose.ui.geometry.Offset(x.dp.toPx(), y.dp.toPx()),
                    size = androidx.compose.ui.geometry.Size(size.dp.toPx(), size.dp.toPx()),
                    style = Stroke(width = strokeWidth),
                )
            }
        }

        Box(
            modifier = Modifier
                .offset(x = 24.dp, y = 16.dp)
                .size(48.dp)
                .clip(CircleShape)
                .background(c.bgFloating)
                .border(1.dp, c.borderSubtle, CircleShape),
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                imageVector = Icons.Outlined.Wifi,
                contentDescription = null,
                tint = c.green,
                modifier = Modifier.size(24.dp),
            )
        }

        Column(
            modifier = Modifier
                .offset(x = 88.dp, y = 16.5f.dp)
                .width(186.dp),
        ) {
            Text(
                networkName,
                fontSize = 18.sp,
                lineHeight = 25.sp,
                color = c.textPrimary,
                fontWeight = FontWeight.Medium,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
            Text(
                subtitle,
                fontSize = 14.sp,
                lineHeight = 20.sp,
                color = c.textSecondary,
                fontWeight = FontWeight.Normal,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
        }
    }
}

// ── Diagnostic banner ─────────────────────────────────────────────────────────

@Composable
private fun DiagnosticBanner(diagnostic: DeviceDiagnostic, modifier: Modifier = Modifier) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(color = diagnostic.tint.copy(alpha = 0.07f))
            .border(0.5.dp, diagnostic.tint.copy(alpha = 0.18f), RoundedCornerShape(12.dp))
            .padding(horizontal = 14.dp, vertical = 12.dp),
        verticalAlignment = Alignment.Top,
        horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        if (diagnostic.iconRes != null) {
            Icon(
                painter = painterResource(diagnostic.iconRes),
                contentDescription = null,
                tint = diagnostic.tint,
                modifier = Modifier.size(16.dp).padding(top = 1.dp),
            )
        } else if (diagnostic.icon != null) {
            Icon(
                imageVector = diagnostic.icon,
                contentDescription = null,
                tint = diagnostic.tint,
                modifier = Modifier.size(16.dp).padding(top = 1.dp),
            )
        }
        Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(
                diagnostic.title,
                style = MaterialTheme.typography.labelLarge,
                color = diagnostic.tint,
            )
            Text(
                diagnostic.body,
                style = MaterialTheme.typography.labelSmall,
                color = diagnostic.tint.copy(alpha = 0.75f),
            )
        }
    }
}

private data class DeviceDiagnostic(
    val title: String,
    val body: String,
    val icon: ImageVector?,
    val tint: Color,
    val iconRes: Int? = null,
)

private fun deviceDiagnostic(uiState: DevicesTabUiState): DeviceDiagnostic? {
    // Access colors without composition — use fixed semantic values
    return when {
        uiState.syncMode == SyncMode.PAUSED -> DeviceDiagnostic(
            "Sync is paused",
            "Resume sync to reconnect nearby devices.",
            Icons.Outlined.PauseCircle,
            Color(0xFF9CA3AF),
        )
        uiState.lanRuntimeDiagnostic.issue == LanRuntimeIssue.SERVER_FAILED -> DeviceDiagnostic(
            "Local listener could not start",
            "Restart AirClip. Another process may be using port 7878.",
            Icons.Outlined.ErrorOutline,
            Color(0xFFD97706),
        )
        uiState.lanRuntimeDiagnostic.issue == LanRuntimeIssue.DISCOVERY_FAILED -> DeviceDiagnostic(
            "Discovery could not start",
            "Check Wi-Fi, VPN settings, and allow local network discovery.",
            Icons.Outlined.WifiOff,
            Color(0xFFD97706),
        )
        uiState.lanRuntimeDiagnostic.issue == LanRuntimeIssue.ADVERTISEMENT_FAILED -> DeviceDiagnostic(
            "This device is not advertising",
            "Other devices may not find it. Check Wi-Fi settings.",
            Icons.Outlined.PortableWifiOff,
            Color(0xFFD97706),
        )
        uiState.pairedDevices.isEmpty() && uiState.myDeviceId != null -> DeviceDiagnostic(
            title = "No paired devices yet",
            body = "Tap the QR icon to scan another AirClip device.",
            icon = null,
            tint = Color(0xFF2563EB),
            iconRes = R.drawable.ic_pair_qr,
        )
        else -> null
    }
}

// ── Device feed row — open list style ────────────────────────────────────────

@Composable
private fun DeviceFeedRow(
    device: PairedDevice,
    isReachable: Boolean,
    nowMs: Long,
    isLast: Boolean,
    onRefresh: () -> Unit,
    onRemove: () -> Unit,
) {
    val c = LocalAirClipColors.current
    var showMenu by remember { mutableStateOf(false) }
    var showConfirm by remember { mutableStateOf(false) }

    val status = deviceDisplayStatus(device, isReachable, nowMs)
    val contentAlpha = if (status == DeviceDisplayStatus.Offline) 0.5f else 1f

    Box(
        modifier = Modifier
            .padding(horizontal = 20.dp)
            .fillMaxWidth()
            .height(68.dp)
            .clip(RoundedCornerShape(8.dp))
            .border(1.dp, c.borderSubtle, RoundedCornerShape(8.dp)),
    ) {
        Icon(
            painter = painterResource(platformIconRes(device)),
            contentDescription = null,
            tint = Color.Unspecified,
            modifier = Modifier
                .offset(x = 12.dp, y = 20.dp)
                .size(28.dp)
                .graphicsLayer { alpha = contentAlpha },
        )

        Column(
            modifier = Modifier
                .offset(x = 52.dp, y = 8.dp)
                .width(264.dp)
                .height(52.dp),
        ) {
            Text(
                device.deviceName,
                fontSize = 16.sp,
                lineHeight = 24.sp,
                fontWeight = FontWeight.Medium,
                color = c.textPrimary.copy(alpha = contentAlpha),
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
            Spacer(Modifier.height(4.dp))
            Text(
                text = status.label,
                fontSize = 14.sp,
                lineHeight = 16.sp,
                fontWeight = FontWeight.Normal,
                color = c.textSecondary.copy(alpha = contentAlpha),
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
        }

        Box(
            modifier = Modifier
                .align(Alignment.TopEnd)
                .offset(x = (-12).dp, y = 24.dp)
                .size(20.dp)
                .clickable(
                    interactionSource = remember { MutableInteractionSource() },
                    indication = LocalIndication.current,
                    role = Role.Button,
                ) { showMenu = true },
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                painter = painterResource(R.drawable.ic_device_more_vertical),
                contentDescription = "More",
                tint = Color.Unspecified,
                modifier = Modifier.size(20.dp),
            )
            AirClipDropdownMenu(
                expanded = showMenu,
                onDismissRequest = { showMenu = false },
                items = listOf(
                    AirClipDropdownItem(
                        label = "Refresh",
                        onClick = onRefresh,
                    ),
                    AirClipDropdownItem(
                        label = "Remove device",
                        color = LocalAirClipColors.current.destructive,
                        onClick = { showConfirm = true },
                    ),
                ),
            )
        }
    }

    if (!isLast) {
        Spacer(Modifier.height(12.dp))
    }

    if (showConfirm) {
        AlertDialog(
            onDismissRequest = { showConfirm = false },
            title = { Text("Remove ${device.deviceName}?", color = c.textPrimary) },
            text = {
                Text(
                    "This device will no longer sync with your AirClip network.",
                    color = c.textSecondary,
                    style = MaterialTheme.typography.bodySmall,
                )
            },
            confirmButton = {
                TextButton(onClick = { showConfirm = false; onRemove() }) {
                    Text("Remove", color = c.destructive)
                }
            },
            dismissButton = {
                TextButton(onClick = { showConfirm = false }) {
                    Text("Cancel", color = c.textSecondary)
                }
            },
            containerColor = c.bgFloating,
        )
    }
}

@Composable
private fun AddNewDeviceButton(
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val c = LocalAirClipColors.current
    Button(
        onClick = onClick,
        modifier = modifier
            .widthIn(min = 164.dp)
            .height(44.dp),
        shape = RoundedCornerShape(22.dp),
        colors = ButtonDefaults.buttonColors(
            containerColor = c.textPrimary,
            contentColor = c.bgBase,
        ),
        contentPadding = PaddingValues(horizontal = 20.dp),
    ) {
        Icon(
            painter = painterResource(R.drawable.ic_pair_qr),
            contentDescription = null,
            modifier = Modifier.size(20.dp),
        )
        Spacer(Modifier.width(8.dp))
        Text(
            text = "Add New Device",
            fontSize = 16.sp,
            lineHeight = 20.sp,
            fontWeight = FontWeight.Normal,
            maxLines = 1,
        )
    }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

private sealed class DeviceDisplayStatus(
    val label: String,
    val color: Color,
) {
    data object Online : DeviceDisplayStatus("Online", Color(0xFF18D437))
    data object Offline : DeviceDisplayStatus("Offline", Color(0xFF9CA3AF))
    data class LastSeen(private val timestampMs: Long, private val nowMs: Long) : DeviceDisplayStatus(
        formatRelativeTime(timestampMs, nowMs),
        Color(0xFF6F7785),
    )
}

private fun deviceDisplayStatus(device: PairedDevice, isReachable: Boolean, nowMs: Long): DeviceDisplayStatus {
    if (!isReachable) return DeviceDisplayStatus.Offline
    val lastActivityMs = when {
        device.lastActiveMs > 0L -> device.lastActiveMs
        device.lastSeenMs > 0L -> device.lastSeenMs
        else -> 0L
    }
    if (lastActivityMs <= 0L) return DeviceDisplayStatus.LastSeen(nowMs, nowMs)
    return if (nowMs - lastActivityMs < 60_000L) {
        DeviceDisplayStatus.Online
    } else {
        DeviceDisplayStatus.LastSeen(lastActivityMs, nowMs)
    }
}

private fun platformIconRes(device: PairedDevice): Int = when (platformKind(device)) {
    "laptop" -> R.drawable.ic_device_laptop_active
    "phone" -> R.drawable.ic_device_mobile_active
    else -> R.drawable.ic_device_mobile_active
}

private fun platformKind(device: PairedDevice): String {
    val value = "${device.platform} ${device.deviceName}".lowercase()
    return when {
        listOf("mac", "macbook", "darwin", "laptop").any { value.contains(it) } -> "laptop"
        listOf("windows", "desktop").any { value.contains(it) } -> "desktop"
        listOf("android", "iphone", "phone", "oneplus", "pixel", "samsung").any { value.contains(it) } -> "phone"
        else -> "phone"
    }
}

private fun formatRelativeTime(timestampMs: Long, nowMs: Long): String {
    val diff = nowMs - timestampMs
    return when {
        diff < 60_000L -> "Online"
        diff < 3_600_000L -> {
            val minutes = diff / 60_000L
            "${minutes}m ago"
        }
        diff < 86_400_000L -> {
            val hours = diff / 3_600_000L
            "${hours}h ago"
        }
        else -> {
            val days = diff / 86_400_000L
            "${days}d ago"
        }
    }
}
