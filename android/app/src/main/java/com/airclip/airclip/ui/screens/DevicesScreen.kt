package com.airclip.airclip.ui.screens

import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import com.journeyapps.barcodescanner.ScanContract
import com.journeyapps.barcodescanner.ScanOptions
import com.airclip.airclip.MainViewModel
import com.airclip.airclip.PairedDevice
import com.airclip.airclip.SyncMode
import com.airclip.airclip.device.WifiNetworkName
import com.airclip.airclip.lan.LanRuntimeIssue
import com.airclip.airclip.lan.PeerManager
import com.airclip.airclip.ui.theme.*
import kotlin.math.cos
import kotlin.math.sin

@Composable
fun DevicesScreen(viewModel: MainViewModel, uiState: MainViewModel.UiState) {
    val context = LocalContext.current
    val currentWifiName = remember(uiState.connectedPeerCount, uiState.pairedDevices) {
        WifiNetworkName.current(context)
    }
    val onlineDevices = remember(uiState.pairedDevices, uiState.connectedPeerCount) {
        uiState.pairedDevices.filter { PeerManager.hasPeer(it.deviceId) }
    }

    // QR scanner for "Add device" (an existing network member scans a new device's QR).
    val scanLauncher = rememberLauncherForActivityResult(ScanContract()) { result ->
        result.contents?.let { qrContent ->
            viewModel.onQrScanned(qrContent)
        }
    }

    Column(modifier = Modifier.fillMaxSize()) {
        // Header
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 20.dp)
                .padding(top = 20.dp, bottom = 8.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                "Devices",
                style = MaterialTheme.typography.titleLarge,
                color = AirClipTextPrimary,
                modifier = Modifier.weight(1f),
            )
            IconButton(onClick = {
                val opts = ScanOptions().apply {
                    setPrompt("Scan a new device's QR code to pair it")
                    setBeepEnabled(false)
                    setOrientationLocked(false)
                }
                scanLauncher.launch(opts)
            }) {
                Icon(
                    Icons.Outlined.QrCodeScanner,
                    contentDescription = "Pair new device",
                    tint = AirClipTextSecondary,
                    modifier = Modifier.size(22.dp),
                )
            }
            IconButton(onClick = viewModel::onRefreshDevices) {
                Icon(
                    Icons.Outlined.Refresh,
                    contentDescription = "Refresh",
                    tint = AirClipTextSecondary,
                    modifier = Modifier.size(20.dp),
                )
            }
        }

        // Peer count strip
        PeerCountStrip(peerCount = uiState.connectedPeerCount)

        val diagnostic = deviceDiagnostic(uiState)
        if (diagnostic != null) {
            DeviceDiagnosticHint(diagnostic)
        }

        if (uiState.pairedDevices.isEmpty() && uiState.myDeviceId == null) {
            DevicesEmptyState()
        } else {
            DeviceOrbitPanel(
                networkName = currentWifiName ?: "Wi-Fi network",
                devices = uiState.pairedDevices,
                onlineCount = onlineDevices.size,
            )

            Spacer(Modifier.height(14.dp))

            LazyColumn(
                contentPadding = PaddingValues(horizontal = 16.dp, vertical = 4.dp),
                verticalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                if (uiState.pairedDevices.isNotEmpty()) {
                    item(key = "header") {
                        SectionLabel("Paired devices")
                    }
                    items(uiState.pairedDevices, key = { it.deviceId }) { device ->
                        val isOnline = PeerManager.hasPeer(device.deviceId)
                        DeviceCard(
                            device = device,
                            isOnline = isOnline,
                            onRemove = { viewModel.onRemoveDevice(device.deviceId) },
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun DeviceOrbitPanel(
    networkName: String,
    devices: List<PairedDevice>,
    onlineCount: Int,
) {
    var pinnedId by remember { mutableStateOf<String?>(null) }
    val placements = remember(devices) {
        devices.mapIndexed { index, device ->
            val base = -90.0
            val step = if (devices.size <= 1) 0.0 else 360.0 / devices.size
            val jitter = ((device.deviceId.hashCode() % 17) - 8) * 0.9
            OrbitPlacement(
                device = device,
                angleDeg = base + index * step + jitter,
            )
        }
    }

    Column(
        modifier = Modifier
            .padding(horizontal = 16.dp)
            .fillMaxWidth()
            .clip(RoundedCornerShape(24.dp))
            .background(AirClipBgElevated)
            .border(0.5.dp, AirClipBorderSubtle, RoundedCornerShape(24.dp))
            .padding(16.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(
            "Network map",
            style = MaterialTheme.typography.labelMedium,
            color = AirClipTextTertiary,
            modifier = Modifier.fillMaxWidth(),
        )

        Spacer(Modifier.height(12.dp))

            BoxWithConstraints(
                modifier = Modifier
                    .fillMaxWidth()
                    .aspectRatio(1f)
                    .pointerInput(devices) {
                        detectTapGestures { pinnedId = null }
                    }
            ) {
            val diameter = if (maxWidth < maxHeight) maxWidth else maxHeight
            val center = Offset(diameter.value / 2f, diameter.value / 2f)
            val hubRadius = diameter.value * 0.18f
            val orbitRadii = listOf(diameter.value * 0.24f, diameter.value * 0.37f, diameter.value * 0.50f)

            Canvas(modifier = Modifier.matchParentSize()) {
                val stroke = 1.dp.toPx()
                orbitRadii.forEach { radius ->
                    drawCircle(
                        color = AirClipBorderSubtle,
                        radius = radius,
                        center = center,
                        style = androidx.compose.ui.graphics.drawscope.Stroke(width = stroke),
                    )
                }
            }

            OrbitNode(
                modifier = Modifier.offset {
                    IntOffset((center.x - hubRadius).toInt(), (center.y - hubRadius).toInt())
                },
                size = hubRadius * 2,
                title = networkName,
                subtitle = when (onlineCount) {
                    0 -> "No devices nearby"
                    1 -> "1 other device online"
                    else -> "$onlineCount other devices online"
                },
                icon = Icons.Outlined.Wifi,
                tint = AirClipGreen,
                isOnline = true,
                selected = true,
            )

            placements.forEachIndexed { index, placement ->
                val radius = orbitRadii[index % orbitRadii.size]
                val rad = Math.toRadians(placement.angleDeg)
                val x = center.x + (cos(rad) * radius).toFloat()
                val y = center.y + (sin(rad) * radius).toFloat()
                val isPinned = pinnedId == placement.device.deviceId
                val isOnline = PeerManager.hasPeer(placement.device.deviceId)
                val nodeSize = if (isPinned) diameter.value * 0.22f else diameter.value * 0.18f
                val tooltipY = if (y < center.y) y + nodeSize + 10f else y - 54f
                val icon = platformIcon(placement.device.platform)

                Box(
                    modifier = Modifier
                        .offset { IntOffset((x - nodeSize / 2f).toInt(), (y - nodeSize / 2f).toInt()) }
                ) {
                    OrbitNode(
                        modifier = Modifier.size(nodeSize.dp),
                        size = nodeSize,
                        title = placement.device.deviceName,
                        subtitle = if (isOnline) "Online" else "Offline",
                        icon = icon,
                        tint = platformTint(placement.device.platform),
                        isOnline = isOnline,
                        selected = isPinned,
                        onClick = { pinnedId = if (isPinned) null else placement.device.deviceId },
                    )

                    if (isPinned) {
                        DeviceTooltip(
                            title = placement.device.deviceName,
                            subtitle = if (isOnline) "Online" else "Offline",
                            modifier = Modifier
                                .offset { IntOffset(0, tooltipY.toInt()) }
                        )
                    }
                }
            }

        }
    }
}

private data class OrbitPlacement(
    val device: PairedDevice,
    val angleDeg: Double,
)

@Composable
private fun OrbitNode(
    modifier: Modifier,
    size: Float,
    title: String,
    subtitle: String,
    icon: ImageVector,
    tint: Color,
    isOnline: Boolean,
    selected: Boolean,
    onClick: (() -> Unit)? = null,
) {
    val alpha = if (isOnline) 1f else 0.5f
    Column(
        modifier = modifier
            .clip(RoundedCornerShape(18.dp))
            .background(if (selected) AirClipActiveFill else AirClipBgFloating)
            .border(0.5.dp, if (selected) tint.copy(alpha = 0.35f) else AirClipBorderSubtle, RoundedCornerShape(18.dp))
            .let { base ->
                if (onClick != null) base.clickableWithoutRipple(onClick) else base
            }
            .padding(8.dp)
            .alpha(alpha),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Box(
            modifier = Modifier
                .size((size * 0.52f).dp)
                .background(tint.copy(alpha = 0.16f), RoundedCornerShape(14.dp)),
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                imageVector = icon,
                contentDescription = title,
                tint = tint,
                modifier = Modifier.size((size * 0.25f).dp),
            )
        }
        Spacer(Modifier.height(6.dp))
        Text(title, style = MaterialTheme.typography.labelLarge, color = AirClipTextPrimary, maxLines = 1)
        Text(subtitle, style = MaterialTheme.typography.labelSmall, color = AirClipTextTertiary)
    }
}

@Composable
private fun DeviceTooltip(title: String, subtitle: String, modifier: Modifier = Modifier) {
    Column(
        modifier = modifier
            .clip(RoundedCornerShape(12.dp))
        .background(AirClipBgFloating)
        .border(0.5.dp, AirClipBorderSubtle, RoundedCornerShape(12.dp))
        .padding(horizontal = 12.dp, vertical = 8.dp),
        horizontalAlignment = Alignment.Start,
    ) {
        Text(title, style = MaterialTheme.typography.labelLarge, color = AirClipTextPrimary)
        Text(subtitle, style = MaterialTheme.typography.labelSmall, color = AirClipTextTertiary)
    }
}

private fun platformIcon(platform: String): ImageVector = when (platform.lowercase()) {
    "android" -> Icons.Outlined.PhoneAndroid
    "mac", "macos", "darwin" -> Icons.Outlined.Laptop
    "windows" -> Icons.Outlined.DesktopWindows
    "linux" -> Icons.Outlined.Computer
    else -> Icons.Outlined.Devices
}

private fun platformTint(platform: String): Color = when (platform.lowercase()) {
    "android" -> AirClipGreen
    "mac", "macos", "darwin" -> AirClipBlue
    "windows" -> AirClipAccent
    "linux" -> AirClipYellow
    else -> AirClipTextSecondary
}

@Composable
private fun Modifier.clickableWithoutRipple(onClick: () -> Unit): Modifier =
    this.clickable(
        indication = null,
        interactionSource = remember { androidx.compose.foundation.interaction.MutableInteractionSource() },
        onClick = onClick,
    )

// ── Peer count strip ──────────────────────────────────────────────────────────

@Composable
private fun PeerCountStrip(peerCount: Int) {
    if (peerCount == 0) return   // no strip when offline — we show OfflineHint instead

    Row(
        modifier = Modifier
            .padding(horizontal = 20.dp)
            .padding(bottom = 4.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Box(
            modifier = Modifier
                .size(7.dp)
                .background(AirClipGreen, RoundedCornerShape(4.dp)),
        )
        val label = if (peerCount == 1) "1 other device nearby" else "$peerCount other devices nearby"
        Text(label, style = MaterialTheme.typography.labelSmall, color = AirClipGreen)
    }
}

// ── Device diagnostics ───────────────────────────────────────────────────────

@Composable
private fun DeviceDiagnosticHint(diagnostic: DeviceDiagnostic) {
    Row(
        modifier = Modifier
            .padding(horizontal = 16.dp)
            .padding(bottom = 8.dp)
            .fillMaxWidth()
            .clip(RoundedCornerShape(10.dp))
            .background(diagnostic.tint.copy(alpha = 0.08f))
            .border(0.5.dp, diagnostic.tint.copy(alpha = 0.20f), RoundedCornerShape(10.dp))
            .padding(horizontal = 14.dp, vertical = 10.dp),
        verticalAlignment = Alignment.Top,
        horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Icon(
            diagnostic.icon,
            null,
            tint = diagnostic.tint,
            modifier = Modifier.size(16.dp).padding(top = 2.dp),
        )
        Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(
                diagnostic.title,
                style = MaterialTheme.typography.labelSmall,
                color = diagnostic.tint.copy(alpha = 0.92f),
            )
            Text(
                diagnostic.body,
                style = MaterialTheme.typography.labelSmall,
                color = diagnostic.tint.copy(alpha = 0.78f),
            )
        }
    }
}

private data class DeviceDiagnostic(
    val title: String,
    val body: String,
    val icon: ImageVector,
    val tint: Color,
)

private fun deviceDiagnostic(uiState: MainViewModel.UiState): DeviceDiagnostic? = when {
    uiState.syncMode == SyncMode.PAUSED -> DeviceDiagnostic(
        title = "Sync is paused",
        body = "Resume sync to reconnect nearby devices.",
        icon = Icons.Outlined.PauseCircle,
        tint = AirClipTextTertiary,
    )
    uiState.lanRuntimeDiagnostic.issue == LanRuntimeIssue.SERVER_FAILED -> DeviceDiagnostic(
        title = "Local listener could not start",
        body = "Restart AirClip. If it keeps happening, another process may be using port 7878.",
        icon = Icons.Outlined.ErrorOutline,
        tint = AirClipYellow,
    )
    uiState.lanRuntimeDiagnostic.issue == LanRuntimeIssue.DISCOVERY_FAILED -> DeviceDiagnostic(
        title = "Discovery could not start",
        body = "Check Wi-Fi, VPN/private DNS settings, and allow nearby/local network discovery.",
        icon = Icons.Outlined.WifiOff,
        tint = AirClipYellow,
    )
    uiState.lanRuntimeDiagnostic.issue == LanRuntimeIssue.ADVERTISEMENT_FAILED -> DeviceDiagnostic(
        title = "This device is not advertising",
        body = "Other devices may not find it. Keep AirClip open and check Wi-Fi or hotspot settings.",
        icon = Icons.Outlined.PortableWifiOff,
        tint = AirClipYellow,
    )
    uiState.pairedDevices.isNotEmpty() && uiState.connectedPeerCount == 0 -> DeviceDiagnostic(
        title = "No paired devices nearby",
        body = "Keep devices awake, on the same Wi-Fi, and allow local network discovery.",
        icon = Icons.Outlined.WifiOff,
        tint = AirClipYellow,
    )
    uiState.pairedDevices.isEmpty() && uiState.myDeviceId != null -> DeviceDiagnostic(
        title = "No paired devices yet",
        body = "Scan a QR code or enter a pairing code from another AirClip device.",
        icon = Icons.Outlined.QrCodeScanner,
        tint = AirClipBlue,
    )
    else -> null
}

// ── Self device card (pinned at top) ─────────────────────────────────────────

@Composable
private fun SelfDeviceCard(deviceName: String) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(AirClipBgElevated)
            .border(0.5.dp, AirClipBorderSubtle, RoundedCornerShape(12.dp))
            .padding(horizontal = 14.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Box(
            modifier = Modifier
                .size(40.dp)
                .background(AirClipActiveFill, RoundedCornerShape(10.dp)),
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                Icons.Outlined.PhoneAndroid,
                null,
                tint = AirClipTextSecondary,
                modifier = Modifier.size(20.dp),
            )
        }
        Column(modifier = Modifier.weight(1f)) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                Text(deviceName, style = MaterialTheme.typography.bodyMedium, color = AirClipTextPrimary)
                Box(
                    modifier = Modifier
                        .background(AirClipBlue.copy(alpha = 0.15f), RoundedCornerShape(4.dp))
                        .padding(horizontal = 6.dp, vertical = 2.dp),
                ) {
                    Text("This device", style = MaterialTheme.typography.labelSmall, color = AirClipBlue)
                }
            }
        }
        // Always online (it's us)
        StatusDot(online = true, label = null)  // no label for self
    }
}

// ── Paired device card ────────────────────────────────────────────────────────

@Composable
private fun DeviceCard(device: PairedDevice, isOnline: Boolean, onRemove: () -> Unit) {
    var showMenu    by remember { mutableStateOf(false) }
    var showConfirm by remember { mutableStateOf(false) }

    val platformIcon: ImageVector = when (device.platform.lowercase()) {
        "android" -> Icons.Outlined.PhoneAndroid
        "mac"     -> Icons.Outlined.Laptop
        "windows" -> Icons.Outlined.DesktopWindows
        "linux"   -> Icons.Outlined.Computer
        else      -> Icons.Outlined.Devices
    }

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(AirClipBgElevated)
            .border(0.5.dp, AirClipBorderSubtle, RoundedCornerShape(12.dp))
            .padding(horizontal = 14.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Box(
            modifier = Modifier
                .size(40.dp)
                .background(AirClipActiveFill, RoundedCornerShape(10.dp)),
            contentAlignment = Alignment.Center,
        ) {
            Icon(platformIcon, null, tint = AirClipTextSecondary, modifier = Modifier.size(20.dp))
        }

        Column(modifier = Modifier.weight(1f)) {
            Text(device.deviceName, style = MaterialTheme.typography.bodyMedium, color = AirClipTextPrimary)
            val subtitle = when {
                isOnline && device.lastSeenMs > 0L -> "Seen ${formatRelativeTime(device.lastSeenMs)}"
                !isOnline && device.lastSeenMs > 0L -> "Last seen ${formatRelativeTime(device.lastSeenMs)}"
                !device.wifiNetwork.isNullOrEmpty() -> device.wifiNetwork
                else -> null
            }
            if (subtitle != null) {
                Spacer(Modifier.height(2.dp))
                Text(
                    subtitle,
                    style = MaterialTheme.typography.labelSmall,
                    color = AirClipTextTertiary,
                )
            }
        }

        StatusDot(online = isOnline, label = if (isOnline) "Online" else "Offline")

        // Three-dot menu
        Box {
            IconButton(
                onClick = { showMenu = true },
                modifier = Modifier.size(32.dp),
            ) {
                Icon(
                    Icons.Outlined.MoreVert,
                    contentDescription = "More options",
                    tint = AirClipTextTertiary,
                    modifier = Modifier.size(18.dp),
                )
            }
            DropdownMenu(
                expanded = showMenu,
                onDismissRequest = { showMenu = false },
            ) {
                DropdownMenuItem(
                    text = { Text("Remove device", color = AirClipDestructive) },
                    onClick = { showMenu = false; showConfirm = true },
                    leadingIcon = {
                        Icon(Icons.Outlined.RemoveCircleOutline, null, tint = AirClipDestructive, modifier = Modifier.size(18.dp))
                    },
                )
            }
        }
    }

    if (showConfirm) {
        AlertDialog(
            onDismissRequest = { showConfirm = false },
            title = { Text("Remove ${device.deviceName}?", color = AirClipTextPrimary) },
            text = {
                Text(
                    "This device will no longer be able to sync with your AirClip network.",
                    color = AirClipTextSecondary,
                    style = MaterialTheme.typography.bodySmall,
                )
            },
            confirmButton = {
                TextButton(onClick = { showConfirm = false; onRemove() }) {
                    Text("Remove", color = AirClipDestructive)
                }
            },
            dismissButton = {
                TextButton(onClick = { showConfirm = false }) {
                    Text("Cancel", color = AirClipTextSecondary)
                }
            },
            containerColor = AirClipBgFloating,
        )
    }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

@Composable
private fun StatusDot(online: Boolean, label: String?) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        Box(
            modifier = Modifier
                .size(7.dp)
                .background(
                    if (online) AirClipGreen else AirClipTextTertiary,
                    RoundedCornerShape(4.dp),
                )
        )
        label?.let {
            Text(it, style = MaterialTheme.typography.labelSmall, color = if (online) AirClipGreen else AirClipTextTertiary)
        }
    }
}

@Composable
private fun SectionLabel(text: String) {
    Text(
        text,
        style = MaterialTheme.typography.labelMedium,
        color = AirClipTextTertiary,
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 4.dp)
            .padding(top = 12.dp, bottom = 4.dp),
    )
}

@Composable
private fun DevicesEmptyState() {
    Column(
        modifier = Modifier.fillMaxSize().padding(32.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Icon(Icons.Outlined.Devices, null, tint = AirClipTextTertiary, modifier = Modifier.size(40.dp))
        Spacer(Modifier.height(12.dp))
        Text("No paired devices yet", style = MaterialTheme.typography.bodyMedium, color = AirClipTextSecondary)
        Spacer(Modifier.height(4.dp))
        Text(
            "Tap the QR icon above to pair another device.",
            style = MaterialTheme.typography.bodySmall,
            color = AirClipTextTertiary,
            textAlign = androidx.compose.ui.text.style.TextAlign.Center,
        )
    }
}

private fun formatRelativeTime(timestampMs: Long): String {
    val diff = System.currentTimeMillis() - timestampMs
    return when {
        diff < 60_000L     -> "just now"
        diff < 3_600_000L  -> "${diff / 60_000L}m ago"
        diff < 86_400_000L -> "${diff / 3_600_000L}h ago"
        else               -> "${diff / 86_400_000L}d ago"
    }
}
