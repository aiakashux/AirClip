package com.airclip.airclip.ui.screens

import android.Manifest
import androidx.activity.compose.BackHandler
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.Crossfade
import androidx.compose.animation.core.CubicBezierEasing
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.animateContentSize
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.LocalIndication
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsHoveredAsState
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.hoverable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.ArrowBack
import androidx.compose.material.icons.outlined.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
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
import com.airclip.airclip.pairing.AirclipCaptureActivity
import com.airclip.airclip.ui.theme.*
import kotlinx.coroutines.delay
import coil.compose.AsyncImage
import coil.decode.SvgDecoder
import coil.request.ImageRequest
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.layout.ContentScale

@Composable
private fun DeviceArtwork(name: String, modifier: Modifier, description: String? = null, tint: Color? = null) {
    AsyncImage(
        model = ImageRequest.Builder(LocalContext.current)
            .data("file:///android_asset/devices/$name.svg")
            .decoderFactory(SvgDecoder.Factory()).build(),
        contentDescription = description,
        colorFilter = tint?.let { ColorFilter.tint(it) },
        contentScale = ContentScale.FillBounds,
        modifier = modifier,
    )
}

private val BearyFontFamily = FontFamily(Font(R.font.beary))

@Composable
fun DevicesScreen(
    viewModel: MainViewModel,
    uiState: DevicesTabUiState,
    listState: LazyListState,
    showCodeInput: Boolean,
    onCodeInputChanged: (Boolean) -> Unit,
) {
    val c = LocalAirclipColors.current
    val context = LocalContext.current
    val statusBarTop = WindowInsets.statusBars.asPaddingValues().calculateTopPadding()
    val headerHeight = statusBarTop + 80.dp
    val codeScreenOffset = with(LocalDensity.current) { 16.dp.roundToPx() }
    val easeOut = CubicBezierEasing(0.23f, 1f, 0.32f, 1f)
    var wifiNetwork by remember { mutableStateOf(WifiNetworkName.current(context)) }
    var statusClockMs by remember { mutableStateOf(System.currentTimeMillis()) }
    var showLocationExplanation by remember { mutableStateOf(false) }
    var pairedDeviceCountBeforeCodeInput by remember { mutableIntStateOf(0) }
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
            refreshWifiNetworkName()
        }
    }

    val scanLauncher = rememberLauncherForActivityResult(ScanContract()) { result ->
        if (result.originalIntent?.getBooleanExtra(
                AirclipCaptureActivity.EXTRA_CODE_CONNECT_REQUESTED,
                false,
            ) == true
        ) {
            pairedDeviceCountBeforeCodeInput = uiState.pairedDevices.size
            viewModel.onPairingCodeEntryOpened()
            onCodeInputChanged(true)
        } else {
            result.contents?.let { viewModel.onQrScanned(it) }
        }
    }

    fun launchPairingScanner() {
        val opts = ScanOptions().apply {
            setPrompt("Scan a new device's QR code to pair it")
            setBeepEnabled(false)
            setCaptureActivity(AirclipCaptureActivity::class.java)
            setOrientationLocked(true)
            addExtra(AirclipCaptureActivity.EXTRA_SHOW_CODE_CONNECT, true)
        }
        scanLauncher.launch(opts)
    }

    LaunchedEffect(uiState.pairedDevices.size, showCodeInput) {
        if (showCodeInput && uiState.pairedDevices.size > pairedDeviceCountBeforeCodeInput) {
            onCodeInputChanged(false)
        }
    }

    AnimatedContent(
        targetState = showCodeInput,
        transitionSpec = {
            if (targetState) {
                (fadeIn(tween(220, easing = easeOut)) +
                    slideInHorizontally(tween(220, easing = easeOut)) { codeScreenOffset }) togetherWith
                    fadeOut(tween(140))
            } else {
                fadeIn(tween(220, easing = easeOut)) togetherWith
                    (fadeOut(tween(140)) +
                        slideOutHorizontally(tween(140, easing = easeOut)) { codeScreenOffset })
            }
        },
        label = "devices code entry",
    ) { showingCodeInput ->
        if (showingCodeInput) {
            DeviceCodeInputScreen(
                error = uiState.pairingError,
                onBack = { onCodeInputChanged(false) },
                onEnterCode = viewModel::onPairingCodeEntered,
            )
        } else Box(
            modifier = Modifier
                .fillMaxSize()
                .background(color = c.bgBase),
        ) {
        LazyColumn(
            modifier = Modifier.fillMaxSize(),
            state = listState,
            contentPadding = PaddingValues(
                top = headerHeight + 28.dp,
                bottom = if (uiState.pairedDevices.isEmpty()) 112.dp else 32.dp,
            ),
        ) {
            item(key = "network-status") {
                NetworkStatusCard(
                    spaceName = uiState.spaceName,
                    network = wifiNetwork,
                    onRefresh = {
                        refreshWifiNetworkName()
                        viewModel.onRefreshDevices()
                    },
                    onPermissionRequest = { showLocationExplanation = true },
                    modifier = Modifier.padding(horizontal = 20.dp),
                )
                Spacer(Modifier.height(24.dp))
            }

            // ── Diagnostic banner ─────────────────────────────────────────────────
            val diagnostic = if (uiState.pairedDevices.isEmpty()) null else deviceDiagnostic(uiState, c)
            item(key = "diagnostic") {
                AnimatedVisibility(
                    visible = diagnostic != null,
                    enter = fadeIn(tween(180, easing = easeOut)),
                    exit = fadeOut(tween(120)),
                ) {
                    if (diagnostic != null) {
                        Column {
                            DiagnosticBanner(diagnostic, modifier = Modifier.padding(horizontal = 16.dp))
                            Spacer(Modifier.height(8.dp))
                        }
                    }
                }
            }

            // ── Device list ───────────────────────────────────────────────────────
            item(key = "device-list") {
                AnimatedVisibility(
                    visible = uiState.pairedDevices.isNotEmpty(),
                    enter = fadeIn(tween(180, easing = easeOut)),
                    exit = fadeOut(tween(120)),
                ) {
                    Column(
                        modifier = Modifier.animateContentSize(tween(180, easing = easeOut)),
                    ) {
                        uiState.pairedDevices.forEachIndexed { index, device ->
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
            }
        }

        AnimatedVisibility(
            visible = uiState.pairedDevices.isEmpty(),
            modifier = Modifier.fillMaxSize(),
            enter = fadeIn(tween(180, easing = easeOut)),
            exit = fadeOut(tween(120)),
        ) {
            Box(Modifier.fillMaxSize()) {
                AirclipEmptyState(
                    iconRes = R.drawable.ic_devices_empty_state,
                    text = "Your space is ready. Connect a device to start syncing.",
                )

                AddNewDeviceButton(
                    label = "Add a device",
                    onClick = { launchPairingScanner() },
                    modifier = Modifier
                        .align(Alignment.Center)
                        .offset(y = 170.dp),
                )
            }
        }

        DevicesPageHeader(
            onPairClick = { launchPairingScanner() },
            modifier = Modifier.align(Alignment.TopCenter),
        )

        }
    }

    if (showLocationExplanation) {
        AlertDialog(
            onDismissRequest = { showLocationExplanation = false },
            icon = { Icon(Icons.Outlined.LocationOn, contentDescription = null, tint = c.accent) },
            title = { Text("Show Wi-Fi name?", color = c.textPrimary) },
            text = {
                Text(
                    "Android requires Location permission to read the connected Wi-Fi name. Airclip uses it only to help identify your local network.",
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
                ) { Text("Continue", color = c.accent) }
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
private fun DeviceCodeInputScreen(
    error: String?,
    onBack: () -> Unit,
    onEnterCode: (String) -> Unit,
) {
    val c = LocalAirclipColors.current
    BackHandler(onBack = onBack)

    BoxWithConstraints(
        modifier = Modifier
            .fillMaxSize()
            .background(c.bgBase),
    ) {
        val scale = (maxWidth.value / 412f).coerceIn(0.82f, 1f)
        Column(
            modifier = Modifier
                .fillMaxSize()
                .statusBarsPadding()
                .imePadding(),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(56.dp),
            ) {
                IconButton(
                    onClick = onBack,
                    modifier = Modifier
                        .align(Alignment.CenterStart)
                        .padding(start = 8.dp),
                ) {
                    Icon(
                        Icons.AutoMirrored.Outlined.ArrowBack,
                        contentDescription = "Back",
                        tint = c.textPrimary,
                    )
                }
            }
            Text(
                "Enter the code",
                fontFamily = BearyFontFamily,
                fontSize = 32.sp,
                lineHeight = 40.sp,
                color = c.textPrimary,
            )
            Spacer(Modifier.height(8.dp))
            Text(
                "Enter the 6-digit code shown on another Airclip device.",
                modifier = Modifier.padding(horizontal = 28.dp),
                fontSize = 16.sp,
                lineHeight = 22.sp,
                color = c.textSecondary,
                textAlign = androidx.compose.ui.text.style.TextAlign.Center,
            )
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .weight(1f),
            ) {
                CodeInputTabContent(
                    onEnterCode = onEnterCode,
                    error = error,
                    scale = scale,
                )
            }
        }
    }
}

@Composable
private fun DevicesPageHeader(
    onPairClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val c = LocalAirclipColors.current
    val statusBarTop = WindowInsets.statusBars.asPaddingValues().calculateTopPadding()
    Row(
        modifier = modifier
            .fillMaxWidth()
            .background(c.bgBase)
            .padding(top = statusBarTop)
            .height(80.dp)
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
            modifier = Modifier.semantics { heading() },
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
}

// ── Network status card ───────────────────────────────────────────────────────

@Composable
private fun NetworkStatusCard(
    spaceName: String,
    network: WifiNetworkName.Result,
    onRefresh: () -> Unit,
    onPermissionRequest: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val c = LocalAirclipColors.current
    var refreshRotationTarget by remember { mutableStateOf(0f) }
    val refreshRotation by animateFloatAsState(
        targetValue = refreshRotationTarget,
        animationSpec = spring(
            dampingRatio = Spring.DampingRatioMediumBouncy,
            stiffness = Spring.StiffnessMediumLow,
        ),
        label = "network refresh rotation",
    )
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
    } ?: spaceName.ifBlank { "My Space" }

    Box(
        modifier = modifier
            .fillMaxWidth()
            .height(84.dp)
            .shadow(
                elevation = 1.dp,
                shape = RoundedCornerShape(16.dp),
                ambientColor = Color.Black.copy(alpha = 0.08f),
                spotColor = Color.Black.copy(alpha = 0.08f),
            )
            .clip(RoundedCornerShape(16.dp))
            .background(if (c.isDark) c.bgElevated else Color(0xFFF7F7F7))
            .then(
                if (needsPermission) {
                    Modifier.clickable(role = Role.Button, onClick = onPermissionRequest)
                } else {
                    Modifier
                },
            )
            .clipToBounds(),
    ) {
        DeviceArtwork("rings", Modifier
            .wrapContentSize(Alignment.TopStart, unbounded = true)
            .size(1032.dp).offset(x = (-476).dp, y = (-476).dp)
            .graphicsLayer { alpha = if (c.isDark) 0.15f else 1f })

        Row(
            modifier = Modifier
                .fillMaxWidth()
                .height(84.dp)
                .padding(start = 16.dp, end = 24.dp, top = 14.dp, bottom = 14.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            Box(
                modifier = Modifier
                    .size(48.dp)
                    .shadow(1.dp, CircleShape)
                    .clip(CircleShape)
                    .background(
                        Brush.verticalGradient(
                            if (c.isDark) listOf(c.bgFloating, c.bgElevated)
                            else listOf(Color.White, Color(0xFFF2F2F2)),
                        ),
                    )
                    .border(1.dp, if (c.isDark) c.borderDefault else Color(0xFFE6E7EB), CircleShape),
                contentAlignment = Alignment.Center,
            ) {
                DeviceArtwork(
                    "wifi",
                    Modifier.size(width = 22.dp, height = 15.5.dp),
                    tint = if (c.isDark) Color(0xFF64D99A) else Color(0xFF669C6C),
                )
            }

            Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(0.dp)) {
                Crossfade(targetState = networkName, animationSpec = tween(140), label = "network name") { name -> Text(
                    name,
                    fontSize = 18.sp,
                    lineHeight = 25.sp,
                    color = if (c.isDark) c.textPrimary else Color(0xFF232E43),
                    fontWeight = FontWeight.Medium,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                ) }
                Crossfade(targetState = subtitle, animationSpec = tween(140), label = "network subtitle") { text -> Text(
                    text,
                    fontSize = 13.sp,
                    lineHeight = 18.sp,
                    color = if (c.isDark) c.textSecondary else Color(0x80232E43),
                    fontWeight = FontWeight.Normal,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                ) }
            }

            Box(
                modifier = Modifier
                    .size(width = 40.dp, height = 28.dp)
                    .shadow(1.dp, CircleShape)
                    .clip(CircleShape)
                    .background(if (c.isDark) c.bgFloating else Color.White)
                    .clickable(role = Role.Button) {
                        refreshRotationTarget += 360f
                        onRefresh()
                    },
                contentAlignment = Alignment.Center,
            ) {
                DeviceArtwork("reconnect", Modifier
                    .size(13.667.dp, 15.667.dp)
                    .graphicsLayer { rotationZ = refreshRotation },
                    description = "Reconnect devices", tint = c.textPrimary)
            }
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
                color = diagnostic.tint,
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

private fun deviceDiagnostic(uiState: DevicesTabUiState, colors: AirclipColorScheme): DeviceDiagnostic? {
    return when {
        uiState.syncMode == SyncMode.PAUSED -> DeviceDiagnostic(
            "Sync is paused",
            "Resume sync to reconnect nearby devices.",
            Icons.Outlined.PauseCircle,
            colors.textSecondary,
        )
        uiState.lanRuntimeDiagnostic.issue == LanRuntimeIssue.SERVER_FAILED -> DeviceDiagnostic(
            "Local listener could not start",
            "Restart Airclip. Another process may be using port 7878.",
            Icons.Outlined.ErrorOutline,
            colors.yellow,
        )
        uiState.lanRuntimeDiagnostic.issue == LanRuntimeIssue.DISCOVERY_FAILED -> DeviceDiagnostic(
            "Discovery could not start",
            "Check Wi-Fi, VPN settings, and allow local network discovery.",
            Icons.Outlined.WifiOff,
            colors.yellow,
        )
        uiState.lanRuntimeDiagnostic.issue == LanRuntimeIssue.ADVERTISEMENT_FAILED -> DeviceDiagnostic(
            "This device is not advertising",
            "Other devices may not find it. Check Wi-Fi settings.",
            Icons.Outlined.PortableWifiOff,
            colors.yellow,
        )
        uiState.pairedDevices.isEmpty() && uiState.myDeviceId != null -> DeviceDiagnostic(
            title = "No paired devices yet",
            body = "Tap the QR icon to scan another Airclip device.",
            icon = null,
            tint = colors.blue,
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
    val c = LocalAirclipColors.current
    var showMenu by remember { mutableStateOf(false) }
    var showConfirm by remember { mutableStateOf(false) }
    val menuInteraction = remember { MutableInteractionSource() }
    val menuPressed by menuInteraction.collectIsPressedAsState()
    val menuHovered by menuInteraction.collectIsHoveredAsState()
    val menuScale by animateFloatAsState(
        targetValue = if (menuPressed) 0.97f else 1f,
        animationSpec = tween(100),
        label = "device menu press",
    )

    val status = deviceDisplayStatus(device, isReachable, nowMs)
    val contentAlpha = if (status == DeviceDisplayStatus.Offline) 0.5f else 1f

    Box(
        modifier = Modifier
            .padding(horizontal = 20.dp)
            .fillMaxWidth()
            .height(68.dp),
    ) {
        DeviceArtwork(
            name = if (device.platform.lowercase() in listOf("mac", "windows", "linux")) "laptop" else "phone",
            modifier = Modifier
                .offset(x = 12.dp, y = 20.dp)
                .size(28.dp)
                .padding(horizontal = if (device.platform.lowercase() in listOf("mac", "windows", "linux")) 1.458.dp else 4.958.dp, vertical = 1.458.dp)
                .graphicsLayer { alpha = contentAlpha },
        )

        Column(
            modifier = Modifier
                .offset(x = 56.dp, y = 12.dp)
                .fillMaxWidth()
                .padding(end = 104.dp)
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
            Crossfade(targetState = status.label, animationSpec = tween(140), label = "device status") { label -> Text(
                text = label,
                fontSize = 14.sp,
                lineHeight = 16.sp,
                fontWeight = FontWeight.Normal,
                color = c.textSecondary.copy(alpha = contentAlpha),
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            ) }
        }

        Box(
            modifier = Modifier
                .align(Alignment.CenterEnd)
                .size(48.dp)
                .graphicsLayer { scaleX = menuScale; scaleY = menuScale }
                .hoverable(menuInteraction)
                .clickable(
                    interactionSource = menuInteraction,
                    indication = null,
                    role = Role.Button,
                ) { showMenu = true },
            contentAlignment = Alignment.Center,
        ) {
            Box(
                modifier = Modifier
                    .size(32.dp)
                    .clip(RoundedCornerShape(10.dp))
                    .background(
                        if (menuPressed || menuHovered) {
                            if (c.isDark) Color.White.copy(alpha = 0.08f)
                            else Color.Black.copy(alpha = 0.04f)
                        } else {
                            Color.Transparent
                        },
                    ),
                contentAlignment = Alignment.Center,
            ) {
                DeviceArtwork("more", Modifier.size(2.104.dp, 12.083.dp), "Device actions", c.textSecondary)
            }
            AirclipDropdownMenu(
                expanded = showMenu,
                onDismissRequest = { showMenu = false },
                items = listOf(
                    AirclipDropdownItem(
                        label = "Reconnect",
                        onClick = onRefresh,
                    ),
                    AirclipDropdownItem(
                        label = "Remove device",
                        color = LocalAirclipColors.current.destructive,
                        onClick = { showConfirm = true },
                    ),
                ),
            )
        }
    }

    if (!isLast) {
        HorizontalDivider(Modifier.padding(horizontal = 20.dp), thickness = 1.dp,
            color = if (c.isDark) c.borderSubtle else Color(0xFFEEEFF0))
    }

    if (showConfirm) {
        AlertDialog(
            onDismissRequest = { showConfirm = false },
            title = { Text("Remove ${device.deviceName}?", color = c.textPrimary) },
            text = {
                Text(
                    "This device will no longer sync with your Airclip space.",
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
    label: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val c = LocalAirclipColors.current
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
            text = label,
            fontSize = 16.sp,
            lineHeight = 20.sp,
            fontWeight = FontWeight.Normal,
            maxLines = 1,
        )
    }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

private sealed class DeviceDisplayStatus(val label: String) {
    data object Online : DeviceDisplayStatus("Online")
    data object Offline : DeviceDisplayStatus("Offline")
    data class LastSeen(private val timestampMs: Long, private val nowMs: Long) : DeviceDisplayStatus(
        formatRelativeTime(timestampMs, nowMs),
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
