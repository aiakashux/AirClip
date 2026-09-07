package com.airclip.airclip.ui.screens

import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.compose.animation.*
import androidx.compose.animation.core.*
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.LocalIndication
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.ArrowBack
import androidx.compose.material.icons.outlined.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.ExperimentalComposeUiApi
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.layout.positionInParent
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.platform.LocalSoftwareKeyboardController
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage
import coil.decode.SvgDecoder
import coil.request.ImageRequest
import com.journeyapps.barcodescanner.ScanContract
import com.journeyapps.barcodescanner.ScanOptions
import com.airclip.airclip.R
import com.airclip.airclip.MainViewModel
import com.airclip.airclip.pairing.AirClipCaptureActivity
import com.airclip.airclip.pairing.PairingCode
import com.airclip.airclip.ui.theme.*
import androidx.compose.ui.graphics.asImageBitmap
import kotlinx.coroutines.delay
import kotlin.math.PI
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.sin

// ── Navigation states ─────────────────────────────────────────────────────────

private sealed interface OnboardingNav {
    data object Landing : OnboardingNav
    data object CreateName : OnboardingNav
    data object JoinFlow : OnboardingNav
    data object Success : OnboardingNav
}

private enum class JoinTab { SCAN_QR, SHOW_QR, CODE_INPUT }

private val BearyFontFamily = FontFamily(Font(R.font.beary))

// ── Entry point ───────────────────────────────────────────────────────────────

@Composable
fun OnboardingScreen(viewModel: MainViewModel, uiState: MainViewModel.UiState) {
    val c = LocalAirClipColors.current
    var nav by remember { mutableStateOf<OnboardingNav>(OnboardingNav.Landing) }

    // When pairing completes, move to success screen
    LaunchedEffect(uiState.isPairingWaiting, uiState.pairingState) {
        if (!uiState.isPairingWaiting && nav == OnboardingNav.JoinFlow &&
            uiState.pairingCode == null && uiState.pairingQr == null) {
            nav = OnboardingNav.Success
        }
    }

    // QR scanner
    val scanLauncher = rememberLauncherForActivityResult(ScanContract()) { result ->
        result.contents?.let { viewModel.onQrScanned(it) }
    }

    AnimatedContent(
        targetState = nav,
        transitionSpec = {
            val easeOut = CubicBezierEasing(0.23f, 1f, 0.32f, 1f)
            val forward = when {
                targetState is OnboardingNav.Landing -> false
                initialState is OnboardingNav.Landing -> true
                else -> true
            }
            (slideInHorizontally(tween(220, easing = easeOut)) { if (forward) it / 12 else -it / 12 } +
                    fadeIn(tween(180, easing = easeOut))).togetherWith(
                slideOutHorizontally(tween(140, easing = easeOut)) { if (forward) -it / 16 else it / 16 } +
                        fadeOut(tween(140))
            )
        },
        label = "OnboardingNav",
    ) { screen ->
        when (screen) {
            OnboardingNav.Landing -> LandingScreen(
                onCreateAirClip = { nav = OnboardingNav.CreateName },
                onJoinAirClip   = {
                    viewModel.onStartPairingSession()
                    nav = OnboardingNav.JoinFlow
                },
            )
            OnboardingNav.CreateName -> CreateNameScreen(
                uiState = uiState,
                onDeviceNameChange = viewModel::onDeviceNameChange,
                onBack = { nav = OnboardingNav.Landing },
                onCreate = { viewModel.onCreateAirClip() },
                error = uiState.lastError,
            )
            OnboardingNav.JoinFlow -> JoinFlowScreen(
                uiState = uiState,
                onBack = {
                    viewModel.onCancelPairing()
                    nav = OnboardingNav.Landing
                },
                onScanQr = {
                    val opts = ScanOptions().apply {
                        setPrompt("")
                        setBeepEnabled(false)
                        setCaptureActivity(AirClipCaptureActivity::class.java)
                        setOrientationLocked(true)
                    }
                    scanLauncher.launch(opts)
                },
                onEnterCode = viewModel::onPairingCodeEntered,
                onRefreshCode = viewModel::onRefreshPairingCode,
                error = uiState.lastError,
            )
            OnboardingNav.Success -> SuccessScreen(
                onGetStarted = { /* ViewModel will flip pairingState → app navigates to MainScreen */ },
            )
        }
    }
}

// ── Landing screen ────────────────────────────────────────────────────────────

@Composable
private fun LandingScreen(
    onCreateAirClip: () -> Unit,
    onJoinAirClip: () -> Unit,
) {
    BoxWithConstraints(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.White)
            .navigationBarsPadding(),
    ) {
        var revealLogo by remember { mutableStateOf(false) }
        var revealBottomContent by remember { mutableStateOf(false) }
        LaunchedEffect(Unit) {
            kotlinx.coroutines.delay(90)
            revealLogo = true
            kotlinx.coroutines.delay(80)
            revealBottomContent = true
        }

        val scale = maxWidth.value / 412f
        fun s(value: Float) = (value * scale).dp
        val easeOut = CubicBezierEasing(0.23f, 1f, 0.32f, 1f)
        val context = LocalContext.current
        val bottomMargin = s(40f)
        val buttonHeight = s(48f)
        val buttonGap = s(16f)
        val buttonStackTop = maxHeight - bottomMargin - buttonHeight - buttonGap - buttonHeight
        val headlineTop = buttonStackTop - s(112f)
        val artworkProgress by animateFloatAsState(
            targetValue = if (revealLogo) 1f else 0f,
            animationSpec = tween(durationMillis = 300, easing = easeOut),
            label = "SplashArtworkReveal",
        )
        val orbitRotation by rememberInfiniteTransition(label = "SplashOrbit").animateFloat(
            initialValue = 0f,
            targetValue = 360f,
            animationSpec = infiniteRepeatable(
                animation = tween(durationMillis = 13_333, easing = LinearEasing),
                repeatMode = RepeatMode.Restart,
            ),
            label = "SplashOrbitRotation",
        )
        val artworkModifier = Modifier
            .align(Alignment.TopCenter)
            .offset(y = s(-30f))
            .graphicsLayer {
                alpha = artworkProgress
            }
            .width(maxWidth)
            .height(maxWidth * (654f / 412f))

        SplashBlurArtwork(modifier = artworkModifier)
        AsyncImage(
            model = ImageRequest.Builder(context)
                .data("android.resource://${context.packageName}/${R.raw.airclip_splash_artwork}")
                .decoderFactory(SvgDecoder.Factory())
                .build(),
            contentDescription = null,
            contentScale = ContentScale.Fit,
            modifier = artworkModifier,
        )
        SplashOrbitingShapes(
            rotationDegrees = orbitRotation,
            modifier = artworkModifier,
        )

        AnimatedVisibility(
            visible = revealBottomContent,
            modifier = Modifier.fillMaxSize(),
            enter = fadeIn(tween(durationMillis = 300, easing = easeOut)) +
                slideInVertically(
                    animationSpec = tween(durationMillis = 300, easing = easeOut),
                    initialOffsetY = { (it * 0.08f).toInt() },
                ),
            exit = fadeOut(tween(durationMillis = 120)),
        ) {
            Box(modifier = Modifier.fillMaxSize()) {
                Text(
                    "Copy anywhere. Paste everywhere.",
                    fontSize = 24.sp,
                    fontFamily = BearyFontFamily,
                    fontWeight = FontWeight.Normal,
                    color = Color(0xFF202327),
                    textAlign = TextAlign.Center,
                    lineHeight = 36.sp,
                    modifier = Modifier
                        .align(Alignment.TopCenter)
                        .offset(y = headlineTop)
                        .width(s(272f)),
                )

                Column(
                    modifier = Modifier
                        .offset(x = s(32f), y = buttonStackTop)
                        .width(s(348f)),
                    verticalArrangement = Arrangement.spacedBy(buttonGap),
                ) {
                    LandingButton(
                        label = "Create an Airclip",
                        icon = R.drawable.airclip_splash_add,
                        containerColor = Color.Black,
                        contentColor = Color.White,
                        modifier = Modifier.fillMaxWidth(),
                        onClick = onCreateAirClip,
                    )
                    LandingButton(
                        label = "Join your Airclip",
                        icon = R.drawable.airclip_splash_link,
                        containerColor = Color(0xFFF5F4F7),
                        contentColor = Color(0xFF202327),
                        modifier = Modifier.fillMaxWidth(),
                        onClick = onJoinAirClip,
                    )
                }
            }
        }
    }
}

@Composable
private fun SplashOrbitingShapes(
    rotationDegrees: Float,
    modifier: Modifier = Modifier,
) {
    Canvas(modifier = modifier) {
        val scale = size.width / 412f
        fun p(value: Float) = value * scale
        fun orbitPoint(startAngle: Float): Offset {
            val centerX = 205.5f
            val centerY = 296.559f
            val radius = 139.74f
            val angle = startAngle + rotationDegrees * (PI.toFloat() / 180f)
            return Offset(
                x = p(centerX + radius * cos(angle)),
                y = p(centerY + radius * sin(angle)),
            )
        }

        val color = Color(0xFF50B4F7)
        val squareStartAngle = atan2(202f - 296.559f, 105f - 205.5f)
        val triangleStartAngle = squareStartAngle + (2f * PI.toFloat() / 3f)
        val dotStartAngle = squareStartAngle + (4f * PI.toFloat() / 3f)

        val squareCenter = orbitPoint(squareStartAngle)
        drawRoundRect(
            color = color,
            topLeft = Offset(squareCenter.x - p(7f), squareCenter.y - p(7f)),
            size = Size(p(14f), p(14f)),
            cornerRadius = CornerRadius(p(4f), p(4f)),
        )

        val triangleCenter = orbitPoint(triangleStartAngle)
        val trianglePath = Path().apply {
            moveTo(triangleCenter.x + p(-6.521f), triangleCenter.y + p(-1.018f))
            lineTo(triangleCenter.x + p(-5.449f), triangleCenter.y + p(-4.345f))
            lineTo(triangleCenter.x + p(4.223f), triangleCenter.y + p(-6.262f))
            lineTo(triangleCenter.x + p(6.521f), triangleCenter.y + p(-3.705f))
            lineTo(triangleCenter.x + p(3.654f), triangleCenter.y + p(5.491f))
            lineTo(triangleCenter.x + p(0.284f), triangleCenter.y + p(6.262f))
            close()
        }
        drawPath(trianglePath, color)

        drawCircle(
            color = color,
            radius = p(7f),
            center = orbitPoint(dotStartAngle),
        )
    }
}

@Composable
private fun SplashBlurArtwork(modifier: Modifier = Modifier) {
    Canvas(modifier = modifier) {
        val scale = size.width / 412f
        fun p(value: Float) = value * scale

        fun drawSoftCircle(
            color: Color,
            centerX: Float,
            centerY: Float,
            radius: Float,
            blur: Float,
        ) {
            val drawRadius = p(radius + blur)
            drawCircle(
                brush = Brush.radialGradient(
                    colorStops = arrayOf(
                        0f to color.copy(alpha = 0.8f),
                        (radius / (radius + blur) * 0.58f) to color.copy(alpha = 0.72f),
                        (radius / (radius + blur)) to color.copy(alpha = 0.24f),
                        1f to color.copy(alpha = 0f),
                    ),
                    center = Offset(p(centerX), p(centerY)),
                    radius = drawRadius,
                ),
                radius = drawRadius,
                center = Offset(p(centerX), p(centerY)),
            )
        }

        drawSoftCircle(
            color = Color(0xFF7F8FF9),
            centerX = 206f,
            centerY = 262f,
            radius = 292f,
            blur = 120f,
        )
        drawSoftCircle(
            color = Color(0xFF2E47F0),
            centerX = 205.498f,
            centerY = 270.014f,
            radius = 221.379f,
            blur = 86f,
        )
        drawSoftCircle(
            color = Color(0xFF070D30),
            centerX = 205.5f,
            centerY = 296.559f,
            radius = 124.164f,
            blur = 64f,
        )
    }
}

@Composable
private fun LandingButton(
    label: String,
    icon: Int,
    containerColor: Color,
    contentColor: Color,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    loading: Boolean = false,
    onClick: () -> Unit,
) {
    val interactionSource = remember { MutableInteractionSource() }
    val isPressed by interactionSource.collectIsPressedAsState()
    val scale by animateFloatAsState(
        targetValue = if (isPressed) 0.97f else 1f,
        animationSpec = spring(stiffness = 500f),
        label = "BtnScale",
    )
    Row(
        modifier = modifier
            .height(48.dp)
            .graphicsLayer { scaleX = scale; scaleY = scale }
            .clip(RoundedCornerShape(16.dp))
            .background(color = containerColor)
            .then(
                if (enabled && !loading) {
                    Modifier.clickable(
                        interactionSource = interactionSource,
                        indication = LocalIndication.current,
                        role = Role.Button,
                        onClick = onClick,
                    )
                } else {
                    Modifier
                },
            ),
        horizontalArrangement = Arrangement.Center,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        if (loading) {
            CircularProgressIndicator(
                modifier = Modifier.size(18.dp),
                color = contentColor,
                strokeWidth = 2.dp,
            )
        } else {
            Icon(
                painter = painterResource(icon),
                contentDescription = null,
                tint = Color.Unspecified,
                modifier = Modifier.size(20.dp),
            )
            Spacer(Modifier.width(12.dp))
            Text(
                label,
                fontSize = 18.sp,
                fontFamily = BearyFontFamily,
                fontWeight = FontWeight.Normal,
                color = contentColor,
            )
        }
    }
}

// ── Create — device name screen ───────────────────────────────────────────────

@Composable
private fun CreateNameScreen(
    uiState: MainViewModel.UiState,
    onDeviceNameChange: (String) -> Unit,
    onBack: () -> Unit,
    onCreate: () -> Unit,
    error: String?,
) {
    val c = LocalAirClipColors.current
    val focusManager = LocalFocusManager.current
    val easeOut = CubicBezierEasing(0.23f, 1f, 0.32f, 1f)
    var revealContent by remember { mutableStateOf(false) }

    LaunchedEffect(Unit) {
        kotlinx.coroutines.delay(60)
        revealContent = true
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(color = c.bgBase)
            .statusBarsPadding()
            .navigationBarsPadding()
            .imePadding(),
    ) {
        IconButton(
            onClick = onBack,
            modifier = Modifier
                .padding(start = 8.dp, top = 4.dp)
                .size(48.dp)
                .clip(CircleShape)
                .background(c.bgBase.copy(alpha = 0.8f)),
        ) {
            Icon(
                Icons.AutoMirrored.Outlined.ArrowBack,
                contentDescription = "Back",
                tint = c.textPrimary,
                modifier = Modifier.size(28.dp),
            )
        }

        AnimatedVisibility(
            visible = revealContent,
            modifier = Modifier.weight(1f),
            enter = fadeIn(tween(durationMillis = 300, easing = easeOut)) +
                slideInVertically(
                    animationSpec = tween(durationMillis = 300, easing = easeOut),
                    initialOffsetY = { (it * 0.03f).toInt() },
                ),
            exit = fadeOut(tween(durationMillis = 120)),
        ) {
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .verticalScroll(rememberScrollState())
                    .padding(horizontal = 32.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Spacer(Modifier.height(16.dp))
                Text(
                    "Name this device",
                    fontSize = 32.sp,
                    lineHeight = 40.sp,
                    fontFamily = BearyFontFamily,
                    fontWeight = FontWeight.Normal,
                    color = c.textPrimary,
                    textAlign = TextAlign.Center,
                )
                Spacer(Modifier.height(8.dp))
                Text(
                    "Helps you recognise it on your other devices.",
                    fontSize = 16.sp,
                    fontWeight = FontWeight.Normal,
                    color = c.textSecondary,
                    textAlign = TextAlign.Center,
                    lineHeight = 24.sp,
                    modifier = Modifier.fillMaxWidth(),
                )

                Spacer(Modifier.height(48.dp))
                DeviceNameField(
                    value = uiState.deviceName,
                    onValueChange = onDeviceNameChange,
                    onDone = { focusManager.clearFocus() },
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(56.dp),
                )

                error?.let {
                    Spacer(Modifier.height(10.dp))
                    Text(
                        it,
                        fontSize = 12.sp,
                        color = c.destructive,
                        modifier = Modifier.fillMaxWidth(),
                    )
                }

                Spacer(Modifier.height(16.dp))
                LandingButton(
                    label = "Create an Airclip",
                    icon = R.drawable.airclip_splash_add,
                    containerColor = if (uiState.deviceName.isNotBlank()) c.textPrimary else c.borderDefault,
                    contentColor = if (uiState.deviceName.isNotBlank()) c.bgBase else c.textTertiary,
                    enabled = uiState.deviceName.isNotBlank(),
                    loading = uiState.isPairingWaiting,
                    modifier = Modifier.fillMaxWidth(),
                    onClick = onCreate,
                )
                Spacer(Modifier.height(24.dp))
            }
        }
    }
}

@Composable
private fun DeviceNameField(
    value: String,
    onValueChange: (String) -> Unit,
    onDone: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val c = LocalAirClipColors.current
    OutlinedTextField(
        value = value,
        onValueChange = onValueChange,
        modifier = modifier,
        placeholder = {
            Text(
                "One Plus 6",
                color = c.textTertiary,
                fontSize = 18.sp,
                lineHeight = 25.2.sp,
            )
        },
        singleLine = true,
        keyboardOptions = KeyboardOptions(imeAction = ImeAction.Done),
        keyboardActions = KeyboardActions(onDone = { onDone() }),
        colors = OutlinedTextFieldDefaults.colors(
            focusedBorderColor = c.accent,
            unfocusedBorderColor = c.borderDefault,
            focusedContainerColor = c.bgBase,
            unfocusedContainerColor = c.bgBase,
            focusedTextColor = c.textPrimary,
            unfocusedTextColor = c.textPrimary,
            cursorColor = c.accent,
        ),
        shape = RoundedCornerShape(16.dp),
        textStyle = MaterialTheme.typography.bodyLarge.copy(
            color = c.textPrimary,
            fontSize = 18.sp,
            lineHeight = 25.2.sp,
        ),
    )
}

// ── Join flow ─────────────────────────────────────────────────────────────────

@Composable
private fun JoinFlowScreen(
    uiState: MainViewModel.UiState,
    onBack: () -> Unit,
    onScanQr: () -> Unit,
    onEnterCode: (String) -> Unit,
    onRefreshCode: () -> Unit,
    error: String?,
) {
    val c = LocalAirClipColors.current
    var activeTab by remember { mutableStateOf(JoinTab.SHOW_QR) }

    BoxWithConstraints(
        modifier = Modifier
            .fillMaxSize()
            .background(color = c.bgBase),
    ) {
        val scale = (maxWidth.value / 412f).coerceIn(0.82f, 1f)
        Column(
            modifier = Modifier
                .fillMaxSize()
                .statusBarsPadding()
                .imePadding(),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Box(modifier = Modifier.fillMaxWidth().height(56.dp)) {
                IconButton(
                    onClick = onBack,
                    modifier = Modifier.align(Alignment.CenterStart).padding(start = 8.dp),
                ) {
                    Icon(
                        Icons.AutoMirrored.Outlined.ArrowBack,
                        contentDescription = "Back",
                        tint = c.textPrimary,
                        modifier = Modifier.size(28.dp),
                    )
                }
            }

            Text(
                "Join your Airclip",
                fontFamily = BearyFontFamily,
                fontSize = 32.sp,
                lineHeight = 40.sp,
                fontWeight = FontWeight.Normal,
                color = c.textPrimary,
                textAlign = TextAlign.Center,
            )
            Spacer(Modifier.height(4.dp))
            Text(
                when (activeTab) {
                    JoinTab.SCAN_QR -> "Scan the QR code shown on a device in your Airclip network."
                    JoinTab.SHOW_QR -> "Scan this QR code with another Airclip device, or enter the code below."
                    JoinTab.CODE_INPUT -> "Enter the 6-digit code shown on an Airclip network device"
                },
                modifier = Modifier.fillMaxWidth().padding(horizontal = 24.dp),
                fontSize = 16.sp,
                lineHeight = 24.sp,
                color = c.textSecondary,
                textAlign = TextAlign.Center,
            )

            Box(modifier = Modifier.fillMaxWidth().weight(1f)) {
                when (activeTab) {
                    JoinTab.SCAN_QR -> ScanQrTabContent(onScanQr = onScanQr, scale = scale)
                    JoinTab.SHOW_QR -> ShowQrTabContent(uiState, scale, onRefreshCode)
                    JoinTab.CODE_INPUT -> CodeInputTabContent(onEnterCode, error, scale)
                }
            }

            JoinTabBar(
                activeTab = activeTab,
                onTabSelected = { activeTab = it },
                modifier = Modifier.navigationBarsPadding().padding(bottom = 16.dp),
            )
        }
    }
}

@Composable
private fun ScanQrTabContent(onScanQr: () -> Unit, scale: Float) {
    val interactionSource = remember { MutableInteractionSource() }
    val isPressed by interactionSource.collectIsPressedAsState()
    val pressScale by animateFloatAsState(
        targetValue = if (isPressed) 0.97f else 1f,
        animationSpec = spring(stiffness = 500f),
        label = "ScanScale",
    )

    Box(modifier = Modifier.fillMaxSize().padding(24.dp), contentAlignment = Alignment.Center) {
        fun s(value: Float) = (value * scale).dp

        Box(
            modifier = Modifier
                .size(s(240f))
                .graphicsLayer { scaleX = pressScale; scaleY = pressScale }
                .clip(RoundedCornerShape(s(32f)))
                .background(color = Color(0xFFF5F5F5))
                .border(s(1f), Color(0xFFE5E7EB), RoundedCornerShape(s(32f)))
                .clickable(
                    interactionSource = interactionSource,
                    indication = LocalIndication.current,
                    role = Role.Button,
                    onClick = onScanQr,
                ),
            contentAlignment = Alignment.Center,
        ) {
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(s(16f)),
            ) {
                Icon(
                    painter = painterResource(R.drawable.ic_pair_qr),
                    contentDescription = null,
                    tint = Color(0xFF101828),
                    modifier = Modifier.size(s(40f)),
                )
                Text(
                    "Tap to open camera",
                    fontSize = 14.sp,
                    fontWeight = FontWeight.Normal,
                    color = Color(0xFF6F7785),
                )
            }
        }
    }
}

@Composable
private fun ShowQrTabContent(
    uiState: MainViewModel.UiState,
    scale: Float,
    onRefreshCode: () -> Unit,
) {
    val c = LocalAirClipColors.current
    var nowMs by remember { mutableLongStateOf(System.currentTimeMillis()) }
    LaunchedEffect(uiState.pairingCodeExpiresAtMs) {
        while (true) {
            nowMs = System.currentTimeMillis()
            delay(1_000L)
        }
    }
    val secondsRemaining = ((uiState.pairingCodeExpiresAtMs - nowMs) / 1_000L).coerceAtLeast(0L)

    Column(
        modifier = Modifier.fillMaxSize().padding(horizontal = 24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        fun s(value: Float) = (value * scale).dp

        Box(
            modifier = Modifier
                .size(s(220f))
                .clip(RoundedCornerShape(s(32f)))
                .background(Color.White)
                .border(s(18f), Color(0xFFF7F7F6), RoundedCornerShape(s(32f)))
                .padding(s(24f)),
            contentAlignment = Alignment.Center,
        ) {
            val qrBitmap = uiState.pairingQr
            if (qrBitmap != null) {
                Image(
                    bitmap = qrBitmap.asImageBitmap(),
                    contentDescription = "Pairing QR code",
                    modifier = Modifier.fillMaxSize(),
                )
            } else {
                CircularProgressIndicator(
                    modifier = Modifier.size(32.dp),
                    color = c.accent,
                    strokeWidth = 2.dp,
                )
            }
        }

        Spacer(Modifier.height(s(20f)))
        uiState.pairingCode?.let { code ->
            val normalized = PairingCode.normalize(code).take(PairingCode.LENGTH)
            PairingCodeDisplay(
                code = normalized,
                modifier = Modifier,
                scale = scale,
            )
        }

        Spacer(Modifier.height(s(10f)))
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(s(8f)),
        ) {
            CircularProgressIndicator(
                modifier = Modifier.size(s(14f)),
                color = c.green,
                strokeWidth = s(2f),
            )
            Text(
                "Waiting · refreshes in ${secondsRemaining}s",
                fontSize = 13.sp,
                color = c.textSecondary,
            )
            TextButton(onClick = onRefreshCode) {
                Text("Refresh", color = c.accent)
            }
        }
    }
}

@OptIn(ExperimentalComposeUiApi::class)
@Composable
private fun CodeInputTabContent(
    onEnterCode: (String) -> Unit,
    error: String?,
    scale: Float,
) {
    var code by remember { mutableStateOf("") }
    var submittedCode by remember { mutableStateOf<String?>(null) }
    var isVerifyingCode by remember { mutableStateOf(false) }
    val focusRequester = remember { FocusRequester() }
    val keyboardController = LocalSoftwareKeyboardController.current
    val shakeOffset = remember { Animatable(0f) }
    val breathing = rememberInfiniteTransition(label = "CodeVerifyBreathing")
    val breathPhase by breathing.animateFloat(
        initialValue = 0f,
        targetValue = 1f,
        animationSpec = infiniteRepeatable(
            animation = tween(durationMillis = 1400, easing = LinearEasing),
            repeatMode = RepeatMode.Restart,
        ),
        label = "CodeVerifyBreathPhase",
    )
    val showCodeError = error != null && submittedCode == code && code.length == PairingCode.LENGTH

    LaunchedEffect(Unit) {
        kotlinx.coroutines.delay(180)
        focusRequester.requestFocus()
        keyboardController?.show()
    }

    LaunchedEffect(error) {
        if (showCodeError) {
            isVerifyingCode = false
            shakeOffset.snapTo(0f)
            shakeOffset.animateTo(
                targetValue = -8f,
                animationSpec = tween(durationMillis = 45),
            )
            shakeOffset.animateTo(
                targetValue = 8f,
                animationSpec = tween(durationMillis = 70),
            )
            shakeOffset.animateTo(
                targetValue = -5f,
                animationSpec = tween(durationMillis = 65),
            )
            shakeOffset.animateTo(
                targetValue = 4f,
                animationSpec = tween(durationMillis = 55),
            )
            shakeOffset.animateTo(
                targetValue = 0f,
                animationSpec = spring(dampingRatio = 0.65f, stiffness = 650f),
            )
            kotlinx.coroutines.delay(80)
            focusRequester.requestFocus()
            keyboardController?.show()
        }
    }

    Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        fun s(value: Float) = (value * scale).dp

        Box(
            modifier = Modifier
                .offset(x = s(shakeOffset.value)),
        ) {
            BasicTextField(
                value = code,
                onValueChange = { new ->
                    val filtered = PairingCode.normalize(new).take(PairingCode.LENGTH)
                    code = filtered
                    if (filtered != submittedCode) {
                        submittedCode = null
                        isVerifyingCode = false
                    }
                    if (filtered.length == PairingCode.LENGTH) {
                        submittedCode = filtered
                        isVerifyingCode = true
                        onEnterCode(filtered)
                    }
                },
                modifier = Modifier
                    .size(1.dp)
                    .focusRequester(focusRequester),
                keyboardOptions = KeyboardOptions(
                    keyboardType = KeyboardType.Number,
                    imeAction = ImeAction.Done,
                ),
                textStyle = LocalTextStyle.current.copy(color = Color.Transparent),
                cursorBrush = Brush.verticalGradient(listOf(Color.Transparent, Color.Transparent)),
            )

            Row(
                horizontalArrangement = Arrangement.spacedBy(s(8f)),
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier.clickable(
                    interactionSource = remember { MutableInteractionSource() },
                    indication = LocalIndication.current,
                    role = Role.Button,
                ) {
                    focusRequester.requestFocus()
                    keyboardController?.show()
                },
            ) {
                val activeCount = (code.length + 1).coerceAtMost(PairingCode.LENGTH)
                val inactiveCount = PairingCode.LENGTH - activeCount

                repeat(activeCount) { index ->
                    val digit = code.getOrNull(index)?.toString()
                    val isFilledDigit = digit != null
                    val isDanger = showCodeError && isFilledDigit
                    val breathOffset = if (isVerifyingCode && isFilledDigit) {
                        val wave = sin(((breathPhase + (index * 0.14f)) % 1f) * 2f * PI).toFloat()
                        s(wave * 10f)
                    } else {
                        0.dp
                    }
                    val slotSize by animateDpAsState(
                        targetValue = s(54f),
                        animationSpec = spring(
                            dampingRatio = 0.72f,
                            stiffness = 360f,
                        ),
                        label = "CodeSlotSize$index",
                    )
                    val bgColor by animateColorAsState(
                        targetValue = if (isDanger) {
                            Color(0xFFDC2626).copy(alpha = 0.08f)
                        } else {
                            Color(0xFFD9E7FB)
                        },
                        animationSpec = tween(150),
                        label = "DigitBg$index",
                    )
                    Box(
                        modifier = Modifier
                            .size(slotSize)
                            .offset(y = breathOffset)
                            .clip(CircleShape)
                            .background(color = bgColor)
                            .then(
                                if (isDanger) {
                                    Modifier.border(1.dp, Color(0xFFDC2626), CircleShape)
                                } else {
                                    Modifier
                                },
                            ),
                        contentAlignment = Alignment.Center,
                    ) {
                        if (digit != null) {
                            Text(
                                digit,
                                fontSize = 28.sp,
                                lineHeight = 39.sp,
                                fontWeight = FontWeight.Normal,
                                color = if (isDanger) Color(0xFFDC2626) else Color(0xFF3572CD),
                                textAlign = TextAlign.Center,
                            )
                        }
                    }
                }

                AnimatedVisibility(
                    visible = inactiveCount > 0,
                    enter = fadeIn(tween(120)) + expandHorizontally(
                        animationSpec = spring(dampingRatio = 0.82f, stiffness = 360f),
                        expandFrom = Alignment.Start,
                    ),
                    exit = fadeOut(tween(90)) + shrinkHorizontally(
                        animationSpec = spring(dampingRatio = 0.9f, stiffness = 420f),
                        shrinkTowards = Alignment.Start,
                    ),
                ) {
                    Row(
                        modifier = Modifier
                            .height(s(54f))
                            .padding(start = s(24f)),
                        horizontalArrangement = Arrangement.spacedBy(s(32f)),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        repeat(inactiveCount) { index ->
                            Box(
                                modifier = Modifier
                                    .size(s(14f))
                                    .clip(CircleShape)
                                    .background(Color(0xFFD9E7FB).copy(alpha = 0.9f)),
                            )
                        }
                    }
                }
            }
        }

        AnimatedVisibility(
            visible = showCodeError,
            modifier = Modifier
                .align(Alignment.Center)
                .offset(y = s(72f)),
            enter = fadeIn(tween(160)) + slideInVertically(tween(180)) { it / 4 },
            exit = fadeOut(tween(120)),
        ) {
            Text(
                error ?: "",
                modifier = Modifier.width(s(320f)),
                fontSize = 13.sp,
                lineHeight = 18.sp,
                color = Color(0xFFDC2626),
                textAlign = TextAlign.Center,
            )
        }
    }
}

@Composable
private fun PairingCodeDisplay(code: String, modifier: Modifier = Modifier, scale: Float) {
    val c = LocalAirClipColors.current
    val parts = PairingCode.normalize(code).padEnd(PairingCode.LENGTH, ' ').chunked(3)

    Row(
        modifier = modifier,
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy((12f * scale).dp),
    ) {
        PairingCodeGroup(parts.getOrElse(0) { "   " }, scale)
        Text(
            "-",
            fontSize = 28.sp,
            lineHeight = 39.sp,
            fontWeight = FontWeight.SemiBold,
            color = c.textPrimary,
        )
        PairingCodeGroup(parts.getOrElse(1) { "   " }, scale)
    }
}

@Composable
private fun PairingCodeGroup(part: String, scale: Float) {
    val c = LocalAirClipColors.current

    Row(
        modifier = Modifier
            .height((48f * scale).dp)
            .clip(RoundedCornerShape((16f * scale).dp))
            .background(Color(0xFFF5F5F5))
            .padding(horizontal = (8f * scale).dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy((4f * scale).dp),
    ) {
        repeat(3) { index ->
            Text(
                part.getOrNull(index)?.toString()?.trim().orEmpty(),
                modifier = Modifier.width((38f * scale).dp),
                fontSize = 28.sp,
                lineHeight = 39.sp,
                fontWeight = FontWeight.SemiBold,
                color = c.textPrimary,
                textAlign = TextAlign.Center,
            )
        }
    }
}

// ── Join tab bar — segmented control ─────────────────────────────────────────

@Composable
private fun JoinTabBar(
    activeTab: JoinTab,
    onTabSelected: (JoinTab) -> Unit,
    modifier: Modifier = Modifier,
) {
    val tabs = listOf(JoinTab.SHOW_QR to "Show QR", JoinTab.SCAN_QR to "Scan QR", JoinTab.CODE_INPUT to "Code Input")
    val density = LocalDensity.current
    val tabMetrics = remember { mutableStateMapOf<JoinTab, Pair<Float, Int>>() }
    val activeMetric = tabMetrics[activeTab]
    val indicatorX by animateDpAsState(
        targetValue = with(density) { (activeMetric?.first ?: 0f).toDp() },
        animationSpec = spring(dampingRatio = 0.82f, stiffness = 520f),
        label = "JoinTabIndicatorX",
    )
    val indicatorWidth by animateDpAsState(
        targetValue = with(density) { (activeMetric?.second ?: 0).toDp() },
        animationSpec = spring(dampingRatio = 0.82f, stiffness = 520f),
        label = "JoinTabIndicatorWidth",
    )

    Box(
        modifier = modifier
            .clip(RoundedCornerShape(16.dp))
            .background(Color(0x0A151311))
            .padding(10.dp),
    ) {
        if (activeMetric != null) {
            Box(
                modifier = Modifier
                    .offset(x = indicatorX)
                    .width(indicatorWidth)
                    .height(40.dp)
                    .shadow(
                        elevation = 2.dp,
                        shape = RoundedCornerShape(10.dp),
                        ambientColor = Color.Black.copy(alpha = 0.04f),
                        spotColor = Color.Black.copy(alpha = 0.08f),
                    )
                    .clip(RoundedCornerShape(10.dp))
                    .background(Color.White.copy(alpha = 0.9f)),
            )
        }

        Row(
            horizontalArrangement = Arrangement.spacedBy(0.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            tabs.forEach { (tab, label) ->
                val interactionSource = remember { MutableInteractionSource() }
                val isPressed by interactionSource.collectIsPressedAsState()
                val isActive = activeTab == tab
                val textColor by animateColorAsState(
                    targetValue = if (isActive) Color.Black else Color.Black.copy(alpha = 0.48f),
                    animationSpec = tween(140, easing = CubicBezierEasing(0.23f, 1f, 0.32f, 1f)),
                    label = "TabTextColor",
                )
                val pressColor by animateColorAsState(
                    targetValue = if (isPressed && !isActive) Color.Black.copy(alpha = 0.035f) else Color.Transparent,
                    animationSpec = tween(120, easing = CubicBezierEasing(0.23f, 1f, 0.32f, 1f)),
                    label = "TabPressColor",
                )
                Box(
                    modifier = Modifier
                        .height(40.dp)
                        .clip(RoundedCornerShape(10.dp))
                        .background(pressColor)
                        .onGloballyPositioned { coordinates ->
                            tabMetrics[tab] = coordinates.positionInParent().x to coordinates.size.width
                        }
                        .semantics { selected = isActive }
                        .clickable(
                            interactionSource = interactionSource,
                            indication = LocalIndication.current,
                            role = Role.Tab,
                        ) { onTabSelected(tab) },
                    contentAlignment = Alignment.Center,
                ) {
                    Text(
                        label,
                        modifier = Modifier.padding(horizontal = 12.dp),
                        fontSize = 16.sp,
                        lineHeight = 20.sp,
                        color = textColor,
                        fontWeight = FontWeight.Medium,
                        textAlign = TextAlign.Center,
                    )
                }
            }
        }
    }
}

// ── Success screen ─────────────────────────────────────────────────────────────

@Composable
private fun SuccessScreen(onGetStarted: () -> Unit) {
    val c = LocalAirClipColors.current

    // Entrance animation
    var visible by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) {
        kotlinx.coroutines.delay(100)
        visible = true
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(color = c.bgBase),
        contentAlignment = Alignment.Center,
    ) {
        AnimatedVisibility(
            visible = visible,
            enter = fadeIn(tween(400)) + slideInVertically(tween(400, easing = FastOutSlowInEasing)) { it / 6 },
        ) {
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                modifier = Modifier.padding(horizontal = 40.dp),
            ) {
                // Success mark
                Box(
                    modifier = Modifier
                        .size(80.dp)
                        .background(c.green.copy(alpha = 0.12f), CircleShape),
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(Icons.Outlined.CheckCircle, null, tint = c.green, modifier = Modifier.size(44.dp))
                }

                Spacer(Modifier.height(24.dp))

                Text(
                    "Successfully joined",
                    fontSize = 26.sp,
                    fontWeight = FontWeight.Bold,
                    color = c.textPrimary,
                    textAlign = TextAlign.Center,
                    letterSpacing = (-0.4).sp,
                )

                Spacer(Modifier.height(10.dp))

                Text(
                    "This device is now part of your Airclip network. Copy on one device, paste from another.",
                    style = MaterialTheme.typography.bodyMedium,
                    color = c.textSecondary,
                    textAlign = TextAlign.Center,
                    lineHeight = 22.sp,
                )

                Spacer(Modifier.height(40.dp))

                OnboardingPrimaryButton(
                    label = "Get Started",
                    enabled = true,
                    loading = false,
                    onClick = onGetStarted,
                )
            }
        }
    }
}

// ── Shared button ─────────────────────────────────────────────────────────────

@Composable
private fun OnboardingPrimaryButton(
    label: String,
    enabled: Boolean,
    loading: Boolean,
    onClick: () -> Unit,
) {
    val c = LocalAirClipColors.current
    val interactionSource = remember { MutableInteractionSource() }
    val isPressed by interactionSource.collectIsPressedAsState()
    val scale by animateFloatAsState(
        targetValue = if (isPressed) 0.97f else 1f,
        animationSpec = spring(stiffness = 500f),
        label = "PrimaryBtnScale",
    )

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .height(52.dp)
            .graphicsLayer { scaleX = scale; scaleY = scale }
            .clip(RoundedCornerShape(26.dp))
            .background(
                color = if (enabled) c.textPrimary else c.borderDefault,
            )
            .then(
                if (enabled) Modifier.clickable(
                    interactionSource = interactionSource,
                    indication = LocalIndication.current,
                    role = Role.Button,
                    onClick = onClick,
                ) else Modifier
            ),
        horizontalArrangement = Arrangement.Center,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        if (loading) {
            CircularProgressIndicator(
                modifier = Modifier.size(18.dp),
                color = c.bgBase,
                strokeWidth = 2.dp,
            )
        } else {
            Text(
                label,
                fontSize = 15.sp,
                fontWeight = FontWeight.SemiBold,
                color = if (enabled) c.bgBase else c.textTertiary,
            )
        }
    }
}
